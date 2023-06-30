#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ ${#@} -lt 2 ]; then
  echo "Usage: [options] <user@controller-ip[:private-ip]> <user>@worker-ip[:private-ip] [<user>@worker-ip[:private_ip]...]"
  echo ""
  echo "--port port    Specify the ssh port."
  echo "--reset        Reset Kubernetes."
  echo "--purge        Reset Kubernetes and remove k8s packages."
  echo "--nointelcert  Do not install Intel certificates."
  echo ""
  exit 3
fi

if [ -n "$SUDO_COMMAND" ]; then
    echo "!!!sudo detected!!!"
    echo "Please run setup-sut-k8s.sh as a regular user."
    exit 3
fi

ssh_port=22
hosts=()
last=""
reset=false
purge=false
intelcert=true
for v in $@; do
  case "$v" in
  --port=*)
    ssh_port="${v#--port=}"
    ;;
  --port)
    ;;
  --reset)
    reset="true"
    ;;
  --purge)
    purge="true"
    reset="true"
    ;;
  --nointelcert)
    intelcert=false
    ;;
  *)
    if [ "$last" = "--port" ]; then
      ssh_port="$v"
    elif [[ "$v" = *"@"* ]]; then
      hosts+=("$v")
    else
      echo "Unsupported argument: $v"
      exit 3
    fi
    ;;
  esac
  last="$v"
done

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
cd "$DIR"
./setup-ansible.sh || exit 3
./setup-sut-native.sh --port $ssh_port $(echo ${hosts[@]} | sed 's|:[^ ]*||g') || exit 3

controller=${hosts[0]}
controller_hh="${controller/*@/}"
controller_h1="${controller_hh/:*/}"
controller_h2="${controller_hh/*:/}"

k8s_taint="true"
for h in ${hosts[@]:1}; do 
  if [ "${controller/*@/}" = "${h/*@/}" ]; then
    k8s_taint="false"
  fi
done

workers="$(
  i=0
  for h in ${hosts[@]:1}; do 
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
workers_ref="$(i=0;for h in ${hosts[@]:1}; do cat <<EOF
        worker-$i: *worker-$i
EOF
i=$((i+1));done)"

ANSIBLE_ROLES_PATH=../terraform/template/ansible/kubernetes/roles:../terraform/template/ansible/common/roles:../terraform/template/ansible/traces/roles ANSIBLE_INVENTORY_ENABLED=yaml ansible-playbook -vv -e install_intelca=$intelcert -e wl_logs_dir="$DIR" -e my_ip_list=1.1.1.1 -e k8s_taint=$k8s_taint -e k8s_reset=$reset -e k8s_purge=$purge --inventory <(cat <<EOF
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
    controller:
      hosts:
        controller-0: *controller-0
    workload_hosts:
      hosts:
$workers_ref
    trace_hosts:
EOF
) ./setup-sut-k8s.yaml
rm -f cluster-info.json
