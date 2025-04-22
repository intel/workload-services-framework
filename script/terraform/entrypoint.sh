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
ln -sf /usr/share/zoneinfo/$TZ /etc/localtime

# select nc.openbsd, nc.traditional, or ncat based on ssh/config
if grep -q -E '^ *ProxyCommand .*nc( |.* )[-][-][a-z][a-z]' /home/.ssh/config 2> /dev/null; then
  update-alternatives --set nc /usr/bin/ncat > /dev/null 2>&1 || true
elif grep -q -E '^ *ProxyCommand .*nc( |.* )[-][br]( |$)' /home/.ssh/config 2> /dev/null; then
  update-alternatives --set nc /usr/bin/nc.traditional > /dev/null 2>&1 || true
elif grep -q -E '^ *ProxyCommand .*nc( |.* )[-][cegGklnotuvCz]( |$)' /home/.ssh/config 2> /dev/null; then
  update-alternatives --set nc /usr/bin/ncat > /dev/null 2>&1 || true
fi

####INSERT####

chown tfu.tfu /home 2> /dev/null || true
exec gosu tfu "$@"
