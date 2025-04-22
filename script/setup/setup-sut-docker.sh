#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/setup-common.sh

print_help () {
  echo "Usage: [options] <user@ip>"
  echo ""
  echo "--port port    Specify the SSH port."
  echo "--nointelcert  Do not install Intel certificates."
  echo "--no-password  Do not ask for password. Use DEV_SUDO_PASSWORD, SUT_SSH_PASSWORD and/or SUT_SUDO_PASSWORD instead."
  echo "--worker       Specify a worker vm_group."
  echo "--client       Specify a client vm_group."
  echo "--controller   Specify a controller vm_group."
  echo "--sut <file>   Specify the sut configuration file."
  echo ""
  exit 3
}

if [ ${#@} -lt 1 ]; then
  print_help
fi

parse_host_args "${@}"
ansible_options=(
  '-e' 'docker_reset=true'
)
[ ! -e vars.yaml ] || ansible_options+=(-e "@vars.yaml")
setup_ansible_options=()
setup_native_options=()
last=""
for v in "${args[@]}"; do
  k1="$(echo "${v#--}" | cut -f1 -d=)"
  v1="$(echo "${v#--}" | cut -f2- -d= | sed 's/%20/ /g')"
  case "$v" in
  --nointelcert)
    setup_native_options+=("$v")
    ;;
  --no-password)
    setup_ansible_options+=("$v")
    setup_native_options+=("$v")
    ;;
  --*=*)
    validate_ansible_option $k1 $v
    setup_native_options+=("$v")
    ansible_options+=("-e" "$k1=$v1")
    ;;
  --no*)
    validate_ansible_option ${k1#no} $v
    setup_native_options+=("$v")
    ansible_options+=("-e" "${k1#no}=false")
    ;;
  --*)
    validate_ansible_option $k1 $v
    setup_native_options+=("$v")
    ansible_options+=("-e" "$k1=true")
    ;;
  *)
    echo "Unsupported argument: $v"
    exit 3
    ;;
  esac
  last="$v"
done

./setup-ansible.sh "${setup_ansible_options[@]}" 2>&1 | tee setup-sut-docker.logs
./setup-sut-native.sh --port $ssh_port --worker "${worker_hosts[@]}" --client "${client_hosts[@]}" --controller "${controller_hosts[@]}" "${setup_native_options[@]}" 2>&1 | tee -a setup-sut-docker.logs

. <(sed '/^# BEGIN WSF Setup/,/^# END WSF Setup/{d}' /etc/environment) > /dev/null
export http_proxy https_proxy no_proxy
rm -f /tmp/wsf-setup-ssh-* 2> /dev/null || true
ANSIBLE_ROLES_PATH=../terraform/template/ansible/docker/roles:../terraform/template/ansible/common/roles:../terraform/template/ansible/traces/roles ANSIBLE_INVENTORY_ENABLED=yaml ansible-playbook -vv -e wl_logs_dir="$DIR" -e compose=true -e my_ip_list=1.1.1.1 "${ansible_options[@]}" --inventory <(create_inventory) ./setup-sut-docker.yaml 2>&1 | tee -a setup-sut-docker.logs
rm -f timing.yam

create_tf_file 2>&1 | tee -a setup-sut-docker.logs
