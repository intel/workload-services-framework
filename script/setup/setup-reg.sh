#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/setup-common.sh

print_help () {
  echo "Usage: [options] <user>@<host>[:port] [<user>@<ip> ...]"
  echo ""
  echo "--port=<port>           Specify the SUT ssh port."
  echo "--force                 Force replacing any existing certificate."
  echo "--no-password           Do not ask for password. Use DEV_SUDO_PASSWORD and/or SUT_SSH_PASSWORD/SUT_SUDO_PASSWORD instead."
  echo "--nointelcert           Do not install Intel certificates."
  echo ""
  echo "<host> can be in the form of a FQDN hostname or an IP address."
  echo "The default registry port of a docker registry is 20666."
  echo "<user@ip> additional hosts that may need to access the registry."
  echo ""
  exit 3
}

if [ -z "$1" ]; then
  print_help
fi

reg_port=20666
ssh_port=22
reg_host=""
reg_user="$(id -un)"
sut_hosts=()
ansible_options=()
[ ! -e vars.yaml ] || ansible_options+=(-e "@vars.yaml")
setup_ansible_options=()
setup_native_options=()
replace="false"
last=""
for v in $@; do
  k1="$(echo "${v#--}" | cut -f1 -d=)"
  v1="$(echo "${v#--}" | cut -f2- -d= | sed 's/%20/ /g')"
  case "$v" in
  --help)
    print_help
    ;;
  --nointelcert)
    setup_native_options+=("$v")
    ;;
  --port=*)
    ssh_port="${v#--port=}"
    ;;
  --port)
    ;;
  --force)
    replace="true"
    ;;
  --no-password)
    setup_ansible_options+=("$v")
    setup_native_options+=("$v")
    export ANSIBLE_BECOME_EXE='echo "$DEV_SUDO_PASSWORD" | sudo -S'
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
    elif [ -z "$reg_host" ]; then
      reg_host="${v//:*/}"
      reg_host="${reg_host//*@/}"
      [[ "$v" != *"@"* ]] || reg_user="${v//@*/}"
      [[ "$v" != *":"* ]] || reg_port="${v//*:/}"
    elif [[ "$v" = *"@"* ]]; then
      sut_hosts+=("$v")
    else
      echo "Unsupported argument: $v"
      exit 3
    fi
    ;;
  esac
  last="$v"
done

if [[ "$reg_host" = *"localhost"* ]] || [[ "$reg_host" = *"127.0.0.1"* ]]; then
  echo "The registry host $reg_host must be fully qualified"
  exit 3
fi

./setup-ansible.sh "${setup_ansible_options[@]}" 2>&1 | tee setup-reg.logs
connection=local
[[ "$reg_host" = "$(hostname -f)"* ]] || [[ " $(hostname -i) " = *" $reg_host "* ]] || connection=ssh
reg_host_ssh="$([ "$connection" = "local" ] || echo "$reg_user@$reg_host")"
[[ "$reg_host_ssh${sut_hosts[@]}" != *"@"* ]] || ./setup-sut-native.sh --port $ssh_port $reg_host_ssh ${sut_hosts[@]} "${setup_native_options[@]}" 2>&1 | tee -a setup-reg.logs

. <(sed '/^# BEGIN WSF Setup/,/^# END WSF Setup/{d}' /etc/environment)
export http_proxy https_proxy no_proxy
rm -f /tmp/wsf-setup-ssh-* 2> /dev/null || true
ANSIBLE_ROLES_PATH=../terraform/template/ansible/common/roles ANSIBLE_INVENTORY_ENABLED=yaml ansible-playbook --flush-cache -vv -e wl_logs_dir="$DIR" -e my_ip_list=1.1.1.1 -e dev_cert_host="$reg_host" -e dev_registry_port="$reg_port" -e dev_cert_replace=$replace "${ansible_options[@]}" -i <(cat <<EOF
all:
  children:
    dev_hosts:
      hosts:
        dev_host:
          ansible_host: "127.0.0.1"
          private_ip: "127.0.0.1"
          ansible_connection: local
    reg_hosts:
      hosts:
        reg_host:
          ansible_host: "$reg_host"
          ansible_user: "$reg_user"
          private_ip: "$reg_host"
          ansible_port: "$ssh_port"
          ansible_connection: "$connection"
    cluster_hosts:
      hosts:
$(i=0
  for h in ${sut_hosts[@]}; do
  cat <<EOF2
        worker-$i:
          ansible_host: "${h/*@/}"
          ansible_user: "${h/@*/}"
          private_ip: "${h/*@/}"
          ansible_port: "$ssh_port"
EOF2
  i=$((i+1))
  done
)
EOF
) ./setup-reg.yaml 2>&1 | tee -a setup-reg.logs
rm -f timing.yaml

