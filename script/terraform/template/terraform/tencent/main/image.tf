#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  os_name_regex = {
    "ubuntu2004": "(Ubuntu Server 20.04 LTS 64|Ubuntu 20.04[(]arm64[)])",
    "ubuntu2204": "(Ubuntu Server 22.04 LTS 64|Ubuntu 22.04[(]arm64[)])",
  }
  os_user_name = {
    "ubuntu2004": "ubuntu",
    "ubuntu2204": "ubuntu",
  }
}

data "tencentcloud_images" "search" {
  for_each = local.profile_map
  image_id = each.value.os_image
  instance_type = each.value.instance_type
  image_name_regex = local.os_name_regex[each.value.os_type]
}

