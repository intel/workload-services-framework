#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if [ -r "$1" ]; then
    grep -v -E '^\s*#' "$1"
else
    proxy_ip="$(curl -s ifconfig.me)"
    if [ "$proxy_ip" = "$(curl -s ipecho.net/plain)" ]; then
      echo "$proxy_ip/32"
    else
      echo "$(hostname -I | cut -f1 -d' ')/32"
    fi
fi

