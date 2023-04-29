#!/bin/bash -e

with_arch () {
    if [[ "$IMAGEARCH" = "linux/amd64" ]]; then
        echo $1
    else
        echo $1-${IMAGEARCH/*\//}
    fi
}

docker_push () {
    case "$1" in
    *.dkr.ecr.*.amazonaws.com/*)
        REGISTRY= "$PROJECTROOT/script/$BACKEND/shell.sh" aws -- /opt/script/push-to-ecr.sh $1
        ;;
    *.pkg.dev/*)
        REGISTRY= "$PROJECTROOT/script/$BACKEND/shell.sh" gcp -- docker -D push $1
        ;;
    *)
        docker -D push $1
        ;;
    esac
}

parse_ingredients () {
    while IFS= read line; do
        case "$line" in
        "ARG "*_VER=*|"ARG "*_VERSION=*|"ARG "*_REPO=*|"ARG "*_REPOSITORY=*|"ARG "*_IMAGE=*|"ARG "*_PACKAGE=*|"ARG "*_IMG=*|"ARG "*_PKG=*)
            var="$(echo ${line/ARG /} | tr -d '" ' | cut -f1 -d=)"
            value="$(echo ${line/ARG /} | tr -d '" ' | cut -f2- -d=)"
            eval "$var=\"$value\""
            eval "value=\"$value\""
            echo "$1${var^^}=$value"
            ;;
        esac
    done
}

# overwrite SOURCEROOT for image and stack
this="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
if [[ "$this" = *"$PROJECTROOT/stack/"* ]] && [ -n "$STACK" ]; then
    export SOURCEROOT="$this"
fi
if [[ "$this" = *"$PROJECTROOT/image/"* ]] && [ -n "$IMAGE" ]; then
    export SOURCEROOT="$this"
fi

# template substitution
if [[ "$SOURCEROOT" = */workload/* ]]; then
    find "$SOURCEROOT" -name "*.m4" ! -name "*-config.yaml.m4" ! -path "*/template/*" -exec /bin/bash -c 'f="{}" && cd "'$SOURCEROOT'" && m4 -Itemplate -I"'$PROJECTROOT'/template" -DPLATFORM='$PLATFORM' -DIMAGEARCH='$IMAGEARCH' -DWORKLOAD='$WORKLOAD' -DREGISTRY='$REGISTRY' -DBACKEND='$BACKEND' -DRELEASE='$RELEASE' "$f" > "${f/.m4/}"' \;
elif [[ "$SOURCEROOT" = */stack/* ]]; then
    find "$SOURCEROOT" -name "*.m4" ! -name "*-config.yaml.m4" ! -path "*/template/*" -exec /bin/bash -c 'f="{}" && cd "'$SOURCEROOT'" && m4 -Itemplate -I"'$PROJECTROOT'/template" -DPLATFORM='$PLATFORM' -DIMAGEARCH='$IMAGEARCH' -DSTACK='$STACK' -DREGISTRY='$REGISTRY' -DBACKEND='$BACKEND' -DRELEASE='$RELEASE' "$f" > "${f/.m4/}"' \;
elif [[ "$SOURCEROOT" = */image/* ]]; then
    find "$SOURCEROOT" -name "*.m4" ! -name "*-config.yaml.m4" ! -path "*/template/*" -exec /bin/bash -c 'f="{}" && cd "'$SOURCEROOT'" && m4 -Itemplate -I"'$PROJECTROOT'/template" -DPLATFORM='$PLATFORM' -DIMAGEARCH='$IMAGEARCH' -DIMAGE='$IMAGE' -DREGISTRY='$REGISTRY' -DBACKEND='$BACKEND' -DRELEASE='$RELEASE' "$f" > "${f/.m4/}"' \;
fi

if [ "${#DOCKER_CONTEXT[@]}" -eq 0 ]; then
    DOCKER_CONTEXT=("${DOCKER_CONTEXT:-.}")
fi

if [[ "$@" = *"--bom"* ]]; then
    [[ "$SOURCEROOT" = *"/workload/"* ]] && echo "# ${SOURCEROOT/*\/workload/workload}"
    [[ "$SOURCEROOT" = *"/stack/"* ]] && echo "# ${SOURCEROOT/*\/stack/stack}"
    [[ "$SOURCEROOT" = *"/image/"* ]] && echo "# ${SOURCEROOT/*\/image/image}"

    find "$SOURCEROOT/template/ansible" \( -path "*/defaults/*.yaml" -o -path "*/defaults/*.yml" \) $FIND_OPTIONS -print 2> /dev/null | (
        while IFS= read yaml; do
            while IFS= read line; do
                case "$line" in
                *_ver:*|*_VER:*|*_version:*|*_VERSION:*|*_repo:*|*_REPO:*|*_repository:*|*_REPOSITORY:*|*_pkg:*|*_PKG:*|*_package:*|*_PACKAGE:*|*_image:*|*_IMAGE:*)
                    var="$(echo $line | cut -f1 -d:)"
                    value="$(echo $line | sed 's/[^:]*:\s*\(.*[^ ]\)\s*$/\1/' | tr -d '"'"'")"
                    eval "$var=\"$value\""
                    eval "value=\"$value\""
                    echo "ARG ${var^^}=$value"
                    ;;
                esac
            done < "$yaml"
        done
    )
fi

if [[ "$@" != *"--read-only-registry"* ]]; then
    build_options="$(compgen -e | sed -nE '/_(proxy|PROXY)$/{s/^/--build-arg /;p}')"
    build_options="$build_options --build-arg RELEASE=$RELEASE --build-arg BUILDKIT_INLINE_CACHE=1"

    if [ "$IMAGEARCH" != "linux/amd64" ]; then
        build_options="$build_options --platform $IMAGEARCH"
    fi

    if [ -r "$HOME/.netrc" ]; then
        build_options="$build_options --secret id=.netrc,src=$HOME/.netrc"
    elif [ -r "/root/.netrc" ]; then
        build_options="$build_options --secret id=.netrc,src=/root/.netrc"
    fi

    for dc in "${DOCKER_CONTEXT[@]}"; do
        for pat in '.9.*' '.8.*' '.7.*' '.6.*' '.5.*' '.4.*' '.3.*' '.2.*' '.1.*' ''; do
            for dockerfile in $(find "$SOURCEROOT/$dc" -maxdepth 1 -mindepth 1 -name "Dockerfile$pat" $FIND_OPTIONS -print 2>/dev/null); do

                image=$(with_arch $(head -n 2 "$dockerfile" | grep -E '^#+ ' | tail -n 1 | cut -d' ' -f2))
                header=$(head -n 2 "$dockerfile" | grep -E '^#+ ' | tail -n 1 | cut -d' ' -f1)
                IMAGE="$REGISTRY$image$RELEASE"
                if [[ "$@" = *"--bom"* ]]; then
                    echo "$header image: $IMAGE"
                    parse_ingredients "ARG " < "$dockerfile"
                else
                    (
                        cd "$SOURCEROOT/$dc"
                        ingredients="$(parse_ingredients "ARG_" < "$dockerfile" | sed "s|^\(.*\)$|--label \1|")"
                        DOCKER_BUILDKIT=1 docker build $BUILD_OPTIONS $build_options $([ -n "$DOCKER_CACHE_REGISTRY" ] && [ -n "$DOCKER_CACHE_REGISTRY_CACHE_TAG" ] && echo --cache-from $DOCKER_CACHE_REGISTRY/$image:$DOCKER_CACHE_REGISTRY_CACHE_TAG) -t $image -t $image$RELEASE $([ -n "$REGISTRY" ] && [ "$header" = "#" ] && echo -t $IMAGE) $ingredients -f "$dockerfile" .
                    )

                    # if REGISTRY is specified, push image to the private registry
                    if [ -n "$REGISTRY" ] && [ "$header" = "#" ]; then
                        [ "$BACKEND" = "atscale" ] && . "$PROJECTROOT/script/atscale/build.sh"
                        docker_push $IMAGE
                    fi
                fi
            done
        done
    done
fi
