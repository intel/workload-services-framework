#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  disks_flat = flatten([
    for k,v in local.instances : [
      for i in range(v.data_disk_spec!=null?(v.data_disk_spec.disk_type!="local"?v.data_disk_spec.disk_count:0):0) : {
        name = "vm-${k}-disk-${i}"
        instance = k
        disk_size = v.data_disk_spec.disk_size
        disk_type = v.data_disk_spec.disk_type
        disk_iops = v.data_disk_spec.disk_iops
        lun       = i
      }
    ]
  ])
}

locals {
  disks = {
    for dsk in local.disks_flat : dsk.name => {
      instance = dsk.instance
      disk_size = dsk.disk_size
      disk_type = dsk.disk_type
      disk_iops = dsk.disk_iops
      lun       = dsk.lun
    }
  }
}

resource "tencentcloud_cbs_storage" "default" {
  for_each = local.disks

  storage_name = format("wsf-%s-${each.key}-storage", substr(var.job_id,0,60-length("wsf--${each.key}-storage")))
  availability_zone = var.zone
  force_delete = true

  storage_size = each.value.disk_size
  storage_type = each.value.disk_type
  throughput_performance = contains(["CLOUD_TSSD", "CLOUD_HSSD"], each.value.disk_type) ? each.value.disk_iops : 0
  
  tags = var.common_tags
}

resource "tencentcloud_cbs_storage_attachment" "default" {
  for_each    = local.disks
  storage_id   = tencentcloud_cbs_storage.default[each.key].id
  instance_id = tencentcloud_instance.default[each.value.instance].id
}

data "template_cloudinit_config" "default" {
  for_each = local.instances
  gzip = false
  base64_encode = true
  part {
    filename = "init-shellscript"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/cloud-init.sh", {
      disks = [ for k,v in local.disks: {
        serial = each.value.data_disk_spec!=null?(each.value.data_disk_spec.disk_type!="local"?tencentcloud_cbs_storage.default[k].id:""):""
        mount_path = "/mnt/disk${v.lun+1}"
      } if v.instance == each.key ]
      disk_format = each.value.data_disk_spec!=null?each.value.data_disk_spec.disk_format:"ext4"
      disk_user  = local.os_user_name[each.value.os_type]
      disk_group = local.os_user_name[each.value.os_type]
    })
  }
}
