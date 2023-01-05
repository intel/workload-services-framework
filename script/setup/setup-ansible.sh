#!/bin/bash

ansible --version > /dev/null 2> /dev/null || (
  apt --version > /dev/null 2> /dev/null && \
      sudo apt install -y software-properties-common && \
      sudo apt-add-repository -y ppa:ansible/ansible && \
      sudo apt install -y ansible-core && \
      sudo apt autoremove -y
  yum --version > /dev/null 2> /dev/null && \
      sudo yum install -y ansible-core
)

