#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "local_file" "default" {
  count = length(local.instances)>0?1:0

  content = templatefile("${path.module}/templates/ssh-config.tpl", {
    hosts = join(" ",[for k,v in data.external.ip: v.result.ip])
    remote_user = var.kvm_host.user
    remote_host = var.kvm_host.host
    remote_port = var.kvm_host.port
  })

  filename = "${path.root}/ssh_config_${var.kvm_index}"
  file_permission = "0600"
}

