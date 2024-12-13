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
    disk_type = "gp2"
    disk_iops = null
    disk_throughput = null
  }
}

variable "disk_spec_2" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_type = "gp2"
    disk_iops = null
    disk_throughput = null
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
  default = "us-west-2a"
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

variable "wl_namespace" {
  default = ""
}

variable "wl_registry_map" {
  default = ""
}

variable "worker_profile" {
  default = {
    name = "worker"
    instance_type = "t2.medium"
    threads_per_core = null
    cpu_core_count = null
    vm_count = 1

    os_image = null
    os_type = "ubuntu2004"
    os_disk_type = "gp2"
    os_disk_size = 200
    os_disk_iops = null
    os_disk_throughput = null

    data_disk_spec = null
    network_spec = null
  }
}

variable "client_profile" {
  default = {
    name = "client"
    instance_type = "t2.medium"
    threads_per_core = null
    cpu_core_count = null
    vm_count = 1

    os_image = null
    os_type = "ubuntu2004"
    os_disk_type = "gp2"
    os_disk_size = 200
    os_disk_iops = null
    os_disk_throughput = null

    data_disk_spec = null
    network_spec = null
  }
}

module "wsf" {
  source = "./template/terraform/aws/eks"

  region = var.region
  zones = [
    var.zone,
    format("%s%s", replace(var.zone, "/(.*)[a-z]$/", "$1"), replace(var.zone, "/.*([a-z])$/", "$1")=="a"?"b":"a"),
  ]
  job_id = var.wl_namespace

  sg_whitelist_cidr_blocks = compact(split("\n",file("proxy-ip-list.txt")))
  ssh_pub_key = file("ssh_access.key.pub")

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
  ]

  spot_instance = var.spot_instance
}

output "options" {
  value = merge({
    wl_name : var.wl_name,
    wl_registry_map : var.wl_registry_map,
    wl_namespace : var.wl_namespace,
    k8s_enable_registry: false,
    k8s_remote_registry_url: "",
  }, module.wsf.options)
}

output "instances" {
  value = {
    for k,v in module.wsf.instances : k => merge(v, {
      csp = "aws",
      zone = var.zone,
    })
  }
}

