#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "oci_core_instance" "default" {
  for_each = local.instances

  display_name = "wsf-${var.job_id}-${each.key}"
  availability_domain = var.zone
  compartment_id = var.compartment

  create_vnic_details {
    assign_private_dns_record = true
    assign_public_ip = true
    display_name = "wsf-${var.job_id}-${each.key}-1nic"
    hostname_label = each.key
    subnet_id = oci_core_subnet.default.id

    freeform_tags = merge(var.common_tags, {
      Name = "wsf-${var.job_id}-${each.key}-1nic"
    })
  }

  metadata = {
    ssh_authorized_keys = var.ssh_pub_key
    user_data = data.template_cloudinit_config.default[each.key].rendered
  }

  shape = each.value.instance_type

  dynamic "shape_config" {
    for_each = replace(each.value.instance_type,".Flex","")!=each.value.instance_type?[1]:[]
    content {
      memory_in_gbs=each.value.memory_size
      ocpus = each.value.cpu_core_count
    }
  }
  
  source_details {
    boot_volume_size_in_gbs = each.value.os_disk_size
    boot_volume_vpus_per_gb = each.value.os_disk_performance!=null?parseint(each.value.os_disk_performance,10):null
    source_type = "image"
    source_id = length(regexall("^ocid",each.value.os_image!=null?each.value.os_image:""))>0?each.value.os_image:data.oci_core_images.search[each.value.profile].images.0.id
  }

  freeform_tags = merge(var.common_tags, {
    Name = "wsf-${var.job_id}-${each.key}"
  })
}
