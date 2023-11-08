#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

with_arch () {
    if [[ "$IMAGEARCH" = "linux/amd64" ]]; then
        echo $1
    else
        echo $1-${IMAGEARCH/*\//}
    fi
}

docker_push () {
    if [[ "$1" = *".dkr.ecr."*".amazonaws.com/"* ]] && [ -x "$PROJECTROOT/script/$BACKEND/shell.sh" ]; then
        REGISTRY= "$PROJECTROOT/script/$BACKEND/shell.sh" aws -- /opt/terraform/script/push-to-ecr.sh $1
    elif [[ "$1" = *".pkg.dev/"* ]] && [ -x "$PROJECTROOT/script/$BACKEND/shell.sh" ]; then
        REGISTRY= "$PROJECTROOT/script/$BACKEND/shell.sh" gcp -- docker -D push $1
    else
        docker -D push $1
    fi
}

parse_dockerfile_ingredients () {
    while IFS= read line; do
        case "$line" in
        "ARG "*_VER=*|"ARG "*_VERSION=*|"ARG "*_REPO=*|"ARG "*_REPOSITORY=*|"ARG "*_IMAGE=*|"ARG "*_PACKAGE=*|"ARG "*_IMG=*|"ARG "*_PKG=*)
            var="$(echo "${line/ARG /}" | tr -d '" ' | cut -f1 -d=)"
            value="$(echo "${line/ARG /}" | tr -d '" ' | cut -f2- -d=)"
            eval "$var=\"$value\""
            eval "value=\"$value\""
            echo "$1${var^^}=$value"
            ;;
        esac
    done
}

parse_ansible_ingredients () {
    while IFS= read yaml; do
        while IFS= read line; do
            case "$line" in
            *_ver:*|*_VER:*|*_version:*|*_VERSION:*|*_repo:*|*_REPO:*|*_repository:*|*_REPOSITORY:*|*_pkg:*|*_PKG:*|*_package:*|*_PACKAGE:*|*_image:*|*_IMAGE:*)
                var="$(echo "$line" | cut -f1 -d:)"
                value="$(echo "$line" | sed 's/[^:]*:\s*\(.*[^ ]\)\s*$/\1/' | tr -d '"'"'" | sed 's/{{ *\([^ }]*\) *}}/${\1}/g')"
                eval "$var=\"$value\""
                eval "value=\"$value\""
                echo "ARG ${var^^}=$value"
                ;;
            esac
        done < "$yaml"
    done
}

macro_replacement () {
    (
        cd "$SOURCEROOT/$1"
        for file1 in *.m4; do
            if [[ "$file1" != *"-config.yaml.m4" ]] && [ -e "$file1" ]; then
                tmp="$(mktemp -p . "${file1%.m4}.tmpm4.XXXX")"
                echo "$SOURCEROOT/$1/$tmp"
                m4 -Itemplate -I"$PROJECTROOT/template" -DPLATFORM=$PLATFORM -DIMAGEARCH=$IMAGEARCH -D$2="$3" -DREGISTRY=$REGISTRY -DBACKEND=$BACKEND -DRELEASE=$RELEASE $M4_OPTIONS "$file1" > "$tmp"
            fi
        done
        for file1 in *.j2; do
            if [[ "$file1" != *"-config.yaml.j2" ]] && [ -e "$file1" ]; then
                tmp="$(mktemp -p . "${file1%.j2}.tmpj2.XXXX")"
                echo "$SOURCEROOT/$1/$tmp"
                ansible all -i "localhost," -c local -m template -a "src=\"$file1\" dest=\"$tmp\"" -e PLATFORM=$PLATFORM -e IMAGEARCH=$IMAGEARCH -e $2="$3" -e REGISTRY=$REGISTRY -e BACKEND=$BACKEND -e RELEASE=$RELEASE $J2_OPTIONS > /dev/null
            fi
        done
    )
}

# overwrite SOURCEROOT for image and stack
this="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
if [[ "$this" = *"$PROJECTROOT/stack/"* ]] && [ -n "$STACK" ]; then
    export SOURCEROOT="$this"
elif [[ "$this" = *"$PROJECTROOT/image/"* ]] && [ -n "$IMAGE" ]; then
    export SOURCEROOT="$this"
fi

# convert BUILD_FILES to FIND_OPTIONS
if [ ${#BUILD_FILES[@]} -gt 0 ]; then
    options=""
    for file1 in ${BUILD_FILES[@]}; do
        options="$options-name ${file1//*\/} -o "
    done
    FIND_OPTIONS="$FIND_OPTIONS ( ${options% -o } )"
fi

BUILD_CONTEXT=(${BUILD_CONTEXT[@]:-.})
[ ${#DOCKER_CONTEXT[@]} -eq 0 ] || BUILD_CONTEXT=(${DOCKER_CONTEXT[@]})

# file lock
(
    flock -e 9

    # template substitution
    tmp_files=()
    if [[ "$SOURCEROOT" = "$PROJECTROOT"/workload/* ]]; then
        for bc in "${BUILD_CONTEXT[@]}"; do
            tmp_files+=($(macro_replacement "$bc" WORKLOAD $WORKLOAD))
        done
    elif [[ "$SOURCEROOT" = "$PROJECTROOT"/stack/* ]]; then
        for bc in "${BUILD_CONTEXT[@]}"; do
            tmp_files+=($(macro_replacement "$bc" STACK $STACK))
        done
    elif [[ "$SOURCEROOT" = "$PROJECTROOT"/image/* ]]; then
        for bc in "${BUILD_CONTEXT[@]}"; do
            tmp_files+=($(macro_replacement "$bc" IMAGE $IMAGE))
        done
    fi
    
    if [[ "$@" = *"--bom"* ]]; then
        [[ "$SOURCEROOT" = *"/workload/"* ]] && echo "# ${SOURCEROOT/*\/workload/workload}"
        [[ "$SOURCEROOT" = *"/stack/"* ]] && echo "# ${SOURCEROOT/*\/stack/stack}"
        [[ "$SOURCEROOT" = *"/image/"* ]] && echo "# ${SOURCEROOT/*\/image/image}"
    
        parse_ansible_ingredients < <(find "$SOURCEROOT/template/ansible" \( -path "*/defaults/*.yaml" -o -path "*/defaults/*.yml" \) $FIND_OPTIONS -print 2> /dev/null)
    fi
    
    if [[ "$@" != *"--read-only-registry"* ]]; then
        build_options=($(compgen -e | sed -nE '/_(proxy|PROXY)$/{s/^/--build-arg /;p}') --build-arg RELEASE=$RELEASE --build-arg BUILDKIT_INLINE_CACHE=1)
    
        if [ "$IMAGEARCH" != "linux/amd64" ]; then
            build_options+=(--platform $IMAGEARCH)
        fi
    
        if [ -r "$HOME/.netrc" ]; then
            build_options+=(--secret id=.netrc,src=$HOME/.netrc)
        elif [ -r "/root/.netrc" ]; then
            build_options+=(--secret id=.netrc,src=/root/.netrc)
        fi
    
        for dc in "${BUILD_CONTEXT[@]}"; do
            for pat in '.9.*' '.8.*' '.7.*' '.6.*' '.5.*' '.4.*' '.3.*' '.2.*' '.1.*' '.tmpj2.*' '.tmpm4.*' ''; do
                for dockerfile in $(find "$SOURCEROOT/$dc" -maxdepth 1 -name "Dockerfile$pat" ! -name "*.m4" ! -name "*.j2" $FIND_OPTIONS -print 2>/dev/null); do
                    image=$(with_arch $(head -n 2 "$dockerfile" | grep -E '^#+ ' | tail -n 1 | cut -d' ' -f2))
                    header=$(head -n 2 "$dockerfile" | grep -E '^#+ ' | tail -n 1 | cut -d' ' -f1)
                    IMAGE="$REGISTRY$image$RELEASE"
                    if [[ "$@" = *"--bom"* ]]; then
                        echo "$header image: $IMAGE"
                        parse_dockerfile_ingredients "ARG " < "$dockerfile"
                    else
                        (
                            cd "$SOURCEROOT/$dc"
                            ingredients="$(parse_dockerfile_ingredients "ARG_" < "$dockerfile" | sed "s|^\(.*\)$|--label \1|")"
                            DOCKER_BUILDKIT=1 docker build $BUILD_OPTIONS ${build_options[@]} $([ -n "$DOCKER_CACHE_REGISTRY" ] && [ -n "$DOCKER_CACHE_REGISTRY_CACHE_TAG" ] && echo --cache-from $DOCKER_CACHE_REGISTRY/$image:$DOCKER_CACHE_REGISTRY_CACHE_TAG) -t $image -t $image$RELEASE $([ -n "$REGISTRY" ] && [ "$header" = "#" ] && echo -t $IMAGE) $ingredients -f "$dockerfile" .
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
    
    # delete tmp files
    rm -f "${tmp_files[@]}"
) 9< "$SOURCEROOT/build.sh"

