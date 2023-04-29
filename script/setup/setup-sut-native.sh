#!/bin/bash

if [ ${#@} -lt 1 ]; then
    echo "Usage: [options] <user@ip> [<user@ip> ...]"
    echo ""
    echo "--port <port>   Specify the SUT ssh port."
    echo ""
    exit 3
fi

if [ -n "$SUDO_COMMAND" ]; then
    echo "!!!sudo detected!!!"
    echo "Please run setup-sut-native.sh as a regular user."
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

if [ ! -r ~/.ssh/id_rsa ]; then
  echo "Generating self-signed key file..."
  yes y | ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
fi

for host in ${hosts[@]}; do
    echo "Setting up passwordless ssh to $host..."
    ssh-copy-id -p $ssh_port "$host"

    echo "Setting up passwordless sudo...(sudo password might be required)"
    username="$(ssh -p $ssh_port "$host" id -un)"
    if [[ "$username" = *" "* ]]; then
        echo "Unsupported: username contains whitespace!"
        exit 3
    fi

    sudoerline="$username ALL=(ALL:ALL) NOPASSWD: ALL"
    ssh -p $ssh_port -t "$host" sudo bash -c "'grep -q -F \"$sudoerline\" /etc/sudoers || echo \"$sudoerline\" | EDITOR=\"tee -a\" visudo'"
done

