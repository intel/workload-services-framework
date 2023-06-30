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
      "debian11": "debian_11_2_x64*alibase*.vhd",
      "anolis86anck":   "anolisos_8_6_x64*anck_alibase*",
      "anolis84anck":   "anolisos_8_4_x64*anck_alibase*",
      "anolis86rhck":   "anolisos_8_6_x64*rhck_alibase*",
      "anolis84rhck":   "anolisos_8_4_x64*rhck_alibase*",
      "redhat86":       "Red Hat Enterprise Linux 8.6",
      "aliyun3":        "aliyun_3_x64*_alibase*",
    },
    "arm64": {
      "ubuntu2004": "ubuntu_20_04_arm64*alibase*.vhd",
      "ubuntu2204": "ubuntu_22_04_arm64*alibase*.vhd",
      "debian11": "debian_11_2_arm64*alibase*.vhd",
      "anolis86anck": "anolisos_8_6_arm64*anck_alibase*",
      "anolis84anck": "anolisos_8_4_arm64*anck_alibase*",
      "anolis86rhck": "anolisos_8_6_arm64*rhck_alibase*",
      "anolis84rhck": "anolisos_8_4_arm64*rhck_alibase*",
    }
  }
  marketplace_images = {
    "redhat86": true
  }
  os_user_name = {
    "ubuntu2004": "tfu",
    "ubuntu2204": "tfu",
    "debian11": "tfu",
    "anolis84anck": "tfu",
    "anolis86anck": "tfu",
    "anolis84rhck": "tfu",
    "anolis86rhck": "tfu",
    "redhat86": "tfu",
    "aliyun3": "tfu",
  }
  instance_type_arm64_suffixes = [ "m", "r", "y" ]
}

data "alicloud_market_products" "products" {
  for_each = {
    for p in var.instance_profiles : p.name => p
      if (p.vm_count > 0) && lookup(local.marketplace_images, p.os_type, false)
  }
  name_regex = local.os_name_regex[contains(local.instance_type_arm64_suffixes, replace(each.value.instance_type,"/[a-z]*[.][a-z]*[0-9]*([a-z0-9-]*)[.][0-9]*[a-z]*/","$1"))?"arm64":"x64"][each.value.os_type]
  product_type          = "MIRROR"
}

data "alicloud_market_product" "default" {
  for_each = {
    for k,v in data.alicloud_market_products.products : k => v.products
      if length(v.products)>0
  }
  product_code = each.value.0.code
  available_region = local.region
}

locals {
  profile_ziplist = setproduct([
    for p in var.instance_profiles: p 
      if p.vm_count > 0 && !lookup(local.marketplace_images, p.os_type, false)
  ], ["self", "system"])
}

data "alicloud_images" "search" {
  count = length(local.profile_ziplist)

  image_name = local.profile_ziplist[count.index].0.os_image!=null?local.profile_ziplist[count.index].0.os_image:local.os_name_regex[contains(local.instance_type_arm64_suffixes, replace(local.profile_ziplist[count.index].0.instance_type,"/[a-z]*[.][a-z]*[0-9]*([a-z0-9-]*)[.][0-9]*[a-z]*/","$1"))?"arm64":"x64"][local.profile_ziplist[count.index].0.os_type]
  is_support_io_optimized = true
  is_support_cloud_init = true
  os_type = "linux"
  owners = local.profile_ziplist[count.index].1
  most_recent = true
}

locals {
  images = merge({
    for k,v in data.alicloud_market_product.default: 
      k => v.product.0.skus.0.images.0.image_id
  }, {
    for k,v in data.alicloud_images.search: 
      local.profile_ziplist[k].0.name => v.images.0.id
        if length(v.images)>0 && local.profile_ziplist[k].1=="system"
  }, {
    for k,v in data.alicloud_images.search: 
      local.profile_ziplist[k].0.name => v.images.0.id
        if length(v.images)>0 && local.profile_ziplist[k].1=="self"
  })
}

