#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

DIR="$( cd "$( dirname "$0" )" &> /dev/null && pwd )"

STACK="spdk_nvme_tcp_dsa_service" "$DIR"/../../stack/spdk-nvme-o-tcp-dsa/build.sh $@

. "$DIR"/../../script/build.sh


