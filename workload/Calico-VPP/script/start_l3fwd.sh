#!/bin/bash -e
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

MTU=${MTU:-1500}
echo "Set interface MTU: $MTU"
ifconfig eth0 mtu "${MTU}"

echo "Start vpp"
vpp -c /etc/vpp/vpp.conf

sleep infinity
