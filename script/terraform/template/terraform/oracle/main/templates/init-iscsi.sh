#!/bin/bash
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

(cat | ssh -i ${ssh_access_key} ${user}@${host} bash) <<EOF
iscsiadm --version || (
    while true; do
        sudo apt-get update && sudo apt-get install -y open-iscsi && break
        sleep 1s
    done
    conf="/etc/iscsi/iscsid.conf"
    echo "node.startup=automatic" | sudo tee -a $conf
    echo "node.session.timeo.replacement_timeout=6000" | sudo tee -a $conf
    echo "node.conn[0].timeo.noop_out_interval=0" | sudo tee -a $conf
    echo "node.conn[0].timeo.noop_out_timeout=0" | sudo tee -a $conf
    echo "node.conn[0].iscsi.HeaderDigest=None" | sudo tee -a $conf
    sudo systemctl restart open-iscsi
)

%{ for disk in disks ~}
    sudo iscsiadm -m node -o new -T ${disk.iqn} -p ${disk.ip}:${disk.port}
    sudo iscsiadm -m node -T ${disk.iqn} -o update -n node.startup -v automatic
    sudo iscsiadm -m node -T ${disk.iqn} -p ${disk.ip}:${disk.port} -l
%{ endfor ~}

EOF

