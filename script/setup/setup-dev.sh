#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/setup-common.sh

ansible_options=()
[ ! -e vars.yaml ] || ansible_options+=(-e "@vars.yaml")
setup_ansible_options=()
sshpass=()
loopback=""
last=""
for v in "$@"; do
  k1="$(echo "${v#--}" | cut -f1 -d=)"
  v1="$(echo "${v#--}" | cut -f2- -d= | sed 's/%20/ /g')"
  case "$v" in
  --help)
    echo "Usage: [options]"
    echo ""
    echo "--nodaemonize        Do not install daemonize."
    echo "--no-password        Do not ask for password. Use DEV_SUDO_PASSWORD instead."
    echo "--loopback [user@ip] Setup a loopback configuration."
    exit 0
    ;;
  --no-password)
    setup_ansible_options+=("$v")
    export ANSIBLE_BECOME_EXE='echo "$DEV_SUDO_PASSWORD" | sudo -S'
    ;;
  --loopback=*)
    loopback="${v#--loopback=}"
    ;;
  --loopback)
    loopback="$(hostname -f)"
    ;;
  --*=*)
    validate_ansible_option $k1 $v
    ansible_options+=("-e" "$k1=$v1")
    ;;
  --no*)
    validate_ansible_option ${k1#no} $v
    ansible_options+=("-e" "${k1#no}=false")
    ;;
  --*)
    validate_ansible_option $k1 $v
    ansible_options+=("-e" "$k1=true")
    ;;
  *)
    if [ "$last" = "--loopback" ]; then
      loopback="$v"
    else
      echo "Unsupported argument: $v"
      exit 3
    fi
    ;;
  esac
  last="$v"
done

./setup-ansible.sh "${setup_ansible_options[@]}" 2>&1 | tee setup-dev.logs
. <(sed '/^# BEGIN WSF Setup/,/^# END WSF Setup/{d}' /etc/environment)
export http_proxy https_proxy no_proxy
rm -f /tmp/wsf-setup-ssh-* 2> /dev/null || true
ANSIBLE_ROLES_PATH=../terraform/template/ansible/docker/roles:../terraform/template/ansible/common/roles:../terraform/template/traces/roles ANSIBLE_INVENTORY_ENABLED=host_list ansible-playbook --flush-cache -vv --connection=local -i 127.0.0.1, -e ansible_user="$(id -un)" -e my_ip_list=1.1.1.1 -e wl_logs_dir="$DIR" -e compose=true "${ansible_options[@]}" ./setup-dev.yaml 2>&1 | tee -a setup-dev.logs

if [ -n "$loopback" ]; then
  [[ "$loopback" = *"@"* ]] || loopback="$(id -un)@$loopback"
  sed -e 's|# "user_name":.*|"user_name": "'${loopback%@*}'",|' -e 's|"public_ip":.*|"public_ip": "'${loopback#*@}'",|' -e 's|"private_ip":.*|"private_ip": "'${loopback#*@}'",|' -e '/^ *output *"options" *{/,/}/{s|^ *value *= *{|  value = {\n    containerd_skip_configuration: true,\n    docker_skip_configuration: true,\n|}' "$DIR/../terraform/terraform-config.static.tf" > "$DIR/../terraform/terraform-config.self.tf"
  "$DIR"/setup-sut-native.sh $loopback $([[ "$@" != *"--no-password"* ]] || echo --no-password)
fi

echo -e "\033[31mPlease logout of the current SSH session and relogin for docker settings to take effect.\033[0m"

