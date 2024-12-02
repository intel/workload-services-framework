#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "local_sensitive_file" "host" {
  content = yamlencode({
    all = {
      children = {
        winrm_hosts = {
          hosts = {
            hyperv_host = merge(local.winrm_common, {
              ansible_host = var.hpv_host.host
              ansible_user = local.configs.winrm_user
              ansible_password = local.configs.winrm_password
              ansible_port = var.hpv_host.port
            })
          }
        }
      }
    }
  })
  filename = "${path.root}/.inventory-${var.hpv_host.host}-vmhost.yaml"
  file_permission = "0600"
}

