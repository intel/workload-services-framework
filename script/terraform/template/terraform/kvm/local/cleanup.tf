#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "null_resource" "cleanup" {
  count = length(local.instances)>0?1:0

  triggers = {
    prefix = "wsf-${var.job_id}"
    port = var.kvm_host.port
    keyfile = var.ssh_pri_key_file
    user = var.kvm_host.user
    host = var.kvm_host.host
  }

  provisioner "local-exec" {
    when = destroy
    command = "${path.module}/scripts/cleanup.sh -p ${self.triggers.port} -i ${self.triggers.keyfile} ${self.triggers.user}@${self.triggers.host}"
    environment = {
      PREFIX = self.triggers.prefix
    }
  }
}

