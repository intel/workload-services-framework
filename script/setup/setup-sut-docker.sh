#!/bin/bash

if [ ${#@} -lt 1 ]; then
  echo "Usage: <user@ip>"
  exit 3
fi

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
cd "$DIR"
./setup-ansible.sh

if [ ! -r ~/.ssh/id_rsa ]; then
  echo "Generating self-signed key file..."
  yes y | ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
fi

echo "Setting up passwordless ssh to $1..."
ssh-copy-id "$1"

echo "Setting up passwordless sudo..."
username="$(ssh "$1" id -un)"
if [[ "$username" = *" "* ]]; then
    echo "Unsupported: username contains whitespace!"
    exit 3
fi

sudoerline="$username ALL=(ALL:ALL) NOPASSWD: ALL"
ssh -t "$1" sudo bash -c "'grep -q -F \"$sudoerline\" /etc/sudoers || echo \"$sudoerline\" | EDITOR=\"tee -a\" visudo'"

ANSIBLE_ROLES_PATH=../terraform/template/ansible/docker/roles:../terraform/template/ansible/common/roles:../terraform/template/ansible/traces/roles ANSIBLE_INVENTORY_ENABLED=yaml ansible-playbook -vv -e wl_logs_dir="$DIR" -e my_ip_list=1.1.1.1 --inventory <(cat <<EOF
all:
  children:
    workload_hosts:
      hosts:
        worker-0: 
          ansible_host: ${1/*@/}
          ansible_user: ${1/@*/}
          private_ip: ${1/*@/}
    trace_hosts:
EOF
) ./setup-sut-docker.yaml

