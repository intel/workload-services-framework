#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "libvirt_pool" "default" {
  count = length(local.instances)>0?1:0
  name = "wsf-${var.job_id}-pool-${var.kvm_index}"
  type = "dir"
  path = "/tmp/wsf-${var.job_id}-kvm${var.kvm_index}"
}

