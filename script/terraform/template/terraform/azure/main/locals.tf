locals {
  vms_flat = flatten([
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
        network_spec = profile.network_spec!=null?profile.network_spec[i]:null
      }
    ]
  ])
}

locals {
  vms = {
    for vm in local.vms_flat : "${vm.profile}-${vm.index}" => {
      instance_type = vm.instance_type
      image = vm.image
      os_type = vm.os_type
      os_disk_type = vm.os_disk_type
      os_disk_size = vm.os_disk_size
      data_disk_spec = vm.data_disk_spec
      network_spec = vm.network_spec
    }
  }
}

locals {
  subnet_cidr_block = cidrsubnet(var.vpc_cidr_block, 8, 1)
}

locals {
  availability_zone = length(regexall("-[0-9]$",var.zone))>0?parseint(replace(var.zone,"/.*-/",""),10):1
}

locals {
  networks_flat = flatten([
    for k,v in local.vms : [
      for i in range(v.network_spec!=null?v.network_spec.network_count:0) : {
        name         = "network-interface-${i+1}"
        instance     = k
        lun          = i+1
      }
    ]
  ])
  networks = {
    for net in local.networks_flat : net.name => {
      instance     = net.instance
      lun          = net.lun
    }
  }
}
