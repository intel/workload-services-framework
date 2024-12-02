#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

data "external" "check_pool" {
  program = [
    "bash",
    "-c",
    "echo \"(virsh pool-list | grep -q -F \\\" ${var.pool_name} \\\") || (sudo mkdir -p /usr/local/${var.pool_name} && virsh pool-define <(echo \\\"<pool type='dir'><name>${var.pool_name}</name><target><path>/usr/local/${var.pool_name}</path></target></pool>\\\") && virsh pool-start ${var.pool_name} && virsh pool-autostart ${var.pool_name})\" | ssh -i ${var.ssh_pri_keyfile} -p ${var.kvm_host_port} ${var.kvm_host_user}@${var.kvm_host} bash -l > /dev/null;echo \"{\\\"status\\\":\\\"0\\\"}\""
  ]
}

