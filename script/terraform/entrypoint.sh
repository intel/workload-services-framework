#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ -n "$DOCKER_GID" ]; then
    if grep -q -E '^docker:' /etc/group; then
        if [ "$DOCKER_GID" != "$(getent group docker | cut -f3 -d:)" ]; then
            groupmod -g $DOCKER_GID -o docker > /dev/null || true
        fi
    fi
fi

if [ -n "$TF_GID" ]; then
    if [ "$TF_GID" != "$(id -g tfu)" ]; then
        groupmod -g $TF_GID -o tfu > /dev/null || true
    fi
    if [ -n "$TF_UID" ]; then
        if [ "$TF_UID" != "$(id -u tfu)" ]; then
            usermod -u $TF_UID -g $TF_GID -o tfu > /dev/null || true
        fi
    fi
fi

# import any certificates
cp -f /usr/local/etc/wsf/certs/*.crt /usr/local/share/ca-certificates > /dev/null 2>&1 && update-ca-certificates > /dev/null 2>&1 || true

# change timezone if needed
if [ -n "$TZ" ]; then
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
fi
####INSERT####

chown tfu.tfu /home 2> /dev/null || true
[ -d "/home/.ssh" ] && chown tfu.tfu /home/.ssh 2> /dev/null || true
exec gosu tfu "$@"
