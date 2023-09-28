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
    "-e" "TZ=$(timedatectl show | grep Timezone= | cut -f2 -d=)"
    $(compgen -e | sed -nE '/_(proxy|PROXY)$/{s/^/-e /;p}')
    "-v" "/etc/localtime:/etc/localtime:ro"
    "-v" "/var/run/docker.sock:/var/run/docker.sock"
    "-v" "$SDIR/../..:/opt/project:ro"
    $(find "$SDIR/../csp" -name ".??*" -type d ! -name .docker ! -name .gitconfig ! -name .ssh ! -name .kube ! -name .diskv-temp -exec sh -c 'printf -- "-v\\n{}:/home/$(basename "{}")\\n-v\\n{}:/root/$(basename "{}")\\n"' \;)
)

# if used a different release, use its native script/template
if [[ -z "$TERRAFORM_REGISTRY$TERRAFORM_RELEASE" ]]; then
    options+=(
        "-v" "$SDIR:/opt/terraform:ro"
    )
fi
if [ -r "$HOME"/.gitconfig ]; then
    options+=(
        "-v" "$HOME/.gitconfig:/home/.gitconfig:ro"
        "-v" "$HOME/.gitconfig:/root/.gitconfig:ro"
    )
fi

if [ -d "$HOME/.docker" ]; then
    options+=(
        "-v" "$HOME/.docker:/home/.docker"
        "-v" "$HOME/.docker:/root/.docker"
    )
fi

if [ -d "/usr/local/etc/wsf" ]; then
    options+=(
        "-v" "/usr/local/etc/wsf:/usr/local/etc/wsf:ro"
    )
fi

if [ -d "$HOME/.ssh" ]; then
    options+=(
        "-v" "$(readlink -e "$HOME/.ssh"):/home/.ssh"
        "-v" "$(readlink -e "$HOME/.ssh"):/root/.ssh"
    )
fi

terraform_image="${TERRAFORM_REGISTRY:-$REGISTRY}terraform-${cloud}${TERRAFORM_RELEASE:-$RELEASE}"
docker run "${options[@]}" -e TERRAFORM_IMAGE=$terraform_image $terraform_image "$@"
