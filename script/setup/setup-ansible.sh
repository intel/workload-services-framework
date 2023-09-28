#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if ! ansible-playbook --version > /dev/null 2> /dev/null; then
  if apt --version > /dev/null 2>&1; then
    sudo -E apt install -y software-properties-common &&
    sudo -E apt-add-repository -y ppa:ansible/ansible &&
    sudo -E apt install -y ansible &&
    sudo -E apt autoremove -y
  elif yum --version > /dev/null 2> /dev/null; then
    if ! sudo -E yum install -y ansible; then
      sudo -E yum install -y yum-utils &&
      sudo -E yum-config-manager --add-repo=https://releases.ansible.com/ansible/rpm/release/epel-7-x86_64/ &&
      sudo -E yum -y update &&
      sudo -E yum install -y ansible
    fi
  fi
fi

if [ ${#@} -gt 0 ]; then
  if apt --version > /dev/null 2>&1; then
      sudo -E apt install -y $@
  elif yum --version > /dev/null 2> /dev/null; then
      sudo -E yum install -y $@
  fi
fi

