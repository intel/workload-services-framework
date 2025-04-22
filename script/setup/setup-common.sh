#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

set -o pipefail
cd "$DIR"

if [ -n "$SUDO_COMMAND" ]; then
    echo "!!!sudo detected!!!"
    echo "Please run $(basename "$0") as a regular user."
    exit 3
fi

valid_ansible_options=()
validate_ansible_option () {
  [ ${#valid_ansible_options[@]} -gt 0 ] || valid_ansible_options=($(find "$DIR"/../terraform/template/ansible "$DIR"/roles -ipath '*/defaults/*' -name '*.yaml' -exec grep -E '^[a-zA-Z0-9_][a-zA-Z0-9_]*:' {} \; | cut -f1 -d:))
  if [[ " ${valid_ansible_options[@]} " != *" ${1%%:*} "* ]]; then
    echo "Unsupported argument: $2"
    exit 3
  fi
}

_create_tf_file () {
  vmtype=$1
  shift
  if [ ${#@} -gt 0 ]; then
    i=0
    for h in $@; do
      hh="${h/*@/}"
      h1="${hh/:*/}"
      h2="${hh/*:/}"
      sed -i -e "/^variable *\"${vmtype}_profile\" *{/,/^}/{/^ *\"${vmtype}-0\": *{/{s/^\( *\)\(\"${vmtype}-0\": *{\)/\1\"${vmtype}-$i\": {\n\1  \"user_name\": \"${h/@*/}\",\n\1  \"public_ip\": \"$h1\",\n\1  \"private_ip\": \"${h2:-$h1}\",\n\1  \"ssh_port\": ${ssh_port:-22},\n\1},\n\1\2/}}" "$sutfile"
      sed -i -e "/^variable *\"${vmtype}_profile\" *{/,/^}/{/^ *\"${vmtype}-0\": *{/,/^}/{/\"user_name\":/,/^}/{/^ *\"${vmtype}-0\": *{/,/^ *}/{d}}}}" "$sutfile"
    done
  fi
}

create_tf_file () {
  cp -f "$DIR"/../terraform/terraform-config.static.tf "$sutfile"
  _create_tf_file worker ${worker_hosts[@]}
  _create_tf_file client ${client_hosts[@]}
  _create_tf_file controller ${controller_hosts[@]}
  echo -e "\033[31mscript/terraform/$(basename "$sutfile") is created to match your SUT setup.\033[0m"
  echo -e "\033[31mActivate it as follows:\033[0m"
  echo -e "\033[31m  cd build\033[0m"
  echo -e "\033[31m  cmake -DTERRAFORM_SUT=$(basename "$sutfile" | cut -f2 -d.) ..\033[0m"
}

create_inventory () {
  local workers="$(
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
      i=$((i+1))
    done)"
  local workers_ref="$(
      i=0
      for h in ${worker_hosts[@]}; do cat <<EOF
        worker-$i: *worker-$i
EOF
        i=$((i+1))
      done)"

  local clients="$(
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
        i=$((i+1))
      done)"
  local clients_ref="$(
      i=0
      for h in ${client_hosts[@]}; do cat <<EOF
        client-$i: *client-$i
EOF
        i=$((i+1))
      done)"

  local controllers="$(
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
        i=$((i+1))
      done)"
  local controllers_ref="$(
      i=0
      for h in ${controller_hosts[@]}; do cat <<EOF
        controller-$i: *controller-$i
EOF
        i=$((i+1))
      done)"

  cat <<EOF
all:
  children:
    cluster_hosts:
      hosts:
$controllers
$workers
$clients
    controller:
      hosts:
$controllers_ref
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
}

parse_host_args () {
  sutfile="$DIR/../terraform/terraform-config.mysut.tf"
  ssh_port=22
  vm_group="worker"
  controller_hosts=()
  worker_hosts=()
  client_hosts=()
  args=()
  last=""
  for v in $@; do
    case "$v" in
    --help)
      print_help
      ;;
    --port=*)
      ssh_port="${v#--port=}"
      ;;
    --port)
      ;;
    --sut=*)
      sutfile="$DIR/../terraform/terraform-config.${v#--sut=}.tf"
      ;;
    --sut)
      ;;
    --worker)
      vm_group="worker"
      ;;
    --client)
      vm_group="client"
      ;;
    --controller)
      vm_group="controller"
      ;;
    *)
      if [ "$last" = "--port" ]; then
        ssh_port="$v"
      elif [ "$last" = "--sut" ]; then
        sutfile="$DIR/../terraform/terraform-config.${v}.tf"
      elif [[ "$v" = *"@"* ]]; then
        case "$vm_group" in
        worker)
          worker_hosts+=("$v")
          ;;
        client)
          client_hosts+=("$v")
          ;;
        controller)
          controller_hosts+=("$v")
          vm_group="worker"
          ;;
        esac
      else
        args+=("$v")
      fi
      ;;
    esac
    last="$v"
  done
}

