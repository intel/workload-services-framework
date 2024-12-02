#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

args=()
sudo="sudo"
for v in "$@"; do
  case "$v" in
  --help)
    echo "Usage: [options]"
    echo ""
    echo "--no-password    Do not ask for password. Use DEV_SUDO_PASSWORD instead."
    echo ""
    exit 3
    ;;
  --no-password)
    sudo="echo \"$DEV_SUDO_PASSWORD\" | sudo -S"
    ;;
  *)
    args+=("$v")
    ;;
  esac
done

min_core_version="2.11"
export DEBIAN_FRONTEND=noninteractive

check_ansible_version () {
  if ! ansible-playbook --version > /dev/null 2> /dev/null; then
    return 1
  else
    version="$(ansible-playbook --version 2> /dev/null | sed -n '/ansible-playbook.*core/{s/.*core \([0-9.]*\).*/\1/;p;q}')"
    if [ "$version" != "$min_core_version" ]; then
      if [ "$version" = "$(echo -e "$version\n$min_core_version" | sort -V | head -n1)" ]; then
        return 1
      fi
    fi
  fi
  return 0
}

remove_legacy_repo_apt () {
  for r in $@; do
    [ -r /etc/apt/sources.list ] && eval "$sudo sed -i 's|^\(deb.*$r\)|#\1|' /etc/apt/sources.list" || true
    for e in /etc/apt/sources.list.d/*.list; do
      [ -r $e ] && grep -s -q -E "deb.*$r" $e && eval "$sudo mv -f $e $e.save" || true
    done
  done
}

remove_legacy_repo_yum () {
  for r in $@; do
    for s in $(grep -E '^\s*baseurl\s*=\s*'$r -B 3 /etc/yum.repos.d/*.repo 2> /dev/null | sed -n '/\[.*\]/{s/.\[\(.*\)\].*/,\1/;p}'); do
      [ -r "${s%,*}" ] && eval "$sudo sed -i '/^\[${s#*,}\]/,/^ *$/{s/\(.*\)/#\1/}' ${s%,*}" || true
    done
  done
}

is_debian_10 () {
  . /etc/os-release
  [ "$ID" = "debian" ] || return 1
  if [ "$VERSION_ID" -lt "10" ]; then
    echo "$ID $VERSION_ID not supported."
    exit 3
  fi
  [ "$VERSION_ID" = "10" ]
}

if ! check_ansible_version; then
  if apt-get --version > /dev/null 2>&1; then
    remove_legacy_repo_apt http://apt.kubernetes.io/ https://dl.k8s.io/apt/doc/apt-key.gpg/
    if eval "$sudo -E apt-get update -y" 2>&1 | grep -q -E '^(E|Err):'; then
      echo "Detected a malfunctioning apt packaging system."
      echo "This could be possibly the result of"
      echo "  a wrong system datetime/timezone or"
      echo "  invalid repository entries."
      echo "Please fix the apt system such that apt-get update shows no error."
      exit 3
    fi
    eval "$sudo -E apt-get remove -y ansible" || true
    eval "$sudo -E apt-get remove -y ansible-core" || true
    eval "$sudo -E apt-get install -y software-properties-common"
    if is_debian_10; then
      eval "$sudo -E apt-get remove -y ansible" || true
      eval "$sudo -E apt-get remove -y ansible-core" || true
      eval "$sudo -H -E python3 -m pip uninstall -y ansible" | true
      eval "$sudo -H -E python3 -m pip uninstall -y ansible-core" | true
      eval "$sudo -E apt-get install -y python3-pip"
      eval "$sudo -H -E python3 -m pip install ansible==4.10.0"
    else
      (eval "$sudo -E apt-add-repository -u -y ppa:ansible/ansible" 2>&1 || echo E:) | grep -q -E '^(E|Err):' && eval "$sudo -E apt-add-repository --remove -y ppa:ansible/ansible" || true
      eval "$sudo -E apt-get install -y ansible"
    fi 
    eval "$sudo -E apt-get autoremove -y"
  elif yum --version > /dev/null 2> /dev/null; then
    remove_legacy_repo_yum https://packages.cloud.google.com/yum/repos/
    eval "$sudo -E yum remove -y ansible" || true
    if ! eval "$sudo -E yum install -y ansible"; then
      eval "$sudo -E yum install -y yum-utils"
      eval "$sudo -E yum-config-manager --add-repo=https://releases.ansible.com/ansible/rpm/release/epel-7-x86_64/"
      eval "$sudo -E yum install -y ansible"
    fi
  fi

  if ! check_ansible_version; then
    echo -e "\033[31mFailed to install latest ansible!\033[0m"
    echo -e "\033[31mYou might have configured multiple repositories, which\033[0m"
    echo -e "\033[31mcontain mixed ansible versions. Please remove/disable\033[0m"
    echo -e "\033[31mthe repositories that contain older ansible versions,\033[0m"
    echo -e "\033[31mand then rerun the setup script.\033[0m"
    exit 3
  fi
fi

if ! python3 -c 'import dns.resolver
import netaddr' 2> /dev/null; then
  if apt-get --version > /dev/null 2>&1; then
    eval "$sudo -E apt-get install -y python3-dnspython python3-netaddr"
  elif yum --version > /dev/null 2> /dev/null; then
    eval "$sudo -E yum install -y python3-dns python3-netaddr"
  fi
  if ! python3 -c 'import dns.resolver
import netaddr' 2> /dev/null; then
    echo -e "\033[31mFailed to install python3-dnspython!\033[0m"
    exit 3
  fi
fi

if [ ${#args[@]} -gt 0 ]; then
  if apt-get --version > /dev/null 2>&1; then
      eval "$sudo -E apt-get install -y ${args[@]}"
  elif yum --version > /dev/null 2> /dev/null; then
      eval "$sudo -E yum install -y ${args[@]}"
  fi
fi

if ! ansible-galaxy collection list 2> /dev/null | grep -q -F "ansible.utils"; then
  ansible-galaxy collection install ansible.utils
fi

if ! ansible-galaxy collection list 2> /dev/null | grep -q -F "ansible.netcommon"; then
  ansible-galaxy collection install ansible.netcommon
fi

if ! ansible-galaxy collection list 2> /dev/null | grep -q -F "ansible.windows"; then
  ansible-galaxy collection install ansible.windows
fi
