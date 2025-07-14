#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
. "$DIR"/setup-common.sh

ansible_options=()
[ ! -e vars.yaml ] || ansible_options+=(-e "@vars.yaml")
setup_ansible_options=()
sshpass=()
self=""
last=""
for v in "$@"; do
  k1="$(echo "${v#--}" | cut -f1 -d=)"
  v1="$(echo "${v#--}" | cut -f2- -d= | sed 's/%20/ /g')"
  case "$v" in
  --help)
    echo "Usage: [options]"
    echo ""
    echo "--nodaemonize        Do not install daemonize."
    echo "--no-password        Do not ask for password. Use DEV_SUDO_PASSWORD instead."
    echo "--self [user@ip[:port]]   Setup a loopback configuration."
    exit 0
    ;;
  --no-password)
    setup_ansible_options+=("$v")
    export ANSIBLE_BECOME_EXE='echo "$DEV_SUDO_PASSWORD" | sudo -S'
    ;;
  --loopback=*|--self=*)
    self="${v##*=}"
    ;;
  --loopback|--self)
    self="$(hostname -f)"
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
    case "$last" in
    --loopback|--self)
      self="$v"
      ;;
    *)
      echo "Unsupported argument: $v"
      exit 3
      ;;
    esac
    ;;
  esac
  last="$v"
done

if [ -n "$self" ]; then
  [[ "$self" = *"@"* ]] || self="$(id -un)@$self"
  [[ "$self" = *":"* ]] || self="$self:22"
fi

./setup-ansible.sh "${setup_ansible_options[@]}" 2>&1 | tee setup-dev.logs
. <(sed '/^# BEGIN WSF Setup/,/^# END WSF Setup/{d}' /etc/environment)
export http_proxy https_proxy no_proxy
rm -f /tmp/wsf-setup-ssh-* 2> /dev/null || true
ANSIBLE_ROLES_PATH=../terraform/template/ansible/docker/roles:../terraform/template/ansible/common/roles:../terraform/template/traces/roles ANSIBLE_INVENTORY_ENABLED=host_list ansible-playbook --flush-cache -vv --connection=local -i 127.0.0.1, -e self_host="$self" -e ansible_user="$(id -un)" -e my_ip_list=1.1.1.1 -e wl_logs_dir="$DIR" -e compose=true "${ansible_options[@]}" ./setup-dev.yaml 2>&1 | tee -a setup-dev.logs

[ -z "$self" ] || sutname=self show_tf_file 2>&1 | tee -a setup-dev.logs

(
  echo -e "\033[31mPlease logout of the current SSH session and relogin for settings to take effect.\033[0m"
  echo ""
  echo "If your SUT is not the dev host, please use one of the setup-sut-* scripts to setup SUT environment."
  echo "- setup-sut-native.sh: Setup SUT to run native workloads."
  echo "- setup-sut-dockder.sh: Setup SUT to run docker or native workloads."
  echo "- setup-sut-k8s.sh: Setup SUT to run Kubernetes or native workloads."
  echo ""
  echo "New CLI installed after shell relogin:"
  echo "  wsf-config, wsf-build, wsf-test, wsf-kpi, and wsf-debug"
  echo "Documentation: doc/user-guide/executing-workload/cli.md"
) 2>&1 | tee -a setup-dev.logs

