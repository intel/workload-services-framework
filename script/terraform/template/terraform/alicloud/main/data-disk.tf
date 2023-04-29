
locals {
  disks_flat = flatten([
    for k,v in local.instances : [
      for i in range(v.data_disk_spec!=null?(v.data_disk_spec.disk_type!="local"?v.data_disk_spec.disk_count:0):0) : {
        name = "vm-${k}-disk-${i}"
        instance = k
        disk_size = v.data_disk_spec.disk_size
        disk_type = v.data_disk_spec.disk_type
        disk_performance = v.data_disk_spec.disk_performance
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
      disk_performance = dsk.disk_performance
      lun       = dsk.lun
    }
  }
}

resource "alicloud_ecs_disk" "default" {
  for_each = local.disks

  disk_name = "wsf-${var.job_id}-${each.key}-storage"
  zone_id = var.zone
  category = each.value.disk_type
  delete_auto_snapshot = true
  delete_with_instance = false
  performance_level = each.value.disk_performance
  resource_group_id = var.resource_group_id
  size = each.value.disk_size
  
  tags = var.common_tags
}

resource "alicloud_ecs_disk_attachment" "default" {
  for_each    = local.disks
  instance_id = alicloud_instance.default[each.value.instance].id
  disk_id     = alicloud_ecs_disk.default[each.key].id
}

data "template_cloudinit_config" "default" {
  for_each = local.instances
  gzip = false
  base64_encode = true
  part {
    filename = "init-shellscript"
    content_type = "text/x-shellscript"
    content = templatefile("./template/terraform/alicloud/main/cloud-init.sh", {
      disks = [ for k,v in local.disks: {
        serial = each.value.data_disk_spec!=null?(each.value.data_disk_spec.disk_type!="local"?replace(alicloud_ecs_disk.default[k].id, "d-", ""):""):""
        mount_path = "/mnt/disk${v.lun+1}"
      } if v.instance == each.key ]
      disk_format = each.value.data_disk_spec!=null?each.value.data_disk_spec.disk_format:"ext4"
      user_name  = local.os_user_name[each.value.os_type]
      public_key = var.ssh_pub_key
    })
  }
}
