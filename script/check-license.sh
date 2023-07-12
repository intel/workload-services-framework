#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ ${#@} = 0 ]; then
    echo "Usage: <cache-file> <name>:<text> ..."
    exit 3
fi

check_access () {
    printf -- "$1\n"
    reply='n'
    read -p 'Type "accept" to proceed or anything else to skip: '
    [ "$REPLY" = "accept" ] || [ "$REPLY" = "ACCEPT" ]
}

check_history () {
    grep -qFx "$1" "$2" 2> /dev/null
}

cache="$1"
shift
while [ ${#@} -gt 0 ]; do
    name="${1/:*/}"
    text="${1#$name:}"
    shift
    if check_history "$name" "$cache"; then
        access=OK
    elif check_access "$text"; then
        access=OK
        echo "$name" >> "$cache"
    else
        access=denied
    fi
    if [ $access != OK ]; then
        echo
        echo "Access to $name denied. Build aborted."
        echo
        exit 1
    fi
done 
exit 0
