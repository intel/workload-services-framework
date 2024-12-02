#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  disks_flat = flatten([
    for k,v in local.vms : [
      for i in range(v.data_disk_spec!=null?(v.data_disk_spec.disk_type!="local"?v.data_disk_spec.disk_count:0):0) : {
        name = "vm-${k}-disk-${i}"
        instance = k
        disk_size = v.data_disk_spec.disk_size
        disk_type = v.data_disk_spec.disk_type
        lun = i
        disk_iops = v.data_disk_spec.disk_iops
        disk_throughput = v.data_disk_spec.disk_throughput
      }
    ]
  ])
  disks = {
    for dsk in local.disks_flat : dsk.name => {
      instance = dsk.instance
      disk_size = dsk.disk_size
      disk_type = dsk.disk_type
      lun = dsk.lun
      disk_iops = dsk.disk_iops
      disk_throughput = dsk.disk_throughput
    }
  }
  speed_adjustable_disk_types = [ 
    "PremiumV2_LRS", "UltraSSD_LRS" 
  ]
}

resource "azurerm_managed_disk" "default" {
  for_each             = local.disks
  name                 = "wsf-${var.job_id}-${each.key}-md"
  location             = local.location
  resource_group_name  = local.resource_group_name
  storage_account_type = each.value.disk_type
  create_option        = "Empty"
  disk_size_gb         = each.value.disk_size
  tags                 = var.common_tags
  zone                 = contains(local.speed_adjustable_disk_types, each.value.disk_type)?local.availability_zone:null
  disk_iops_read_write = contains(local.speed_adjustable_disk_types, each.value.disk_type)?each.value.disk_iops:null
  disk_mbps_read_write = contains(local.speed_adjustable_disk_types, each.value.disk_type)?each.value.disk_throughput:null
  disk_encryption_set_id = var.encrypt_disk?(var.disk_encryption_set_name==null?azurerm_disk_encryption_set.default.0.id:data.azurerm_disk_encryption_set.default.0.id):null
}

resource "azurerm_virtual_machine_data_disk_attachment" "default" {
  for_each           = local.disks
  managed_disk_id    = azurerm_managed_disk.default[each.key].id
  virtual_machine_id = !local.is_windows[each.value.instance] ? azurerm_linux_virtual_machine.default[each.value.instance].id : azurerm_windows_virtual_machine.default[each.value.instance].id
  lun                = each.value.lun
  caching            = contains(local.speed_adjustable_disk_types, each.value.disk_type)?"None":"ReadWrite"
}

data "template_cloudinit_config" "default" {
  for_each = {
    for k,v in local.vms: k=>v if !local.is_windows[k]
  }
  
  gzip = true
  base64_encode = true
  part {
    filename = "init-shellscript"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/cloud-init.sh", {
      disk_count  = each.value.data_disk_spec!=null?each.value.data_disk_spec.disk_count:0
      disk_format = each.value.data_disk_spec!=null?each.value.data_disk_spec.disk_format:"ext4"
      device_root = each.value.data_disk_spec!=null?each.value.data_disk_spec.disk_type!="local"?"/dev/disk/azure/scsi1":"":""
      disk_user   = local.os_image_user[each.value.os_type]
      disk_group  = local.os_image_user[each.value.os_type]
    })
  }

  part {
    filename = "init-cloud"
    content_type = "text/cloud-config"
    content = "${file("${path.module}/templates/cloud_init_resourcedisk.cfg")}"
  }
}

