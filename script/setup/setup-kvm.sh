#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/setup-common.sh

print_help () {
  echo "Usage: [options] <user@ip[:dev]> [<user@ip>[:dev] ...]"
  echo ""
  echo "--nointelcert              Do not install Intel certificates."
  echo "--port port                Specify the SSH port"
  echo "--hugepage sz/n            Setup hugepage: 2M/1024 or 1G/4"
  echo "--reboot                   Reboot SUT if required"
  echo "--mtu n                    Set the VXLAN MTU value"
  echo "--dev device               Set the VXLAN interface device"
  echo "--vxlan                    Setup VXLAN"
  echo "--reset                    Reset VXLAN"
  echo "--no-password  Do not ask for password. Use DEV_SUDO_PASSWORD, SUT_SSH_PASSWORD and/or SUT_SUDO_PASSWORD instead."
  echo ""
  exit 3
}

if [ ${#@} -lt 1 ]; then
  print_help
fi

ssh_port=22
hosts=()
ansible_options=()
[ ! -e vars.yaml ] || ansible_options+=(-e "@vars.yaml")
setup_ansible_options=()
setup_native_options=()
hugepages=()
reboot="false"
mtu=1450
id=20667
dstport=20667
vxlan="false"
reset="false"
dev="eno1"
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
  --hugepage=*)
    hugepages+=("${v#*=}")
    ;;
  --hugepage)
    ;;
  --reboot)
    reboot="true"
    ;;
  --reset)
    reset="true"
    ;;
  --mtu=*)
    mtu="${v#--mtu=}"
    ;;
  --mtu)
    ;;
  --dev=*)
    dev="${v#--dev=}"
    ;;
  --dev)
    ;;
  --vxlan)
    vxlan="true"
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
    elif [ "$last" = "--hugepage" ]; then
      hugepages+=("$v")
    elif [ "$last" = "--mtu" ]; then
      mtu="$v"
    elif [ "$last" = "--dev" ]; then
      dev="$v"
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

./setup-ansible.sh python3-lxml python3-netaddr python3-libvirt "${setup_ansible_options[@]}" 2>&1 | tee setup-kvm.logs
./setup-sut-native.sh --port $ssh_port ${hosts[@]} "${setup_native_options[@]}" 2>&1 | tee -a setup-kvm.logs

kvms="$(
  i=0
  for h in ${hosts[@]}; do
    if [[ "$h" = *:* ]]; then
      dev1="${h/*:/}"
    else
      dev1="$dev"
    fi
    h="${h/:*/}"
    cat <<EOF
        kvm-$i:
          ansible_host: "${h/*@/}"
          ansible_user: "${h/@*/}"
          ansible_port: "$ssh_port"
          kvm_vxlan_dev: "$dev1"
          kvm_vxlan_mtu: "$mtu"
          kvm_vxlan_mode: "$vxlan"
EOF
i=$((i+1));done)"

. <(sed '/^# BEGIN WSF Setup/,/^# END WSF Setup/{d}' /etc/environment)
export http_proxy https_proxy no_proxy
rm -f /tmp/wsf-setup-ssh-* 2> /dev/null || true
ANSIBLE_ROLES_PATH=../terraform/template/ansible/common/roles:../terraform/template/ansible/traces/roles ANSIBLE_INVENTORY_ENABLED=yaml ansible-playbook --flush-cache -vv --inventory <(cat <<EOF
all:
  children:
    kvm_hosts:
      hosts:
$kvms
    trace_hosts:
      hosts:
$kvms
EOF
) -e kvm_reboot=$reboot -e kvm_reset=$reset -e kvm_hugepages=$(echo "${hugepages[@]}" | tr 'A-Z ' 'a-z,') "${ansible_options[@]}" ./setup-kvm.yaml 2>&1 | tee -a setup-kvm.logs
rm -f timing.yaml

