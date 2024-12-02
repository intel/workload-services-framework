#!/bin/bash -xe
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

pool_name="$1"
shift

var_envs="$(ssh $@ env)"
var_http_proxy="$(echo "$var_envs" | grep -i -E "^http_proxy=" | cut -f2- -d=)"
var_https_proxy="$(echo "$var_envs" | grep -i -E "^https_proxy=" | cut -f2- -d=)"
var_no_proxy="$(echo "$var_envs" | grep -i -E "^no_proxy=" | cut -f2- -d=)"
vol_list="$(ssh $@ sudo virsh vol-list --pool $pool_name | grep -E '(.img|.qcow2)' | cut -f2 -d' ' | tr '\n' ' ')"

cat <<EOF
{
  "http_proxy": "$var_http_proxy",
  "https_proxy": "$var_https_proxy",
  "no_proxy": "$var_no_proxy",
  "date_time": "$(date -Ins)",
  "time_zone": "$(timedatectl show --va -p Timezone 2> /dev/null || echo $TZ)",
  "vol_list": "$vol_list"
}
EOF
