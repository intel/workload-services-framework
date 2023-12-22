#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

OWNER="${1:-$( (git config user.name || id -un) 2> /dev/null)-}"
if [ -z "$1" ]; then
    DIRPATH="$(pwd)"
    while [[ "$DIRPATH" = */* ]]; do
        if [ -r "$DIRPATH/CMakeCache.txt" ]; then
            backend="$(grep "BACKEND:UNINITIALIZED=" "$DIRPATH/CMakeCache.txt" | cut -f2 -d=)"
            options="$(grep "${backend^^}_OPTIONS:UNINITIALIZED=" "$DIRPATH/CMakeCache.txt" | cut -f2- -d=)"
            if [[ "$options" = *"--owner="* ]]; then
                OWNER="$(echo "x$options" | sed 's|.*--owner=\([^ ]*\).*|\1|')-"
            fi
            break
        fi
        DIRPATH="${DIRPATH%/*}"
    done
fi
    
cmd="docker ps -f name=$(echo $OWNER | tr 'A-Z' 'a-z' | tr -c -d 'a-z0-9-' | sed 's|^\(.\{12\}\).*$|\1|')"
if [ "$($cmd | wc -l)" -ne 2 ]; then
    echo "None or multiple ctest instances detected:"
    echo ""
    $cmd --format '{{.Names}}\t{{.Status}}'
    echo ""
    echo "Please identify the instance with: ./debug.sh <name prefix>"
    exit 3
fi
docker exec -u tfu -it $($cmd --format '{{.ID}}') bash
