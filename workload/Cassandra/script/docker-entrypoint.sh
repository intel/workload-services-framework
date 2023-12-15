#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
set -e

 if [ "$deploy_mode" == "cluster" ]; then
     /usr/local/bin/cluster.sh > cluster.log
 fi

 if [ "$deploy_mode" == "standalone" ]; then
    /usr/local/bin/standalone.sh > standalone.log
 fi

wait
