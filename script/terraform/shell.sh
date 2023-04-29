#!/bin/bash -e

SDIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
REGISTRY=${TERRAFORM_REGISTRY:-$REGISTRY}
RELEASE=${TERRAFORM_RELEASE:-$RELEASE}

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
    $(compgen -e | sed -nE '/_(proxy|PROXY)$/{s/^/-e /;p}')
    "-v" "/etc/localtime:/etc/localtime:ro"
    "-v" "/etc/timezone:/etc/timezone:ro"
    "-v" "/var/run/docker.sock:/var/run/docker.sock"
    $(find "$SDIR/../csp" -name ".??*" -type d ! -name .docker ! -name .gitconfig ! -name .ssh ! -name .kube ! -name .diskv-temp -exec sh -c 'printf -- "-v\\n{}:/home/$(basename "{}")\\n-v\\n{}:/root/$(basename "{}")\\n"' \;)
)

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

docker run "${options[@]}" -i ${REGISTRY}terraform-${cloud}${RELEASE} "$@"
