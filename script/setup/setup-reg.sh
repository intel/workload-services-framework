#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ -z "$1" ]; then
  echo "Usage: [options] <host>[:port] [<user>@<ip> ...]"
  echo ""
  echo "--mirror=<url>          Launch as a pull-through cache registry."
  echo "--port=<port>           Specify the SUT ssh port."
  echo "--force                 Force replacing any existing certificate."
  echo ""
  echo "<host> can be in the form of a FQDN hostname or an IP address."
  echo "The default registry port of a docker registry is 20666."
  echo "The default registry port of a pull-through cache is 20690."
  echo "<user@ip> additional hosts that may need to access the registry."
  echo ""
  exit 3
fi

if [ -n "$SUDO_COMMAND" ]; then
    echo "!!!sudo detected!!!"
    echo "Please run setup-reg.sh as a regular user."
    exit 3
fi

reg_port=""
ssh_port=22
mirror_url=""
host=""
hosts=()
replace="false"
last=""
for v in $@; do
  case "$v" in
  --mirror=*)
    mirror_url="${v#--mirror=}"
    ;;
  --port=*)
    ssh_port="${v#--port=}"
    ;;
  --mirror|--port)
    ;;
  --force)
    replace="true"
    ;;
  *)
    if [ "$last" = "--mirror" ]; then
      mirror_url="$v"
    elif [ "$last" = "--port" ]; then
      ssh_port="$v"
    elif [ -z "$host" ]; then
      host="${v/:*/}"
      host="${host/*@/}"
      [[ "$v" != *":"* ]] || reg_port="${v/*:/}"
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

set -o pipefail
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
cd "$DIR"

./setup-ansible.sh 2>&1 | tee "$DIR"/setup-reg.logs
./setup-sut-native.sh --port $ssh_port ${hosts[@]} 2>&1 | tee -a "$DIR"/setup-reg.logs
if [ -z "$mirror_url" ]; then
  [[ -n "$reg_port" ]] || reg_port=20666
  options=""
else
  [[ "$mirror_url" = "http"* ]] || mirror_url="https://$mirror_url"
  [[ -n "$reg_port" ]] || reg_port=20690
  options="-e dev_registry_name=dev-cache -e dev_registry_mirror=$mirror_url"
fi

workers="$(i=0;for h in ${hosts[@]}; do cat <<EOF
        worker-$i:
          ansible_host: "${h/*@/}"
          ansible_user: "${h/@*/}"
          private_ip: "${h/*@/}"
          ansible_port: "$ssh_port"
EOF
i=$((i+1));done)"

ANSIBLE_INVENTORY_ENABLED=yaml ansible-playbook --flush-cache -vv -e dev_cert_host=$host -e dev_registry_port=$reg_port -e wl_logs_dir="$DIR" -e my_ip_list=1.1.1.1 -e dev_cert_replace=$replace $options -K -i <(cat <<EOF
all:
  children:
    cluster_hosts:
      hosts:
$workers
EOF
) ./setup-reg.yaml 2>&1 | tee -a "$DIR"/setup-reg.logs

