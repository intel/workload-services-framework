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
  echo "--sut <file>   Specify the sut configuration file."
  echo ""
  exit 3
}

if [ ${#@} -lt 2 ]; then
  print_help
fi

parse_host_args --controller "$@"
setup_ansible_options=()
setup_native_options=()
ansible_options=(
  '-e' 'k8s_reset=true'
  '-e' 'containerd_reset=true'
  '-e' 'k8s_enable_registry=false'
)
[ ! -e vars.yaml ] || ansible_options+=(-e "@vars.yaml")
last=""
for v in ${args[@]}; do
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

./setup-ansible.sh "${setup_ansible_options[@]}" 2>&1 | tee setup-sut-k8s.logs
./setup-sut-native.sh --port $ssh_port --controller ${controller_hosts[@]} --worker ${worker_hosts[@]} --client ${client_hosts[@]} "${setup_native_options[@]}" 2>&1 | tee -a setup-sut-k8s.logs

. <(sed '/^# BEGIN WSF Setup/,/^# END WSF Setup/{d}' /etc/environment)
export http_proxy https_proxy no_proxy
rm -f /tmp/wsf-setup-ssh-* 2> /dev/null || true
ANSIBLE_ROLES_PATH=../terraform/template/ansible/kubernetes/roles:../terraform/template/ansible/common/roles:../terraform/template/ansible/traces/roles ANSIBLE_INVENTORY_ENABLED=yaml ansible-playbook --flush-cache -vv -e mysut_config_name="$sutname" -e wl_logs_dir="$DIR" -e my_ip_list=1.1.1.1 "${ansible_options[@]}" --inventory <(create_inventory) ./setup-sut-k8s.yaml 2>&1 | tee -a setup-sut-k8s.logs
rm -f cluster-info.json timing.yaml

show_tf_file 2>&1 | tee -a setup-sut-k8s.logs

is_controller_on_dev_host () {
  for h in ${controller_hosts[@]/:*/}; do
    [[ " $@ " != *" ${h/*@/} "* ]] || echo true
  done
}

if [[ "$(is_controller_on_dev_host $(hostname) $(hostname -f) $(hostname -i))" = *"true"* ]]; then
  (
    echo
    echo "Kubernetes requires to use a docker REGISTRY to serve images. If you use only official release images,"
    echo "then no more setup is required. Otherwise you must create a private registry (setup-reg.sh) and set it"
    echo "as follows:"
    echo "  cd build"
    echo "  wsf-config -DREGISTRY=<value>"
  ) 2>&1 | tee -a setup-sut-k8s.logs
else
  (
    echo
    echo "Kubernetes requires to use a docker REGISTRY to serve images. If you use only official release images,"
    echo "then no more setup is required. Otherwise do one of the following setup steps:"
    echo "(1) Setup a private registry (setup-reg.sh) and activate it as follows:"
    echo "  cd build"
    echo "  wsf-config -DREGISTRY=<value>"
    echo "(2) Set 'k8s_enable_registry: true' in script/terraform/terraform-config.$sutname.tf. An in-cluster registry"
    echo "will be created to serve images."
  ) 2>&1 | tee -a setup-sut-k8s.logs
fi
