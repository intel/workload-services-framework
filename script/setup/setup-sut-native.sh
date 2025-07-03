#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/setup-common.sh

print_help () {
    echo "Usage: [options] <user@ip> [<user@ip> ...]"
    echo ""
    echo "--port <port>    Specify the SUT ssh port."
    echo "--nointelcert    Do not install Intel certificates."
    echo "--no-password    Do not ask for password. Use DEV_SUDO_PASSWORD, SUT_SSH_PASSWORD and/or SUT_SUDO_PASSWORD instead."
    echo "--sut <file>[:#slices]  Specify the sut configuration file."
    echo ""
    exit 3
}

if [ ${#@} -lt 1 ]; then
    print_help
fi

parse_host_args "$@"
sshpass=()
setup_ansible_options+=()
ansible_options=(
  '-e' 'sut_update_proxy=true'
  '-e' 'sut_update_datetime=true'
)
[ ! -e vars.yaml ] || ansible_options+=(-e "@vars.yaml")
ssh_options=(
  -o ConnectTimeout=20
  -o ServerAliveInterval=30
  -o ServerAliveCountMax=10
)
intelcert=true
vm_group="worker"
last=""
for v in ${args}; do
  k1="$(echo "${v#--}" | cut -f1 -d=)"
  v1="$(echo "${v#--}" | cut -f2- -d= | sed 's/%20/ /g')"
  case "$v" in
  --no-password)
    sshpass=("sshpass" "-e")
    export SSHPASS="$SUT_SSH_PASSWORD"
    setup_ansible_options+=("$v")
    ssh_options+=(-o StrictHostKeyChecking=no)
    ;;
  --nointelcert)
    intelcert=false
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
    echo "Unsupported argument: $v"
    exit 3
    ;;
  esac
  last="$v"
done

if [ "$(ls -lnd "$HOME" | cut -f3-4 -d' ')" != "$(id -u) $(id -g)" ]; then
  echo "Your HOME directory is not owned by $(id -un):$(id -gn)"
  echo "Please fix ownership."
  exit 3
fi

if [ ${#sshpass[@]} -gt 0 ] && ! sshpass -V >/dev/null 2>/dev/null; then
  echo "sshpass not found. Please install sshpass."
  exit 3
fi

for host in ${controller_hosts[@]//:*/} ${worker_hosts[@]//:*/} ${client_hosts[@]//:*/}; do
    echo "Setting up passwordless ssh to $host..."
    "${sshpass[@]}" ssh-copy-id ${ssh_options[@]} -p $ssh_port "$host" || (
        echo "Generating self-signed key file..."
        printf "\n\n\n" | ssh-keygen -N "" || true
        "${sshpass[@]}" ssh-copy-id ${ssh_options[@]} -p $ssh_port "$host"
    )

    echo "Setting up passwordless sudo...(sudo password might be required)"
    username="$("${sshpass[@]}" ssh ${ssh_options[@]} -p $ssh_port "$host" id -un)"
    if [[ "$username" = *" "* ]]; then
        echo "Unsupported: username contains whitespace!"
        exit 3
    fi

    sudoerline="$username ALL=(ALL:ALL) NOPASSWD: ALL"
    if [ ${#sshpass[@]} -eq 0 ]; then
        ssh ${ssh_options[@]} -p $ssh_port -t "$host" sudo -p "\"[sudo] password for %u@%h:\"" bash -c "'grep -q -F \"$sudoerline\" /etc/sudoers || echo \"$sudoerline\" | EDITOR=\"tee -a\" visudo'"
    else
        echo "$SUT_SUDO_PASSWORD" | "${sshpass[@]}" ssh ${ssh_options[@]} -p $ssh_port "$host" sudo -S bash -c "'grep -q -F \"$sudoerline\" /etc/sudoers || echo \"$sudoerline\" | EDITOR=\"tee -a\" visudo'"
    fi
done 2>&1 | tee -a setup-sut-native.logs

./setup-ansible.sh "${setup_ansible_options[@]}" 2>&1 | tee -a setup-sut-native.logs

rm -f /tmp/wsf-setup-ssh-* 2> /dev/null || true
. <(sed '/^# BEGIN WSF Setup/,/^# END WSF Setup/{d}' /etc/environment) > /dev/null
export http_proxy https_proxy no_proxy
ANSIBLE_ROLES_PATH=../terraform/template/ansible/common/roles:../terraform/template/ansible/traces/roles ANSIBLE_INVENTORY_ENABLED=yaml ansible-playbook --flush-cache -vv -e mysut_config_name="$([[ "$(ps -p $(ps -o ppid= -p $$) -o comm=)" = "setup-"* ]] || echo "$sutname")" -e install_intelca=$intelcert -e wl_logs_dir="$DIR" -e my_ip_list=1.1.1.1 "${ansible_options[@]}" --inventory <(create_inventory) ./setup-sut-native.yaml 2>&1 | tee -a setup-sut-native.logs
rm -f timing.yaml

[[ "$(ps -p $(ps -o ppid= -p $$) -o comm=)" = "setup-"* ]] || show_tf_file 2>&1 | tee -a setup-sut-native.logs
