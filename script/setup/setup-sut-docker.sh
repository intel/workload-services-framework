#!/bin/bash

if [ ${#@} -lt 1 ]; then
  echo "Usage: [options] <user@ip>"
  echo ""
  echo "--port port    Specify the SSH port."
  echo ""
  exit 3
fi

if [ -n "$SUDO_COMMAND" ]; then
    echo "!!!sudo detected!!!"
    echo "Please run setup-sut-docker.sh as a regular user."
    exit 3
fi

ssh_port=22
hosts=()
last=""
for v in $@; do
  case "$v" in
  --port=*)
    ssh_port="${v#--port=}"
    ;;
  --port)
    ;;
  *)
    if [ "$last" = "--port" ]; then
      ssh_port="$v"
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

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"
cd "$DIR"
./setup-ansible.sh
./setup-sut-native.sh --port $ssh_port ${hosts[@]}

ANSIBLE_ROLES_PATH=../terraform/template/ansible/docker/roles:../terraform/template/ansible/common/roles:../terraform/template/ansible/traces/roles ANSIBLE_INVENTORY_ENABLED=yaml ansible-playbook -vv -e wl_logs_dir="$DIR" -e my_ip_list=1.1.1.1 --inventory <(cat <<EOF
all:
  children:
    workload_hosts:
      hosts:
        worker-0: 
          ansible_host: "${hosts[0]/*@/}"
          ansible_user: "${hosts[0]/@*/}"
          private_ip: "${hosts[0]/*@/}"
          ansible_port: "$ssh_port"
    trace_hosts:
EOF
) ./setup-sut-docker.yaml

