#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

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

if [ "$(ls -lnd "$HOME" | cut -f3-4 -d' ')" != "$(id -u) $(id -g)" ]; then
  echo "Your HOME directory is not owned by $(id -un):$(id -gn)"
  echo "Please fix ownership."
  exit 3
fi

set -o pipefail
DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

(
    if [ ! -r ~/.ssh/id_rsa ]; then
        echo "Generating self-signed key file..."
        yes y | ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
    fi
) 2>&1 | tee "$DIR"/setup-sut-native.logs

ssh_options=(
  -o ConnectTimeout=20
  -o ServerAliveInterval=30
  -o ServerAliveCountMax=10
)

for host in ${hosts[@]}; do
    echo "Setting up passwordless ssh to $host..."
    ssh-copy-id ${ssh_options[@]} -p $ssh_port "$host"

    echo "Setting up passwordless sudo...(sudo password might be required)"
    username="$(ssh ${ssh_options[@]} -p $ssh_port "$host" id -un)"
    if [[ "$username" = *" "* ]]; then
        echo "Unsupported: username contains whitespace!"
        exit 3
    fi

    sudoerline="$username ALL=(ALL:ALL) NOPASSWD: ALL"
    ssh ${ssh_options[@]} -p $ssh_port -t "$host" sudo bash -c "'grep -q -F \"$sudoerline\" /etc/sudoers || echo \"$sudoerline\" | EDITOR=\"tee -a\" visudo'"
done 2>&1 | tee -a "$DIR"/setup-sut-native.logs

