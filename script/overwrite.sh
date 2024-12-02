#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ -r "$PROJECTROOT/script/$BACKEND/vars.sh" ]; then
    for _k in $(compgen -e); do
        eval "_v=\"\$$_k\""
        . "$PROJECTROOT/script/$BACKEND/vars.sh" "$_k" "$_v"
    done
fi

TESTCASE_OVERWRITE_WITHBKC=()
TESTCASE_OVERWRITE_CUSTOMIZED=()
if [ -r "$CTESTSH_CONFIG" ]; then
    _insection=0
    _prefix=undef
    [[ "$CTESTSH_CONFIG" = "${SOURCEROOT%/}/"* ]] && _overwrite="_withbkc" || _overwrite="_customized"
    while IFS= read _line; do
        _prefix1="$(echo "$_line" | sed 's/[^ ].*$//')"
        [[ "$_line" = "# ctestsh_config: ${SOURCEROOT%/}/"* ]] && _overwrite="_withbkc"
        [[ "$_line" = "# ctestsh_overwrite:"* ]] && _overwrite="_customized"
        [[ "$_line" = "#"* ]] && continue
        [[ "$_line" != *:* ]] && continue
        _k="$(echo "$_line" | cut -f1 -d: | sed -e 's|^ *||' -e 's| *$||' | tr -d "\"'")"
        _v="$(echo "$_line" | cut -f2- -d: | sed -e 's|^ *||' -e 's| *$||')"
        if [[ "$_v" = "'"* ]]; then
            _v="${_v#"'"}"
            _v="${_v%"'"}"
        elif [[ "$_v" = '"'* ]]; then
            _v="${_v#'"'}"
            _v="${_v%'"'}"
        fi
        [ $_prefix = undef ] && _prefix=${#_prefix1}
        if [ ${#_prefix1} -eq $_prefix ]; then
            case "$TESTCASE" in
            $_k)
                _insection=1;;
            *)
                _insection=0;;
            esac
        elif [ $_insection -gt 0 ] && [ ${#_prefix1} -gt $_prefix ]; then
            eval "_tmp=\"\$$_k\""
            if [ "$_v" != "$_tmp" ]; then
                if [ "$_overwrite" = "_withbkc" ]; then
                    TESTCASE_OVERWRITE_WITHBKC+=($_k)
                elif [ "$_overwrite" = "_customized" ]; then
                    TESTCASE_OVERWRITE_CUSTOMIZED+=($_k)
                fi
                echo "OVERWRITE: $_k=$_v"
            fi
            eval "export $_k=\"$_v\""
            if [ -r "$PROJECTROOT/script/$BACKEND/vars.sh" ]; then
                . "$PROJECTROOT/script/$BACKEND/vars.sh" "$_k" "$_v"
            fi
        fi
    done < <(sed 's/\r$//' "$CTESTSH_CONFIG"; echo)
    # save test config
    cp -f "$CTESTSH_CONFIG" "${LOGSDIRH:-$(pwd)}/test-config.yaml" > /dev/null 2>&1 || echo -n ""
fi
