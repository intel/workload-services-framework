#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "libvirt_volume" "os_image" {
  for_each = toset(var.kvm_host.pool==null?[ for k,v in local.instances : v.os_type if v.os_image==null ]:[])

  name = replace(local.os[each.key].image_url,"/.*//","")
  pool = libvirt_pool.default.0.name
  source = local.os[each.key].image_url
  format = "qcow2"
}

resource "libvirt_volume" "os_disk" {
  for_each = local.instances

  name = "wsf-${var.job_id}-os-disk-${each.key}"
  pool = libvirt_pool.default.0.name
  size = each.value.os_disk_size*1024*1024*1024
  base_volume_name = var.kvm_host.pool==null?libvirt_volume.os_image[each.value.os_type].name:(each.value.os_image!=null?each.value.os_image:replace(local.os[each.value.os_type].image_url,"/.*//",""))
  base_volume_pool = var.kvm_host.pool!=null?var.kvm_host.pool:libvirt_pool.default.0.name
}

