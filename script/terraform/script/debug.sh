#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

argv=()
touches=()
last=""
for v in $@; do
  case "$v" in
  --touch=*)
    touches+=("${v#--touch=}")
    ;;
  --touch)
    ;;
  *)
    case "$last" in
    --touch)
      touches+=("$v")
      ;;
    *)
      argv+=("$v")
      ;;
    esac
    ;;
  esac
  last="$v"
done

OWNER="${argv[0]:-$( (git config user.name || id -un) 2> /dev/null)-}"
if [ -z "${argv[0]}" ]; then
    DIRPATH="$(pwd)"
    for cmakecache_path in "$DIRPATH/CMakeCache.txt" "$DIRPATH/../CMakeCache.txt" "$DIRPATH/../../CMakeCache.txt"; do
        if grep -q -E "^BACKEND:[^=]*=" "$cmakecache_path" 2> /dev/null; then
            backend="$(grep -m 1 -E "^BACKEND:[^=]*=" "$cmakecache_path" | cut -f2 -d=)"
            options="$(grep -m 1 -E "^${backend^^}_OPTIONS:[^=]*=" "$cmakecache_path" | cut -f2- -d=)"
            if [[ "$options" = *"--owner="* ]]; then
                OWNER="$(echo "x$options" | sed 's|.*--owner=\([^ ]*\).*|\1|')-"
            fi
            break
        fi
    done
fi
    
cmd="docker ps -f name=$(echo $OWNER | tr 'A-Z' 'a-z' | tr -c -d 'a-z0-9-' | sed 's|^\(.\{12\}\).*$|\1|')"
if [ ${#touches[@]} -gt 0 ]; then
    if [ "$($cmd | wc -l)" -lt 2 ]; then
        echo "No instances detected"
        exit 3
    fi
    for container in $($cmd --format '{{.ID}}'); do
        docker exec -u tfu -t $container touch "${touches[@]}" &
    done
    wait
else
    if [ "$($cmd | wc -l)" -ne 2 ]; then
        echo "None or multiple instances detected:"
        echo ""
        $cmd --format '{{.Names}}\t{{.Status}}'
        echo ""
        echo "Please identify the instance with: wsf-debug <name prefix>"
        exit 3
    fi
    docker exec -u tfu -it $($cmd --format '{{.ID}}') bash
fi
