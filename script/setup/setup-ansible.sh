#!/bin/bash

ansible-playbook --version > /dev/null 2> /dev/null || (
  apt --version > /dev/null 2> /dev/null && \
      sudo -E apt install -y software-properties-common && \
      sudo -E apt-add-repository -y ppa:ansible/ansible && \
      sudo -E apt install -y ansible && \
      sudo -E apt autoremove -y
  yum --version > /dev/null 2> /dev/null && \
      sudo -E yum install -y ansible
)

