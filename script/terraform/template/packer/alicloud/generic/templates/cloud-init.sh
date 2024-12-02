#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ ! -d /home/${user_name} ]; then
    echo "${user_name} ALL = NOPASSWD: ALL" >> /etc/sudoers
    useradd ${user_name} --home /home/${user_name} --shell /bin/bash -m
fi

mkdir -p /home/${user_name}/.ssh
echo "${public_key}" > /home/${user_name}/.ssh/authorized_keys
chown -R ${user_name}:${user_name} /home/${user_name}/.ssh
chmod 700 /home/${user_name}/.ssh
chmod 400 /home/${user_name}/.ssh/authorized_keys

