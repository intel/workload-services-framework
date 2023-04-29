
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
      "redhat86": "8.6",
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
  os_user_name = {
    "ubuntu2004": "tfu",
    "ubuntu2204": "tfu",
    "debian11": "tfu",
    "anolis84anck": "tfu",
    "anolis86anck": "tfu",
    "anolis84rhck": "tfu",
    "anolis86rhck": "tfu",
    "redhat86": "tfu",
  }
  instance_type_arm64_suffixes = [ "m", "r", "y" ]
}

locals {
  profile_map = {
    for profile in var.instance_profiles: 
        profile.name => profile 
  }
}

data "alicloud_market_products" "products" {
  for_each = {
    for instance_name, instance_config in local.profile_map :
    instance_name => instance_config if (instance_config.os_type == "redhat86" && instance_config.vm_count > 0)
  }
  name_regex            = "Red Hat Enterprise Linux ${replace(each.value.os_type, "/[a-z]*([0-9])([0-9])$/", "$1.$2")}"
  product_type          = "MIRROR"
}

data "alicloud_regions" "current_region_ds" {
  current = true
}

data "alicloud_market_product" "default" {
  for_each = {
    for instance_name, instance_config in local.profile_map :
    instance_name => instance_config if (instance_config.os_type == "redhat86" && instance_config.vm_count > 0)
  }
  product_code     = data.alicloud_market_products.products[each.value.name].products.0.code
  available_region = data.alicloud_regions.current_region_ds.ids.0
}

data "alicloud_images" "search" {
  for_each = {
    for instance_name, instance_config in local.profile_map :
    instance_name => instance_config if (instance_config.os_type != "redhat86" && instance_config.vm_count > 0)
  }

  image_id = each.value.image
  image_name = local.os_name_regex[contains(local.instance_type_arm64_suffixes, replace(each.value.instance_type,"/[a-z]*[.][a-z]*[0-9]*([a-z0-9-]*)[.][0-9]*[a-z]*/","$1"))?"arm64":"x64"][each.value.os_type]
  is_support_io_optimized = true
  is_support_cloud_init = true
  os_type = "linux"
  owners = "system"
  output_file = "images-${each.key}"
  most_recent = true
}

locals {
  images = merge({
    for k,v in data.alicloud_images.search: k => v.images.0.id
  }, {
    for k,v in data.alicloud_market_product.default: k => v.product.0.skus.0.images.0.image_id
  })
}

