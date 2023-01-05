
variable "disk_spec_1" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_type = "Standard_LRS"
    disk_iops = 32000
    disk_throughput = 1024
  }
}

variable "disk_spec_2" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_type = "Standard_LRS"
    disk_iops = 32000
    disk_throughput = 1024
  }
}

variable "network_spec_1" {
  default = {
    network_count = 1
  }
}

variable "region" {
  default = null
}

variable "zone" {
  default = "eastus-1"
}

variable "owner" {
  default = ""
}

variable "spot_instance" {
  default = true
}

variable "custom_tags" {
  default = {}
}

variable "wl_name" {
  default = ""
}

variable "wl_category" {
   default = ""
}

variable "wl_docker_image" {
  default = ""
}

variable "wl_docker_options" {
  default = ""
}

variable "wl_job_filter" {
  default = ""
}

variable "wl_timeout" {
  default = "28800,300"
}

variable "wl_registry_map" {
  default = ""
}

variable "wl_namespace" {
  default = ""
}

variable "wl_trace_mode" {
  default = ""
}

variable "worker_profile" {
  default = {
    name = "worker"
    vm_count = 1
    instance_type = "Standard_A2_v2"

    image = null
    os_type = "ubuntu2204"
    os_disk_type = "Standard_LRS"
    os_disk_size = 200

    data_disk_spec = null
    network_spec = null
  }
}

variable "client_profile" {
  default = {
    name = "client"
    vm_count = 1
    instance_type = "Standard_A2_v2"

    image = null
    os_type = "ubuntu2204"
    os_disk_type = "Standard_LRS"
    os_disk_size = 200

    data_disk_spec = null
    network_spec = null
  }
}

variable "controller_profile" {
  default = {
    name = "controller"
    vm_count = 1
    instance_type = "Standard_A2_v2"

    image = null
    os_type = "ubuntu2204"
    os_disk_type = "Standard_LRS"
    os_disk_size = 200

    data_disk_spec = null
    network_spec = null
  }
}

module "wsf" {
  source = "./template/terraform/azure/main"

  region = var.region
  zone   = var.zone
  job_id = var.wl_namespace

  sg_whitelist_cidr_blocks = compact(split("\n",file("proxy-ip-list.txt")))
  ssh_pub_key = file("ssh_access.key.pub")

  common_tags = merge(var.custom_tags, {
    owner: var.owner,
    workload: var.wl_name,
  })

  instance_profiles = [
    merge(var.worker_profile, {
      data_disk_spec: null,
      network_spec: null,
    }),
    merge(var.client_profile, {
      data_disk_spec: null,
      network_spec: null,
    }),
    merge(var.controller_profile, {
      data_disk_spec: null,
      network_spec: null,
    }),
  ]

  spot_instance = var.spot_instance
}

output "options" {
  value = {
    wl_name : var.wl_name,
    wl_category : var.wl_category,
    wl_docker_image : var.wl_docker_image,
    wl_docker_options : var.wl_docker_options,
    wl_job_filter : var.wl_job_filter,
    wl_timeout : var.wl_timeout,
    wl_registry_map : var.wl_registry_map,
    wl_namespace : var.wl_namespace,
    wl_trace_mode : var.wl_trace_mode,
  }
}

output "instances" {
  value = {
    for k,v in module.wsf.instances: k => merge(v, {
      csp = "azure",
      zone = var.zone,
    })
  }
}

