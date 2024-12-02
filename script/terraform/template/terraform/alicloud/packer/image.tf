#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  os_name_regex = {
    "x64": {
      "ubuntu2004": "ubuntu_20_04_x64*alibase*.vhd",
      "ubuntu2204": "ubuntu_22_04_x64*alibase*.vhd",
      "ubuntu2404": "ubuntu_24_04_x64*alibase*.vhd",
      "debian11": "debian_11_*_x64*alibase*.vhd",
      "debian12": "debian_12_*_x64*alibase*.vhd",
      "anolis86anck":   "anolisos_8_6_x64*anck_alibase*",
      "anolis84anck":   "anolisos_8_4_x64*anck_alibase*",
      "anolis86rhck":   "anolisos_8_6_x64*rhck_alibase*",
      "anolis84rhck":   "anolisos_8_4_x64*rhck_alibase*",
      "redhat86": "8.6",
    },
    "arm64": {
      "ubuntu2004": "ubuntu_20_04_arm64*alibase*.vhd",
      "ubuntu2204": "ubuntu_22_04_arm64*alibase*.vhd",
      "ubuntu2404": "ubuntu_24_04_arm64*alibase*.vhd",
      "debian11": "debian_11_*_arm64*alibase*.vhd",
      "debian12": "debian_12_*_arm64*alibase*.vhd",
      "anolis86anck": "anolisos_8_6_arm64*anck_alibase*",
      "anolis84anck": "anolisos_8_4_arm64*anck_alibase*",
      "anolis86rhck": "anolisos_8_6_arm64*rhck_alibase*",
      "anolis84rhck": "anolisos_8_4_arm64*rhck_alibase*",
    }
  }
  os_user_name = {
    "ubuntu2004": "tfu",
    "ubuntu2204": "tfu",
    "ubuntu2404": "tfu",
    "debian11": "tfu",
    "debian12": "tfu",
    "anolis84anck": "tfu",
    "anolis86anck": "tfu",
    "anolis84rhck": "tfu",
    "anolis86rhck": "tfu",
    "redhat86": "tfu",
  }
  instance_type_arm64_suffixes = [ "m", "r", "y" ]
}

data "alicloud_market_products" "products" {
  for_each = toset(var.os_type=="redhat86"?[var.os_type]:[])
  name_regex = "Red Hat Enterprise Linux ${replace(var.os_type, "/[a-z]*([0-9])([0-9])$/", "$1.$2")}"
  product_type = "MIRROR"
}

data "alicloud_market_product" "default" {
  for_each = toset(var.os_type=="redhat86"?[var.os_type]:[])
  product_code = data.alicloud_market_products.products[var.os_type].products.0.code
  available_region = local.region
}

data "alicloud_instance_types" "types" {
  for_each = toset(var.os_type=="redhat86"?[var.os_type]:[])
  image_id = var.os_image!=null?var.os_image:data.alicloud_market_product.default[var.os_type].product.0.skus.0.images.0.image_id
  instance_type_family = regex("[a-zA-Z0-9]+\\.[a-zA-Z0-9]+", var.instance_type)
  cpu_core_count = try(tonumber(regex("([0-9]+)xlarge$", var.instance_type)[0]), 1) * 4
}

data "alicloud_images" "search" {
  for_each = toset(var.os_type!="redhat86"?[var.os_type]:[])
  image_id = var.os_image
  image_name = local.os_name_regex[contains(local.instance_type_arm64_suffixes, replace(var.instance_type,"/[a-z]*[.][a-z]*[0-9]*([a-z0-9-]*)[.][0-9]*[a-z]*/","$1"))?"arm64":"x64"][var.os_type]
  is_support_io_optimized = true
  is_support_cloud_init = true
  os_type = "linux"
  owners = "system"
  most_recent = true
}

locals {
  images = merge({
    for k,v in data.alicloud_images.search: k => v.images.0.id
  }, {
    for k,v in data.alicloud_instance_types.types: k => v.image_id
  })
}

data "alicloud_images" "check_image" {
  owners = "self"
  name_regex = replace(lower(var.image_name), "_", "-")
  resource_group_id = var.resource_group_id

  lifecycle {
    postcondition {
      condition = length(self.images) == 0
      error_message = "${var.image_name} already exists"
    }
  }
}


