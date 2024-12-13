#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
variable "disk_spec_1" {
  default = {
    disk_count = 1
    disk_size = 100
    disk_format = "ext4"
  }
}

variable "disk_spec_2" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
  }
}

variable "network_spec_1" {
  default = {
    network_count = 1
    network_type = null
  }
}

variable "owner" {
  default = ""
}

variable "wl_name" {
  default = ""
}

variable "wl_namespace" {
  default = ""
}

variable "wl_registry_map" {
  default = ""
}

variable "worker_profile" {
  default = {
    name = "worker"
    cpu_core_count = 1
    memory_size = 4
    vm_count = 1

    os_image = null
    os_type = "windows2022"
    os_disk_size = 50

    data_disk_spec = null
    network_spec = null
  }
}

variable "client_profile" {
  default = {
    name = "client"
    cpu_core_count = 1
    memory_size = 4
    vm_count = 1

    os_image = null
    os_type = "windows2022"
    os_disk_size = 50

    data_disk_spec = null
    network_spec = null
  }
}

variable "controller_profile" {
  default = {
    name = "controller"
    cpu_core_count = 1
    memory_size = 4
    vm_count = 1

    os_image = null
    os_type = "windows2022"
    os_disk_size = 50

    data_disk_spec = null
    network_spec = null
  }
}

# single HyperV host
variable "hpv_hosts" {
  default = [{
    host   = "<my-hyperv-host>"
    port   = 5986
    networks = [ "wsfext" ]
  }]
}

locals {
  instance_profiles = [
    merge(var.worker_profile, {
      data_disk_spec: null,
      network_spec: null,
    }),
    merge(var.client_profile, {
      data_disk_spec: null
      network_spec: null,
    }),
    merge(var.controller_profile, {
      data_disk_spec: null,
      network_spec: null,
    }),
  ]
}

module "wsf_hyperv" {
  source = "./template/terraform/hyperv/local"

  job_id = var.wl_namespace
  ssh_pub_key = file("${path.root}/ssh_access.key.pub")
  instance_profiles = local.instance_profiles
  hpv_host  = var.hpv_hosts.0
}

output "options" {
  value = merge(module.wsf_hyperv.options, {
    wl_name : var.wl_name,
    wl_registry_map : var.wl_registry_map,
    wl_namespace : var.wl_namespace,
    k8s_enable_registry: true,
  })
}

output "instances" {
  sensitive = true
  value = {
    for k,v in module.wsf_hyperv.instances : k => merge(v, {
      csp = "hyperv",
    })
  }
}

