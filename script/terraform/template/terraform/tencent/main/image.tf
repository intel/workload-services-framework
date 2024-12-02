#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  os_name_regex = {
    "ubuntu2004": "(Ubuntu Server 20.04 LTS 64|Ubuntu 20.04[(]arm64[)])",
    "ubuntu2204": "(Ubuntu Server 22.04 LTS 64|Ubuntu 22.04[(]arm64[)])",
    "ubuntu2404": "(Ubuntu Server 24.04 LTS 64|Ubuntu 24.04[(]arm64[)])",
    "tencentos31": "(TencentOS Server 3.1 [(]TK4[)])",
  }
  os_user_name = {
    "ubuntu2004": "ubuntu",
    "ubuntu2204": "ubuntu",
    "ubuntu2404": "ubuntu",
    "tencentos31": "root",
  }
  os_name_platform_suffix  = {
    "S7": " SPR"
  }
}

data "tencentcloud_images" "search" {
  for_each = local.profile_map
  image_id = each.value.os_image == null ? null : startswith(each.value.os_image, "img-") ? each.value.os_image : null
  instance_type = each.value.instance_type
  image_name_regex = each.value.os_image == null ? format("%s%s", local.os_name_regex[each.value.os_type], lookup(local.os_name_platform_suffix, replace(each.value.instance_type,"/[.].*/", ""), "")) : startswith(each.value.os_image, "img-") ? null : each.value.os_image
}

