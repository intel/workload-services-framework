#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  ebs_device_names = [
    "/dev/sdb",
    "/dev/sdc",
    "/dev/sdd",
    "/dev/sde",
    "/dev/sdf",
    "/dev/sdg",
    "/dev/sdh",
    "/dev/sdi",
    "/dev/sdj",
    "/dev/sdk",
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
        lun       = i
      }
    ]
  ])
  ebs_disks = {
    for dsk in local.ebs_disks_flat : dsk.name => {
      instance = dsk.instance
      disk_size = dsk.disk_size
      disk_format = dsk.disk_format
      device = local.ebs_device_names[dsk.lun]
      path = format("/mnt/disk%d", dsk.lun+1)
    }
  }
}

resource "libvirt_volume" "data_disk" {
  for_each = local.ebs_disks

  name = "wsf-${var.job_id}-${each.key}"
  pool = libvirt_pool.default.0.name
  size = each.value.disk_size*1024*1024*1024
}

