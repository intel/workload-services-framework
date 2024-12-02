#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

var_envs="$(ssh $@ env)"
var_http_proxy="$(echo "$var_envs" | grep -m1 -i -E "^http_proxy=" | cut -f2- -d=)"
var_https_proxy="$(echo "$var_envs" | grep -m1 -i -E "^https_proxy=" | cut -f2- -d=)"
var_no_proxy="$(echo "$var_envs" | grep -m1 -i -E "^no_proxy=" | cut -f2- -d=)"

cat <<EOF
{
  "http_proxy": "$var_http_proxy",
  "https_proxy": "$var_https_proxy",
  "no_proxy": "$var_no_proxy"
}
EOF
