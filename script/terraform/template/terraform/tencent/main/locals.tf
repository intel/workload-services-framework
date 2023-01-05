locals {
  instances_flat = flatten([
    for profile in var.instance_profiles : [
      for i in range(profile.vm_count): {
        index = i
        profile = profile.name
        instance_type = profile.instance_type
        image = profile.image
        os_type = profile.os_type
        os_disk_type = profile.os_disk_type
        os_disk_size = profile.os_disk_size
        data_disk_spec = profile.data_disk_spec!=null?profile.data_disk_spec[i]:null
      }
    ]
  ])
}

locals {
  instances = {
    for vm in local.instances_flat : "${vm.profile}-${vm.index}" => {
      instance_type = vm.instance_type
      image = vm.image
      profile = vm.profile
      os_type = vm.os_type
      os_disk_type = vm.os_disk_type
      os_disk_size = vm.os_disk_size
      data_disk_spec = vm.data_disk_spec
    }
  }
}

locals {
  profile_map = {
    for profile in var.instance_profiles: profile.name => profile
  }
}

