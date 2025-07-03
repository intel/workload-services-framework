#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

port="${server_index:generic}"
key="mongodb-$server_index-log"
cmd="APPEND"
eol="\\r\\n"

while IFS= read -r msg; do

    msg2="$msg\n"
    msg2=$(echo $msg | tr '$' '\$')"\n"

    output=""
    output+="*3$eol"
    output+="\$${#cmd}$eol"
    output+="$cmd$eol"
    output+="\$${#key}$eol"
    output+="$key$eol"
    output+="\$${#msg2}$eol"
    output+="${msg2}$eol"
    echo -e $output
done
