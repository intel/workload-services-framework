#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

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
            local var="$(echo "${line/ARG /}" | tr -d "'"'" ' | cut -f1 -d=)"
            local value="$(echo "${line/ARG /}" | tr -d "'"'" ' | cut -f2- -d= | cut -f1 -d'#')"
            eval "local $var=\"$value\""
            eval "local value=\"$value\""
            echo "$1${var^^}=$value"
            ;;
        "ARG "*=*)
            local var="$(echo "${line/ARG /}" | tr -d "'"'" ' | cut -f1 -d=)"
            local value="$(echo "${line/ARG /}" | tr -d "'"'" ' | cut -f2- -d= | cut -f1 -d'#')"
            eval "local $var=\"$value\""
            ;;
        esac
    done
}

parse_ansible_ingredients () {
    while IFS= read yaml; do
        while IFS= read line; do
            case "$line" in
            *_ver:*|*_VER:*|*_version:*|*_VERSION:*|*_repo:*|*_REPO:*|*_repository:*|*_REPOSITORY:*|*_pkg:*|*_PKG:*|*_package:*|*_PACKAGE:*|*_image:*|*_IMAGE:*)
                local var="$(echo "$line" | cut -f1 -d: | tr -d '"'"' ")"
                local value="$(echo "$line" | sed 's/[^:]*:\s*\(.*[^ ]\)\s*$/\1/' | sed 's/{{ *\([^ }]*\) *}}/${\1}/g' | tr -d '"'"' " | cut -f1 -d'#')"
                eval "local $var=\"$value\""
                eval "local value=\"$value\""
                echo "ARG ${var^^}=$value"
                ;;
            esac
        done < "$yaml"
    done
}

build_commits () {
    local commit_id="$(flock /dev/urandom cat /dev/urandom | tr -dc '0-9a-f' | head -c 40)"
    if git --version > /dev/null 2>&1; then
        commit_id="$(cd "$PROJECTROOT"; GIT_SSH_COMMAND='ssh -o BatchMode=yes' GIT_ASKPASS=echo flock .git git rev-parse HEAD 2> /dev/null || true)"
        local branch_id=""
        local show_ref="$(cd "$PROJECTROOT";GIT_SSH_COMMAND='ssh -o BatchMode=yes' GIT_ASKPASS=echo flock .git git show-ref 2> /dev/null | grep -F "$commit_id" || true)"
        if [[ "$RELEASE" = :v* ]]; then
            branch_id="$(echo "$show_ref" | grep -m1 -E "refs/tags/${RELEASE#:}\$" | cut -f2- -d/)"
            [ -n "$branch_id" ] || branch_id="$(echo "$show_ref" | grep -m1 -E "refs/remotes/.*/${RELEASE#:v}\$" | cut -f3- -d/)"
        fi
        [ -n "$branch_id" ] || branch_id="$(echo "$show_ref" | grep -m1 -E "refs/tags/" | cut -f2- -d/)"
        [ -n "$branch_id" ] || branch_id="$(echo "$show_ref" | grep -m1 -E "refs/remotes/" | cut -f3- -d/)"
        [ -z "$branch_id" ] || echo "--label BUILD_BRANCH=$branch_id"
    fi
    echo "--label BUILD_COMMIT_ID=$commit_id"
}

macro_replacement () {
    (   
        cd "$SOURCEROOT/$1"
        for file1 in *.m4; do
            if [[ "$file1" != *"-config.yaml.m4" ]] && [ -e "$file1" ]; then
                tmp="$(mktemp -p . "${file1%.m4}.tmpm4.XXXX")"
                echo "$SOURCEROOT/$1/$tmp"
                m4 -Itemplate -I"$PROJECTROOT/template" -DPLATFORM=$PLATFORM -DIMAGEARCH=$IMAGEARCH -DIMAGESUFFIX=$IMAGESUFFIX -D$2="$3" -DREGISTRY=$REGISTRY -DBACKEND=$BACKEND -DRELEASE=$RELEASE $M4_OPTIONS "$file1" > "$tmp"
            fi
        done
        for file1 in *.j2; do
            if [[ "$file1" != *"-config.yaml.j2" ]] && [ -e "$file1" ]; then
                tmp="$(mktemp -p . "${file1%.j2}.tmpj2.XXXX")"
                echo "$SOURCEROOT/$1/$tmp"
                ansible all -i "localhost," -c local -m template -a "src=\"$file1\" dest=\"$tmp\"" -e PLATFORM=$PLATFORM -e IMAGEARCH=$IMAGEARCH -e IMAGESUFFIX=$IMAGESUFFIX -e $2="$3" -e REGISTRY=$REGISTRY -e BACKEND=$BACKEND -e RELEASE=$RELEASE $J2_OPTIONS -o 1>&2
            fi
        done
    )
}

# ingredient.yaml dockerfile
upgrade_ingredients () {
    p=1
    s=0
    c=1
    f=1
    var=()
    from=()
    to=()

    while IFS= read line; do
        if [ "${line// /}" = "---" ]; then
            [ $p -eq 1 ] && [ $s -eq 1 ] && [ $c -eq 1 ] && [ $f -eq 1 ] && \
            [ ${#var[@]} -eq ${#from[@]} ] && [ ${#from[@]} -eq ${#to[@]} ] && [ ${#to[@]} -gt 0 ] && break

            p=1
            s=0
            c=1
            f=1
            var=()
            from=()
            to=()
        elif [[ "${line// /}" != "#"* ]] && [ -n "${line// /}" ]; then
            k="$(echo "$line" | cut -f1 -d: | sed -e 's|^ *||' -e 's| *$||' | tr -d "\"'")"
            v="$(echo "$line" | cut -f2- -d: | sed -e 's|^ *||' -e 's| *$||')"

            if [[ "$v" = "'"* ]]; then
                v="${v#"'"}"
                v="${v%"'"}"
            elif [[ "$v" = '"'* ]]; then
                v="${v#'"'}"
                v="${v%'"'}"
            fi
            case "$k" in
            PLATFORM)
                [ "$v" = "$PLATFORM" ] || p=0
                ;;
            SOURCEROOT)
                [ "$v" = "${SOURCEROOT#"$PROJECTROOT/"}" ] && s=1
                ;;
            WORKLOAD)
                [ "$v" = "$WORKLOAD" ] || c=0
                ;;
            STACK)
                [ "$v" = "$STACK" ] || c=0
                ;;
            DOCKERFILE)
                [ "$2" = "./$v" ] || [[ "$2" = "./$v.tmp"* ]] || f=0
                ;;
            FROM)
                from+=($v)
                ;;
            TO)
                to+=($v)
                ;;
            *)
                [ -n "$k" ] && var+=($k)
                ;;
            esac
        fi
    done < <(echo "---"; cat "$1"; echo "---")

    if [ $p -eq 1 ] && [ $s -eq 1 ] && [ $c -eq 1 ] && [ $f -eq 1 ] && \
       [ ${#var[@]} -eq ${#from[@]} ] && [ ${#from[@]} -eq ${#to[@]} ] && [ ${#to[@]} -gt 0 ]; then

        while IFS= read line; do
            if [[ "${line// /}" = ARG*=* ]]; then
                local k="$(echo "$line" | sed 's/^ *ARG *\([^ =]*\).*$/\1/')"
                local v="$(echo "$line" | sed -e 's/^[^=]*= *\(.*\)$/\1/' -e 's/ *$//')"
                for i in $(seq 0 $(( ${#var[@]} - 1 ))); do
                    [ "$k" = "${var[$i]}" ] && [ "$v" = "${from[$i]}" ] && line="ARG $k=${to[$i]}"
                done
            fi
            echo "$line"
        done < <(cat "$2"; echo)

    else
        cat "$2"
    fi
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
        if [[ "$file1" = */* ]]; then
            options="$options-path ${file1} -o "
        else
            options="$options-name ${file1} -o "
        fi
    done
    FIND_OPTIONS="$FIND_OPTIONS ( ${options% -o } )"
fi

BUILD_CONTEXT=(${BUILD_CONTEXT[@]:-.})
[ ${#DOCKER_CONTEXT[@]} -eq 0 ] || BUILD_CONTEXT=(${DOCKER_CONTEXT[@]})

FIND_OPTIONS="$(echo "x$FIND_OPTIONS" | sed -e 's/^x//' -e 's/\([(*?)]\)/\\\1/g' -e 's/\\\\\([(*?)]\)/\\\1/g')"
# file lock
(
    flock -e 9

    # template substitution
    tmp_files=()
    trap 'rm -f "${tmp_files[@]}";exit 0' SIGTERM SIGINT SIGKILL ERR EXIT

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
    
        parse_ansible_ingredients < <(eval "find \"$SOURCEROOT/template/ansible\" \\( -path \"*/defaults/*.yaml\" -o -path \"*/defaults/*.yml\" -o -path \"*/defaults/*/*.yaml\" -o -path \"*/defaults/*/*.yml\" \\) $FIND_OPTIONS \\( -name \"*.yaml\" -o -name \"*.yml\" \\) -print" 2> /dev/null)
    fi
    
    build_options=(
        $(compgen -e | sed -nE '/_(proxy|PROXY)$/{s/^/--build-arg /;p}')
        --platform $IMAGEARCH
        --build-arg RELEASE=$RELEASE
        --build-arg IMAGESUFFIX=$IMAGESUFFIX
        --label BUILD_ID=$(flock /dev/urandom cat /dev/urandom | tr -dc '0-9a-f' | head -c 64)
        $(build_commits)
    )

    if [[ "$@" != *"--export-dockerfile"* ]]; then
        build_options+=(--build-arg BUILDKIT_INLINE_CACHE=1)
    fi
    
    if [[ "$@" != *"--export-dockerfile"* ]]; then
        if [ -r "$HOME/.netrc" ]; then
            build_options+=(--secret id=.netrc,src=$HOME/.netrc)
        elif [ -r "/root/.netrc" ]; then
            build_options+=(--secret id=.netrc,src=/root/.netrc)
        fi
    fi
    
    for dc in "${BUILD_CONTEXT[@]}"; do
        pushd "$SOURCEROOT/$dc" > /dev/null
        for pat in '.9.*' '.8.*' '.7.*' '.6.*' '.5.*' '.4.*' '.3.*' '.2.*' '.1.*' '.tmpj2.*' '.tmpm4.*' ''; do
            for dockerfile in $(eval "find . -maxdepth 1 -name \"Dockerfile$pat\" ! -name \"*.m4\" ! -name \"*.j2\" $FIND_OPTIONS -name \"Dockerfile*\" -print" 2>/dev/null); do
                image="$(head -n 2 "$dockerfile" | grep -E '^#+ ' | tail -n 1 | cut -d' ' -f2)$IMAGESUFFIX"
                header=$(head -n 2 "$dockerfile" | grep -E '^#+ ' | tail -n 1 | cut -d' ' -f1)
                IMAGE="$REGISTRY$image$RELEASE"

                if [[ "$@" = *"--upgrade-ingredients="* ]]; then
                    ingredients_yaml="$(echo "x$@" | sed -e 's/.*--upgrade-ingredients=//' -e 's/ .*//')"
                    if [ -r "$ingredients_yaml" ]; then
                        tmp="$(mktemp -p . "$dockerfile.tmp.XXXX")"
                        tmp_files+=("$SOURCEROOT/$dc/$tmp")
                        upgrade_ingredients "$ingredients_yaml" "$dockerfile" > "$tmp"
                        dockerfile="$tmp"
                    fi
                fi

                if [[ "$@" = *"--bom"* ]]; then
                    echo "$header image: $IMAGE"
                    parse_dockerfile_ingredients "ARG " < "$dockerfile"
                elif [[ "$@" != *"--read-only-registry"* ]]; then
                    if [[ "$@" = *"--export-dockerfile"* ]]; then
                        dist_docker_file="$PROJECTROOT/dist/dockerfile/dockerfile.$PLATFORM.$image"
                        mkdir -p "$(dirname "$dist_docker_file")"
                        sed -n '1,/^[^# ]/{/^[# ]/{p};/^[^# ]/{q}}' "$dockerfile" > "$dist_docker_file"
                        echo "#" >> "$dist_docker_file"
                        eval "echo \"# DOCKER_BUILDKIT=1 docker build $BUILD_OPTIONS "${build_options[@]}" -t $image -t $image$RELEASE $([ -n "$REGISTRY" ] && [ "$header" = "#" ] && echo -t $IMAGE) -f ${dist_docker_file#"$PROJECTROOT/"} ${SOURCEROOT#"$PROJECTROOT/"}/$dc\"" >> "$dist_docker_file"
                        echo "#" >> "$dist_docker_file"
                        sed -n '/^[^# ]/,${p}' "$dockerfile" >> "$dist_docker_file"
                    else
                        this_build_options=(
                            $(parse_dockerfile_ingredients "ARG_" < "$dockerfile" | sed "s|^\(.*\)$|--label \1|")
                            -t $image
                            -t $image$RELEASE 
                        )
                        if [ -n "$REGISTRY" ] && [ "$header" = "#" ]; then
                            this_build_options+=(-t $IMAGE)
                        fi
                        if [ -n "$DOCKER_CACHE_REGISTRY" ] && [ -n "$DOCKER_CACHE_REGISTRY_CACHE_TAG" ]; then
                            this_build_options+=(
                                --cache-from ${DOCKER_CACHE_REGISTRY%/}/$image:${DOCKER_CACHE_REGISTRY_CACHE_TAG#:}
                            )
                        fi
                        DOCKER_BUILDKIT=1 docker build $BUILD_OPTIONS "${build_options[@]}" "${this_build_options[@]}" -f "$dockerfile" . & 
                        wait
                    fi

                    # if REGISTRY is specified, push image to the private registry
                    if [ -n "$REGISTRY" ] && [ "$header" = "#" ]; then
                        [ "$BACKEND" = "atscale" ] && . "$PROJECTROOT/script/atscale/build.sh"
                        docker_push $IMAGE &
                        wait
                    fi
                fi
            done
        done
        popd > /dev/null
    done
) 9< "$SOURCEROOT/build.sh"

