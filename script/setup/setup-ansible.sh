#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

min_core_version="2.12"
export DEBIAN_FRONTEND=noninteractive

check_ansible_version () {
  if ! ansible-playbook --version > /dev/null 2> /dev/null; then
    return 1
  else
    version="$(ansible-playbook --version 2> /dev/null | sed -n '/ansible-playbook.*core/{s/.*core \([0-9.]*\).*/\1/;p;q}')"
    if [ "$version" != "$min_version" ]; then
      if [ "$version" = "$(echo -e "$version\n$min_core_version" | sort -V | head -n1)" ]; then
        return 1
      fi
    fi
  fi
  return 0
}

if ! check_ansible_version; then
  if apt --version > /dev/null 2>&1; then
    sudo -E apt remove -y ansible ansible-core || true
    sudo -E apt install -y software-properties-common &&
    sudo -E apt-add-repository -y ppa:ansible/ansible &&
    sudo -E apt install -y ansible &&
    sudo -E apt autoremove -y
  elif yum --version > /dev/null 2> /dev/null; then
    sudo -E yum remove -y ansible || true
    if ! sudo -E yum install -y ansible; then
      sudo -E yum install -y yum-utils &&
      sudo -E yum-config-manager --add-repo=https://releases.ansible.com/ansible/rpm/release/epel-7-x86_64/ &&
      sudo -E yum -y update &&
      sudo -E yum install -y ansible
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

if [ ${#@} -gt 0 ]; then
  if apt --version > /dev/null 2>&1; then
      sudo -E apt install -y $@
  elif yum --version > /dev/null 2> /dev/null; then
      sudo -E yum install -y $@
  fi
fi

