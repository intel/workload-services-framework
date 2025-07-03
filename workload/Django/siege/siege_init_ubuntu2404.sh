#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

rm -rf /tmp/siege*

cd /home/scripts/

if [ "$TLS" == "0" ]; then
    SOURCE_FILE="/home/scripts/urls.txt"
else
    SOURCE_FILE="/home/scripts/urls_https.txt"
fi

sed -i 's/limit = 255/limit = 20000/g' ~/.siege/siege.conf
sed -i 's/json_output = true/json_output = false/g' ~/.siege/siege.conf

sed -i "s/localhost/$TARGET_ENDPOINT/g" /home/scripts/urls.txt
sed -i "s/localhost/$TARGET_ENDPOINT/g" /home/scripts/urls_https.txt

cmd="siege -c $WORKER -b -t $DURATION -f $SOURCE_FILE"

timeout $(($DURATION * 60 + 60 )) $cmd
