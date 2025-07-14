#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  ebs_device_names = [
    "/dev/vdb",
    "/dev/vdc",
    "/dev/vdd",
    "/dev/vde",
    "/dev/vdf",
    "/dev/vdg",
    "/dev/vdh",
    "/dev/vdi",
    "/dev/vdj",
    "/dev/vdk",
  ]
}

locals {
  ebs_disks_flat = flatten([
    for k,v in local.instances : [
      for i in range(v.data_disk_spec!=null?v.data_disk_spec.disk_count:0) : {
        name = "vm-${k}-disk-${i}"
        instance = k
        disk_size = v.data_disk_spec.disk_size
        disk_format = v.data_disk_spec.disk_format
        disk_pool = v.data_disk_spec.disk_pool
        lun       = i
      }
    ]
  ])
  ebs_disks = {
    for dsk in local.ebs_disks_flat : dsk.name => {
      instance = dsk.instance
      disk_size = dsk.disk_size
      disk_format = dsk.disk_format
      disk_pool = dsk.disk_pool
      device = local.ebs_device_names[dsk.lun]
      path = format("/mnt/disk%d", dsk.lun+1)
      lun = dsk.lun
    }
  }
}

data "external" "nvme" {
  count = length(local.instances)>0?1:0
  program = [ "${path.module}/scripts/nvme.sh", "-p", var.kvm_host.port, "${var.kvm_host.user}@${var.kvm_host.host}"]
}

resource "libvirt_volume" "data_disk" {
  for_each = {
    for k,v in local.ebs_disks: k=>v
      if (v.disk_pool==null?true:!startswith(element(split(",",v.disk_pool),v.lun),"/dev/"))
  }

  name = "wsf-${var.job_id}-${each.key}"
  pool = each.value.disk_pool!=null?element(
    split(",",each.value.disk_pool),
    each.value.lun
  ):libvirt_pool.default.0.name
  size = each.value.disk_size*1024*1024*1024
}

