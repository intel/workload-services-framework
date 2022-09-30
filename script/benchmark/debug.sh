#!/bin/bash -e

owner="${1:-$( (git config user.name || id -un) 2> /dev/null)-}"
cmd="docker ps -f name=$(echo $owner | tr 'A-Z' 'a-z' | tr -c -d 'a-z0-9-' | sed 's|^\(.\{12\}\).*$|\1|')"
if [ "$($cmd | wc -l)" -ne 2 ]; then
    echo "None or multiple ctest instances detected:"
    echo ""
    $cmd --format '{{.ID}} {{.Names}}'
    echo ""
    echo "Please identify the instance with: ./debug.sh <name prefix>"
    exit 3
fi
docker exec -u pkb -it $($cmd --format '{{.ID}}') bash
