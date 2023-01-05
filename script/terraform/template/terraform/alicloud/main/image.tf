
locals {
  os_name_regex = {
    "x64": {
      "ubuntu2004": "ubuntu_20_04_x64*alibase*.vhd",
      "ubuntu2204": "ubuntu_22_04_x64*alibase*.vhd",
      "debian11": "debian_11_2_x64*alibase*.vhd",
    },
    "arm64": {
      "ubuntu2004": "ubuntu_20_04_arm64*alibase*.vhd",
      "ubuntu2204": "ubuntu_22_04_arm64*alibase*.vhd",
      "debian11": "debian_11_2_arm64*alibase*.vhd",
    }
  }
  os_user_name = {
    "ubuntu2004": "tfu",
    "ubuntu2204": "tfu",
    "debian11": "tfu",
  }
  instance_type_arm64_suffixes = [ "m", "r", "y" ]
}

locals {
  profile_map = {
    for profile in var.instance_profiles: 
        profile.name => profile 
  }
}

data "alicloud_images" "search" {
  for_each = local.profile_map

  image_id = each.value.image
  image_name = local.os_name_regex[contains(local.instance_type_arm64_suffixes, replace(each.value.instance_type,"/[a-z]*[.][a-z]*[0-9]*([a-z0-9-]*)[.][0-9]*[a-z]*/","$1"))?"arm64":"x64"][each.value.os_type]
  is_support_io_optimized = true
  is_support_cloud_init = true
  os_type = "linux"
  owners = "system"
  output_file = "images-${each.key}"
  most_recent = true
}


