#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  operating_systems = {
    "ubuntu2004" = "Canonical Ubuntu"
    "ubuntu2204" = "Canonical Ubuntu"
    "ubuntu2404" = "Canonical Ubuntu"
  }
  operating_system_versions = {
    "ubuntu2004" = "20.04"
    "ubuntu2204" = "22.04"
    "ubuntu2404" = "24.04"
  }
  os_image_user = {
    "ubuntu2004": "ubuntu",
    "ubuntu2204": "ubuntu",
    "ubuntu2404": "ubuntu",
  }
}

data "oci_core_images" "search" {
  for_each = {
    for k,v in local.profile_map : k => v
      if v.vm_count > 0 && length(regexall("^ocid",v.os_image!=null?v.os_image:""))==0
  }

  compartment_id = var.compartment
  operating_system = each.value.os_image==null?local.operating_systems[each.value.os_type]:null
  operating_system_version = each.value.os_image==null?local.operating_system_versions[each.value.os_type]:null
  shape = each.value.os_image==null?each.value.instance_type:null
  sort_by = "TIMECREATED"
  sort_order = "DESC"
  display_name = each.value.os_image==null?null:each.value.os_image
}

