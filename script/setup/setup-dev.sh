#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
cd "$DIR"

if [ -n "$SUDO_COMMAND" ]; then
    echo "!!!sudo detected!!!"
    echo "Please run setup-dev.sh as a regular user."
    exit 3
fi

./setup-ansible.sh || exit 3
ANSIBLE_ROLES_PATH=../terraform/template/ansible/docker/roles:../terraform/template/ansible/common/roles:../terraform/template/traces/roles ansible-playbook --flush-cache -vv --inventory 127.0.0.1, -e ansible_user="$(id -un)" -e "options=$@" -e my_ip_list=1.1.1.1 -e wl_logs_dir="$DIR" -e compose=true -K ./setup-dev.yaml
