#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
variable "disk_spec_1" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_type = "scsi"
    disk_performance = "0"
  }
}

variable "disk_spec_2" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_type = "scsi"
    disk_performance = "0"
  }
}

variable "network_spec_1" {
  default = {
    network_count = 1
    network_type = null
  }
}

variable "region" {
  default = null
}

variable "zone" {
  default = "Qrha:PHX-AD-1"
}

variable "compartment" {
  default = "ocid1.compartment.oc1..aaaaaaaarx6edbbm7qv6lpivqk6pojsxilp63lqftaid27xkh5kqpd3npcea"
}

variable "owner" {
  default = ""
}

variable "custom_tags" {
  default = {}
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
    instance_type = "VM.Standard3.Flex"
    cpu_model_regex = null
    cpu_core_count = 1
    memory_size = 1
    vm_count = 1

    os_image = null
    os_type = "ubuntu2204"
    os_disk_size = 200
    os_disk_performance = null

    data_disk_spec = null
    network_spec = null
  }
}

variable "client_profile" {
  default = {
    name = "client"
    instance_type = "VM.Standard3.Flex"
    cpu_model_regex = null
    cpu_core_count = 2
    memory_size = 2
    vm_count = 1

    os_image = null
    os_type = "ubuntu2204"
    os_disk_size = 200
    os_disk_performance = null

    data_disk_spec = null
    network_spec = null
  }
}

variable "controller_profile" {
  default = {
    name = "controller"
    instance_type = "VM.Standard3.Flex"
    cpu_model_regex = null
    cpu_core_count = 2
    memory_size = 2
    vm_count = 1

    os_image = null
    os_type = "ubuntu2204"
    os_disk_size = 200
    os_disk_performance = null

    data_disk_spec = null
    network_spec = null
  }
}

module "wsf" {
  source = "./template/terraform/oracle/main"

  region = var.region
  zone = var.zone
  compartment = var.compartment
  job_id = var.wl_namespace

  sg_whitelist_cidr_blocks = compact(split("\n",file("${path.module}/proxy-ip-list.txt")))
  ssh_pub_key = file("${path.module}/ssh_access.key.pub")
  ssh_private_key_file = "${path.module}/ssh_access.key"

  common_tags = {
    for k,v in merge(var.custom_tags, {
      owner: var.owner,
      workload: var.wl_name,
    }) : k => substr(replace(lower(v), "/[^a-z0-9_-]/", ""), 0, 63)
  }

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

output "options" {
  value = {
    wl_name : var.wl_name,
    wl_registry_map : var.wl_registry_map,
    wl_namespace : var.wl_namespace,
  }
}

output "instances" {
  sensitive = true
  value = {
    for k,v in module.wsf.instances : k => merge(v, {
      csp = "oracle",
      zone = var.zone,
    })
  }
}

output "terraform_replace" {
  value = lookup(module.wsf, "terraform_replace", null)==null?null:{
    command = replace(module.wsf.terraform_replace.command, "=", "=module.wsf.")
    cpu_model = module.wsf.terraform_replace.cpu_model
  }
}

