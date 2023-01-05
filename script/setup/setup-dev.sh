#!/bin/bash

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
cd "$DIR"

./setup-ansible.sh
ANSIBLE_ROLES_PATH=../terraform/template/ansible/docker/roles:../terraform/template/ansible/common/roles:../terraform/template/traces/roles ansible-playbook -vv --inventory 127.0.0.1, -e ansible_user="$(id -un)" -e "options=$@" -e my_ip_list=1.1.1.1 -e wl_logs_dir="$DIR" -K ./setup-dev.yaml
