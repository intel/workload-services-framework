#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

set -o pipefail
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
cd "$DIR"

if [ -n "$SUDO_COMMAND" ]; then
    echo "!!!sudo detected!!!"
    echo "Please run setup-dev.sh as a regular user."
    exit 3
fi

./setup-ansible.sh 2>&1 | tee "$DIR"/setup-dev.logs
ANSIBLE_ROLES_PATH=../terraform/template/ansible/docker/roles:../terraform/template/ansible/common/roles:../terraform/template/traces/roles ANSIBLE_INVENTORY_ENABLED=host_list ansible-playbook --flush-cache -vv --inventory 127.0.0.1, -e ansible_user="$(id -un)" -e "options=$@" -e my_ip_list=1.1.1.1 -e wl_logs_dir="$DIR" -e compose=true -K ./setup-dev.yaml 2>&1 | tee -a "$DIR"/setup-dev.logs

echo -e "\033[31mPlease logout of the current SSH session and relogin for docker settings to take effect.\033[0m"
