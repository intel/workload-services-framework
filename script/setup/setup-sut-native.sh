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
    echo ""
    exit 3
}

if [ ${#@} -lt 1 ]; then
    print_help
fi

ssh_port=22
sshpass=()
controller_hosts=()
worker_hosts=()
client_hosts=()
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
for v in $@; do
  k1="$(echo "${v#--}" | cut -f1 -d=)"
  v1="$(echo "${v#--}" | cut -f2- -d= | sed 's/%20/ /g')"
  case "$v" in
  --help)
    print_help
    ;;
  --port=*)
    ssh_port="${v#--port=}"
    ;;
  --port)
    ;;
  --no-password)
    sshpass=("sshpass" "-e")
    export SSHPASS="$SUT_SSH_PASSWORD"
    setup_ansible_options+=("$v")
    ssh_options+=(-o StrictHostKeyChecking=no)
    ;;
  --nointelcert)
    intelcert=false
    ;;
  --controller)
    vm_group="controller"
    ;;
  --worker)
    vm_group="worker"
    ;;
  --client)
    vm_group="client"
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
    if [ "$last" = "--port" ]; then
      ssh_port="$v"
    elif [[ "$v" = *"@"* ]]; then
      case "$vm_group" in
      controller)
        controller_hosts+=("$v")
        ;;
      worker)
        worker_hosts+=("$v")
        ;;
      client)
        client_hosts+=("$v")
        ;;
      esac
    else
      echo "Unsupported argument: $v"
      exit 3
    fi
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

(
    if [ ! -r ~/.ssh/id_rsa ]; then
        echo "Generating self-signed key file..."
        yes y | ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa || true
    fi
) 2>&1 | tee setup-sut-native.logs

for host in ${controller_hosts[@]//:*/} ${worker_hosts[@]//:*/} ${client_hosts[@]//:*/}; do
    echo "Setting up passwordless ssh to $host..."
    "${sshpass[@]}" ssh-copy-id ${ssh_options[@]} -p $ssh_port "$host"

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

controllers="$(
  i=0
  for h in ${controller_hosts[@]}; do
    hh="${h/*@/}"
    h1="${hh/:*/}"
    h2="${hh/*:/}"
    cat <<EOF
        controller-$i: &controller-$i
          ansible_host: "${h1}"
          ansible_user: "${h/@*/}"
          private_ip: "${h2:-$h1}"
          ansible_port: "$ssh_port"
EOF
i=$((i+1));done)"

controllers_ref="$(i=0;for h in ${controller_hosts[@]}; do cat <<EOF
        controller-$i: *controller-$i
EOF
i=$((i+1));done)"

workers="$(
  i=0
  for h in ${worker_hosts[@]}; do
    hh="${h/*@/}"
    h1="${hh/:*/}"
    h2="${hh/*:/}"
    cat <<EOF
        worker-$i: &worker-$i
          ansible_host: "${h1}"
          ansible_user: "${h/@*/}"
          private_ip: "${h2:-$h1}"
          ansible_port: "$ssh_port"
EOF
i=$((i+1));done)"

workers_ref="$(i=0;for h in ${worker_hosts[@]}; do cat <<EOF
        worker-$i: *worker-$i
EOF
i=$((i+1));done)"

clients="$(
  i=0
  for h in ${client_hosts[@]}; do
    hh="${h/*@/}"
    h1="${hh/:*/}"
    h2="${hh/*:/}"
    cat <<EOF
        client-$i: &client-$i
          ansible_host: "${h1}"
          ansible_user: "${h/@*/}"
          private_ip: "${h2:-$h1}"
          ansible_port: "$ssh_port"
EOF
i=$((i+1));done)"

clients_ref="$(i=0;for h in ${client_hosts[@]}; do cat <<EOF
        client-$i: *client-$i
EOF
i=$((i+1));done)"

./setup-ansible.sh "${setup_ansible_options[@]}" 2>&1 | tee -a setup-sut-native.logs

rm -f /tmp/wsf-setup-ssh-* 2> /dev/null || true
. <(sed '/^# BEGIN WSF Setup/,/^# END WSF Setup/{d}' /etc/environment) > /dev/null
export http_proxy https_proxy no_proxy
ANSIBLE_ROLES_PATH=../terraform/template/ansible/common/roles:../terraform/template/ansible/traces/roles ANSIBLE_INVENTORY_ENABLED=yaml ansible-playbook --flush-cache -vv -e install_intelca=$intelcert -e wl_logs_dir="$DIR" -e my_ip_list=1.1.1.1 "${ansible_options[@]}" --inventory <(cat <<EOF
all:
  children:
    cluster_hosts:
      hosts:
$controllers
$workers
$clients
    controller_hosts:
      hosts:
$controllers_ref
    workload_hosts:
      hosts:
$workers_ref
    client_hosts:
      hosts:
$clients_ref
    trace_hosts:
      hosts:
$workers_ref
$clients_ref
    off_cluster_hosts:
      hosts:
EOF
) ./setup-sut-native.yaml 2>&1 | tee -a setup-sut-native.logs
rm -f timing.yaml

