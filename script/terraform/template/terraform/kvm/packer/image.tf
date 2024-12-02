#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  image_name = replace(lower(var.image_name),"_","-")
}

data "external" "check_image" {
  program = [
    "bash",
    "-c",
    "echo virsh vol-list --pool ${var.pool_name} | ssh -i ${var.ssh_pri_keyfile} -p ${var.kvm_host_port} ${var.kvm_host_user}@${var.kvm_host} bash -l | grep -q -F ' ${local.image_name} ';echo \"{\\\"status\\\":\\\"$?\\\"}\""
  ]

  lifecycle {
    postcondition {
      condition = self.result.status != "0"
      error_message = "${var.image_name} already exist."
    }
  }
}

