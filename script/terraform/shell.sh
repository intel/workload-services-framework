#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

SDIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
cloud=${1:-static}
shift

options=()
while [ "$1" != "--" ]; do
    options+=("$1")
    shift
done
shift

options+=(
    "--rm"
    "-e" "TERRAFORM_OPTIONS"
    "-e" "TF_USER=$(id -un)"
    "-e" "TF_UID=$(id -u)"
    "-e" "TF_GID=$(id -g)"
    "-e" "DOCKER_GID=$(getent group docker | cut -f3 -d:)"
    "-e" "TZ=$(timedatectl show --va -p Timezone 2> /dev/null || echo $TZ)"
    $(compgen -e | sed -nE '/_(proxy|PROXY)$/{s/^/-e /;p}')
    "-v" "/var/run/docker.sock:/var/run/docker.sock"
    "-v" "$SDIR/../..:/opt/project:ro"
    $(find "$SDIR/../csp" -name ".??*" -type d ! -name .docker ! -name .gitconfig ! -name .ssh ! -name .kube ! -name .netrc ! -name .diskv-temp -exec sh -c 'printf -- "-v\\n{}:/home/$(basename "{}")\\n-v\\n{}:/root/$(basename "{}")\\n"' \;)
)

if [ -n "$REGISTRY$TERRAFORM_REGISTRY" ]; then
    options+=(
        "--pull" "always"
    )
fi

# if used a different release, use its native script/template
if [[ -z "$TERRAFORM_REGISTRY$TERRAFORM_RELEASE" ]]; then
    options+=(
        "-v" "$SDIR:/opt/terraform:ro"
    )
fi

if [ -d "/usr/local/etc/wsf" ]; then
    options+=(
        "-v" "/usr/local/etc/wsf:/usr/local/etc/wsf:ro"
    )
fi

if [ -r "$HOME"/.gitconfig ]; then
    gitconfig_path="$(readlink -e "$HOME/.gitconfig")"
    options+=(
        "-v" "$gitconfig_path:/home/.gitconfig:ro"
        "-v" "$gitconfig_path:/root/.gitconfig:ro"
    )
fi

if [ -d "$HOME/.docker" ]; then
    dockerconfig_path="$(readlink -e "$HOME/.docker")"
    options+=(
        "-v" "$dockerconfig_path:/home/.docker"
        "-v" "$dockerconfig_path:/root/.docker"
    )
fi

if [ -d "$HOME/.ssh" ]; then
    sshconfig_path="$(readlink -e "$HOME/.ssh")"
    options+=(
        "-v" "$sshconfig_path:/home/.ssh"
        "-v" "$sshconfig_path:/root/.ssh"
    )
fi

if [ -r "$HOME/.netrc" ]; then
    netrconfig_path="$(readlink -e "$HOME/.netrc")"
    options+=(
        "-v" "$netrconfig_path:/home/.netrc:ro"
        "-v" "$netrconfig_path:/root/.netrc:ro"
    )
    if [ -n "$(find "$netrconfig_path" -perm /177 2>/dev/null)" ]; then
        echo "The ~/.netrc permission is too permissive."
        echo "Consider chmod 600 ~/.netrc instead."
        exit 3
    fi
fi

terraform_image="${TERRAFORM_REGISTRY:-$REGISTRY}terraform-${cloud}${TERRAFORM_RELEASE:-$RELEASE}"
docker run "${options[@]}" -e TERRAFORM_IMAGE=$terraform_image $terraform_image "$@"
