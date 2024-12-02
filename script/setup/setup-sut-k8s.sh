#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/setup-common.sh

print_help () {
  echo "Usage: [options] <user@controller-ip[:private-ip]> <user>@worker-ip[:private-ip] [<user>@worker-ip[:private_ip]...]"
  echo ""
  echo "--port port    Specify the ssh port."
  echo "--nointelcert  Do not install Intel certificates."
  echo "--no-password  Do not ask for password. Use DEV_SUDO_PASSWORD, SUT_SSH_PASSWORD and/or SUT_SUDO_PASSWORD instead."
  echo "--worker       Specify the worker group."  
  echo "--client       Specify the client group."
  echo "--controller   Specify the controller group."
  echo ""
  exit 3
}

if [ ${#@} -lt 2 ]; then
  print_help
fi

ssh_port=22
controller_hosts=()
worker_hosts=()
client_hosts=()
setup_ansible_options=()
setup_native_options=()
ansible_options=(
  '-e' 'k8s_reset=true'
  '-e' 'containerd_reset=true'
  '-e' 'k8s_enable_registry=false'
)
[ ! -e vars.yaml ] || ansible_options+=(-e "@vars.yaml")
last=""
vm_group="controller"
for v in $@; do
  k1="$(echo "${v#--}" | cut -f1 -d=)"
  v1="$(echo "${v#--}" | cut -f2- -d= | sed 's/%20/ /g')"
  case "$v" in
  --help)
    print_help
    ;;
  --worker)
    vm_group=worker
    ;;
  --client)
    vm_group=client
    ;;
  --controller)
    vm_group=controller
    ;;
  --port=*)
    ssh_port="${v#--port=}"
    ;;
  --port)
    ;;
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
    if [ "$last" = "--port" ]; then
      ssh_port="$v"
    elif [[ "$v" = *"@"* ]]; then
      case "$vm_group" in
      controller)
        controller_hosts+=("$v")
        vm_group=worker
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

./setup-ansible.sh "${setup_ansible_options[@]}" 2>&1 | tee setup-sut-k8s.logs
./setup-sut-native.sh --port $ssh_port --controller ${controller_hosts[@]} --worker ${worker_hosts[@]} --client ${client_hosts[@]} "${setup_native_options[@]}" 2>&1 | tee -a setup-sut-k8s.logs

controller=${controller_hosts[0]}
controller_hh="${controller/*@/}"
controller_h1="${controller_hh/:*/}"
controller_h2="${controller_hh/*:/}"

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

. <(sed '/^# BEGIN WSF Setup/,/^# END WSF Setup/{d}' /etc/environment)
export http_proxy https_proxy no_proxy
rm -f /tmp/wsf-setup-ssh-* 2> /dev/null || true
ANSIBLE_ROLES_PATH=../terraform/template/ansible/kubernetes/roles:../terraform/template/ansible/common/roles:../terraform/template/ansible/traces/roles ANSIBLE_INVENTORY_ENABLED=yaml ansible-playbook --flush-cache -vv -e wl_logs_dir="$DIR" -e my_ip_list=1.1.1.1 "${ansible_options[@]}" --inventory <(cat <<EOF
all:
  children:
    cluster_hosts:
      hosts:
        controller-0: &controller-0
          ansible_host: "${controller_h1}"
          ansible_user: "${controller/@*/}"
          private_ip: "${controller_h2:-$controller_h1}"
          ansible_port: "$ssh_port"
$workers
$clients
    controller:
      hosts:
        controller-0: *controller-0
    workload_hosts:
      hosts:
$workers_ref
$clients_ref
    trace_hosts:
      hosts:
$workers_ref
$clients_ref
    off_cluster_hosts:
      hosts:
EOF
) ./setup-sut-k8s.yaml 2>&1 | tee -a setup-sut-k8s.logs
rm -f cluster-info.json timing.yaml
