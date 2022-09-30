#!/bin/bash -e

SDIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
REGISTRY=${CUMULUS_REGISTRY:-$REGISTRY}
RELEASE=${CUMULUS_RELEASE:-$RELEASE}

cloud=$1
shift
options=()
while [ "$1" != "--" ]; do
    options+=("$1")
    shift
done
shift

options+=(
    "--rm"
    "-e" "CUMULUS_OPTIONS=${CUMULUS_OPTIONS}"
    "-e" "PKB_USER=$(id -un)"
    "-e" "PKB_UID=$(id -u)"
    "-e" "PKB_GID=$(id -g)"
    "-e" "DOCKER_GID=$(getent group docker | cut -f3 -d:)"
    $(env | cut -f1 -d= | grep -E '_(proxy|PROXY)$' | sed 's/^/-e /')
    "-v" "/etc/localtime:/etc/localtime"
    "-v" "/var/run/docker.sock:/var/run/docker.sock"
    $(find "$SDIR" -name ".??*" -type d ! -name ".docker" ! -name ".gitconfig" ! -name ".ssh" -exec sh -c 'printf -- "-v\\n{}:/home/$(basename "{}")\\n-v\\n{}:/root/$(basename "{}")\\n"' \;)
)
[ -n "$REGISTRY" ] && options+=(
    "--pull" "always"
)
[ -r "$HOME"/.gitconfig ] && options+=(
    "-v" "$HOME/.gitconfig:/home/.gitconfig:ro"
    "-v" "$HOME/.gitconfig:/root/.gitconfig:ro"
)
[ -d "$HOME/.docker" ] && options+=(
    "-v" "$HOME/.docker:/home/.docker"
    "-v" "$HOME/.docker:/root/.docker"
)

docker run "${options[@]}" -i ${REGISTRY}cumulus-${cloud}${RELEASE} "$@"
