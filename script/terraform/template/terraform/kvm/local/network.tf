#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

data "external" "ip" {
  for_each = local.instances

  program = [ "${path.module}/scripts/get-ip.sh", var.kvm_host.networks.0, libvirt_domain.default[each.key].network_interface.0.mac, "-p", var.kvm_host.port, "-i", var.ssh_pri_key_file, "${var.kvm_host.user}@${var.kvm_host.host}" ]
}

locals {
  winrm_lports = {
    for k,v in local.instances : k => var.winrm_lport + var.kvm_index*10 + index([ for k1,v1 in local.instances : k1 if local.is_windows[k1] ], k) if local.is_windows[k]
  }
}

resource "null_resource" "https" {
  for_each = local.winrm_lports

  provisioner "local-exec" {
    command = "ssh -fNL $LPORT:$IP:$RPORT -p $SSH_PORT -i $SSH_IDENT $SSH_USER@$SSH_HOST"
    environment = {
      LPORT     = each.value
      RPORT     = var.winrm_port
      IP        = data.external.ip[each.key].result.ip
      SSH_PORT  = var.kvm_host.port
      SSH_IDENT = var.ssh_pri_key_file
      SSH_USER  = var.kvm_host.user
      SSH_HOST  = var.kvm_host.host
    }
  }
}

