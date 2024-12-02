#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

set -o pipefail
cd "$DIR"

if [ -n "$SUDO_COMMAND" ]; then
    echo "!!!sudo detected!!!"
    echo "Please run $(basename "$0") as a regular user."
    exit 3
fi

valid_ansible_options=()
validate_ansible_option () {
  [ ${#valid_ansible_options[@]} -gt 0 ] || valid_ansible_options=($(find "$DIR"/../terraform/template/ansible "$DIR"/roles -ipath '*/defaults/*' -name '*.yaml' -exec grep -E '^[a-zA-Z0-9_][a-zA-Z0-9_]*:' {} \; | cut -f1 -d:))
  if [[ " ${valid_ansible_options[@]} " != *" ${1%%:*} "* ]]; then
    echo "Unsupported argument: $2"
    exit 3
  fi
}

