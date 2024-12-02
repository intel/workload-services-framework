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
  }
}

data "tencentcloud_images" "search" {
  instance_type = var.instance_type
  image_name_regex = local.os_name_regex[var.os_type]
}

data "tencentcloud_images" "check_image" {
  image_name_regex = replace(lower(var.image_name),"_","-")
  image_type = ["PRIVATE_IMAGE"]

  lifecycle {
    postcondition {
      condition = length(self.images) == 0
      error_message = "${var.image_name} already exists."
    }
  }
}

