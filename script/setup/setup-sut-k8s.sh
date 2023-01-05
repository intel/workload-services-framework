#!/bin/bash

if [ ${#@} -lt 2 ]; then
  echo "Usage: <user@controller-ip> <user>@worker-ip [<user>@worker-ip...]"
  exit 3
fi

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
cd "$DIR"
./setup-ansible.sh

if [ ! -r ~/.ssh/id_rsa ]; then
  echo "Generating self-signed key file..."
  yes y | ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
fi

for h in $@; do
  echo "Setting up passwordless ssh to $h..."
  ssh-copy-id $h

  echo "Setting up passwordless sudo..."
  username="$(ssh "$h" id -un)"
  if [[ "$username" = *" "* ]]; then
    echo "Unsupported: username contains whitespace!"
    exit 3
  fi

  sudoerline="$username ALL=(ALL:ALL) NOPASSWD: ALL"
  ssh -t "$h" sudo bash -c "'grep -q -F \"$sudoerline\" /etc/sudoers || echo \"$sudoerline\" | EDITOR=\"tee -a\" visudo'"
done

controller=$1
shift

k8s_taint="true"
for h in $@; do 
  if [ "${controller/*@/}" = "${h/*@/}" ]; then
    k8s_taint="false"
  fi
done

workers="$(i=0;for h in $@; do cat <<EOF
        worker-$i: &worker-$i
          ansible_host: ${h/*@/}
          ansible_user: ${h/@*/}
          private_ip: ${h/*@/}
EOF
i=$((i+1));done)"
workers_ref="$(i=0;for h in $@; do cat <<EOF
        worker-$i: *worker-$i
EOF
i=$((i+1));done)"

ANSIBLE_ROLES_PATH=../terraform/template/ansible/kubernetes/roles:../terraform/template/ansible/common/roles:../terraform/template/ansible/traces/roles ANSIBLE_INVENTORY_ENABLED=yaml ansible-playbook -vv -e wl_logs_dir="$DIR" -e my_ip_list=1.1.1.1 -e k8s_taint=$k8s_taint --inventory <(cat <<EOF
all:
  children:
    cluster_hosts:
      hosts:
        controller-0: &controller-0
          ansible_host: ${controller/*@/}
          ansible_user: ${controller/@*/}
          private_ip: ${controller/*@/}
$workers
    controller:
      hosts:
        controller-0: *controller-0
    workload_hosts:
      hosts:
$workers_ref
    trace_hosts:
EOF
) ./setup-sut-k8s.yaml
rm -f cluster-info.json
