#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

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
      lun = dsk.lun
      path = format("%s\\wsf-%s-%s-data-disk%d.vhdx", var.data_disk_path, var.job_id, dsk.instance, dsk.lun+1)
    }
  }
}

resource "null_resource" "data_disk" {
  for_each = local.ebs_disks

  triggers = {
    inventory = local_sensitive_file.host.filename
    disk_path = each.value.path
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i ${self.triggers.inventory} -t create ${path.module}/scripts/data-disk.yaml"
    environment = {
      DISK_PATH = self.triggers.disk_path
      DISK_SIZE = each.value.disk_size*1024*1024*1024
      DISK_TYPE = var.data_disk_vhd_type
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "ansible-playbook -i ${self.triggers.inventory} -t destroy ${path.module}/scripts/data-disk.yaml"
    environment = {
      DISK_PATH = self.triggers.disk_path
    }
  }
}

resource "null_resource" "os_disk" {
  for_each = local.instances

  triggers = {
    inventory = local_sensitive_file.host.filename
    dest = "${var.data_disk_path}\\wsf-${var.job_id}-${each.key}-osdisk.vhdx"
  }

  provisioner "local-exec" {
    command = "ansible-playbook -i ${self.triggers.inventory} -t create ${path.module}/scripts/resize.yaml"
    environment = {
      SRC = each.value.os_image!=null?each.value.os_image:local.os[each.value.os_type].path
      OS_DISK_PATH = var.os_disk_path
      DEST = self.triggers.dest
      SIZE = each.value.os_disk_size*1024*1024*1024
    }
  }

  provisioner "local-exec" {
    when = destroy
    command = "ansible-playbook -i ${self.triggers.inventory} -t destroy ${path.module}/scripts/resize.yaml"
    environment = {
      DEST = self.triggers.dest
    }
  }
}

