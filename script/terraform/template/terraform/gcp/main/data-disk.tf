#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  prohibit_set_iops_disktype = ["pd-standard", "pd-balanced", "pd-ssd"]
}

locals {
  pst_disks_flat = flatten([
    for k,v in local.vms : [
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
  pst_disks = {
    for dsk in local.pst_disks_flat : dsk.name => {
      instance = dsk.instance
      disk_size = dsk.disk_size
      disk_type = dsk.disk_type
      disk_iops = contains(local.prohibit_set_iops_disktype, dsk.disk_type) ? null : dsk.disk_iops
      lun       = dsk.lun
    }
  }
}

locals {
  device_root = var.instance_storage_interface=="NVME"?"/dev/disk/by-id/google-local-nvme-ssd":"/dev/disk/by-id/google-local-ssd"
}

resource "google_compute_disk" "default" {
  for_each = local.pst_disks
  name     = "wsf-${var.job_id}-${each.key}"
  project  = local.project_id
  labels   = var.common_tags
  size     = each.value.disk_size
  type     = each.value.disk_type
  provisioned_iops = each.value.disk_iops
}

resource "google_compute_attached_disk" "default" {
  for_each    = local.pst_disks
  disk        = google_compute_disk.default[each.key].id
  instance    = google_compute_instance.default[each.value.instance].id
  device_name = "wsf-data-disk-${each.value.lun}"
}

data "template_cloudinit_config" "default" {
  for_each = local.vms
  gzip = false
  base64_encode = false
  part {
    filename = "init-shellscript"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/cloud-init.sh", {
      disk_count  = each.value.data_disk_spec!=null?each.value.data_disk_spec.disk_count:0
      disk_format = each.value.data_disk_spec!=null?each.value.data_disk_spec.disk_format:"ext4"
      device_root = each.value.data_disk_spec!=null?(each.value.data_disk_spec.disk_type!="local"?"/dev/disk/by-id/google-wsf-data-disk":local.device_root):""
      disk_user   = local.os_image_user[each.value.os_type]
      disk_group  = local.os_image_user[each.value.os_type]
    })
  }
}

