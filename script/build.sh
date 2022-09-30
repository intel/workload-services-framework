#!/bin/bash -e

PLATFORM=${PLATFORM:-SPR}
IMAGEARCH=${IMAGEARCH:-linux/amd64}
BACKEND=${BACKEND:-docker}
RELEASE=${RELEASE:-:latest}

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
        REGISTRY= "$SCRIPT/cumulus/shell.sh" aws -v "$SCRIPT/cumulus:/mnt:ro" -- /mnt/script/create-private-repository-aws.sh $1 || true
        ;;
    esac
    docker -D push $1
}

# template substitution
if [[ "$DIR" = */workload/* ]]; then
    find "$DIR" -name "*.m4" ! -name "*-config.yaml.m4" ! -path "*/template/*" -exec /bin/bash -c 'f="{}" && cd "'$DIR'" && m4 -Itemplate -I../../template -DPLATFORM='$PLATFORM' -DIMAGEARCH='$IMAGEARCH' -DWORKLOAD='$WORKLOAD' -DREGISTRY='$REGISTRY' -DBACKEND='$BACKEND' -DRELEASE='$RELEASE' "$f" > "${f/.m4/}"' \;
elif [[ "$DIR" = */stack/* ]]; then
    find "$DIR" -name "*.m4" ! -name "*-config.yaml.m4" ! -path "*/template/*" -exec /bin/bash -c 'f="{}" && cd "'$DIR'" && m4 -Itemplate -I../../template -DPLATFORM='$PLATFORM' -DIMAGEARCH='$IMAGEARCH' -DSTACK='$STACK' -DREGISTRY='$REGISTRY' -DBACKEND='$BACKEND' -DRELEASE='$RELEASE' "$f" > "${f/.m4/}"' \;
fi

if [ "${#DOCKER_CONTEXT[@]}" -eq 0 ]; then
    DOCKER_CONTEXT=("${DOCKER_CONTEXT:-.}")
fi

if [ "$1" = "--bom" ]; then
    [[ "$DIR" = *"/workload/"* ]] && echo "# ${DIR/*\/workload/workload}"
    [[ "$DIR" = *"/stack/"* ]] && echo "# ${DIR/*\/stack/stack}"
    for dc in "${DOCKER_CONTEXT[@]}"; do
        for pat in '.9.*' '.8.*' '.7.*' '.6.*' '.5.*' '.4.*' '.3.*' '.2.*' '.1.*' ''; do
            find "$DIR/$dc" -maxdepth 1 -mindepth 1 -name "Dockerfile$pat" $FIND_OPTIONS ! -name "*.m4" -print 2> /dev/null | (
                while IFS= read df; do
                    image=$(with_arch $(head -n 2 "$df" | grep -E '^#+ ' | tail -n 1 | cut -d' ' -f2))
                    header=$(head -n 2 "$df" | grep -E '^#+ ' | tail -n 1 | cut -d' ' -f1)
                    [ -n "$REGISTRY" ] && [ "$header" = "#" ] && image="$REGISTRY$image$RELEASE"
                    echo "$header image: $image"
                    while IFS= read line; do
                        if [[ "$line" = "ARG "*=* ]]; then
                            var="$(echo ${line/ARG /} | tr -d '"' | cut -f1 -d=)"
                            value="$(echo ${line/ARG /} | tr -d '"' | cut -f2- -d=)"
                            eval "$var=\"$value\""
                            eval "value=\"$value\""

                            case "$line" in
                            *_VER=*|*_VERSION=*|*_REPO=*|*_REPOSITORY=*|*_IMG=*|*_IMAGE=*|*_PKG=*|*_PACKAGE=*)
                                echo "ARG $var=$value"
                                ;;
                            esac
                        fi
                    done < "$df"
                done
            )
        done
    done
else
    build_options="$(env | cut -f1 -d= | grep -iE '_proxy$' | sed 's/^/--build-arg /'  | tr '\n' ' ')"
    build_options="$build_options --build-arg RELEASE=$RELEASE"

    if [ "$IMAGEARCH" != "linux/amd64" ]; then
        build_options="$build_options --platform $IMAGEARCH"
    fi

    build_options="$build_options --build-arg BUILDKIT_INLINE_CACHE=1"
    for dc in "${DOCKER_CONTEXT[@]}"; do
        for pat in '.9.*' '.8.*' '.7.*' '.6.*' '.5.*' '.4.*' '.3.*' '.2.*' '.1.*' ''; do
            for dockerfile in $(find "$DIR/$dc" -maxdepth 1 -mindepth 1 -name "Dockerfile$pat" $FIND_OPTIONS -print 2>/dev/null); do

                image=$(with_arch $(head -n 2 "$dockerfile" | grep -E '^#+ ' | tail -n 1 | cut -d' ' -f2))
                header=$(head -n 2 "$dockerfile" | grep -E '^#+ ' | tail -n 1 | cut -d' ' -f1)
                IMAGE="$REGISTRY$image$RELEASE"
                (
                    cd "$DIR/$dc"
                    DOCKER_BUILDKIT=1 docker build $BUILD_OPTIONS $build_options --cache-from $REGISTRY$image$RELEASE -t $image -t $image$RELEASE $([ -n "$REGISTRY" ] && [ "$header" = "#" ] && echo -t $IMAGE) -f "$dockerfile" .
                )
                if [ -n "$REGISTRY" ] && [ "$header" = "#" ]; then
                    docker_push $IMAGE
                fi
            done
        done
    done
fi
