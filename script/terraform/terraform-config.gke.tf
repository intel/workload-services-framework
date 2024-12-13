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
    disk_type = "pd-standard"
    disk_iops = null
  }
}

variable "disk_spec_2" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_type = "pd-standard"
    disk_iops = null
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
  default = "us-west1-a"
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

variable "wl_registry_map" {
  default = ""
}

variable "wl_namespace" {
  default = ""
}

variable "worker_profile" {
  default = {
    name = "worker"
    instance_type = "e2-small"
    vm_count = 1
    min_cpu_platform = null
    nic_type = "GVNIC"

    os_type = "ubuntu"
    os_disk_type = "pd-standard"
    os_disk_size = 200

    data_disk_spec = null
    network_spec = null
  }
}

variable "client_profile" {
  default = {
    name = "client"
    instance_type = "e2-small"
    vm_count = 1
    min_cpu_platform = null
    nic_type = "GVNIC"

    os_type = "ubuntu"
    os_disk_type = "pd-standard"
    os_disk_size = 200

    data_disk_spec = null
    network_spec = null
  }
}

module "wsf" {
  source = "./template/terraform/gcp/gke"

  region = var.region
  zone = var.zone
  job_id = var.wl_namespace

  sg_whitelist_cidr_blocks = compact(split("\n",file("proxy-ip-list.txt")))
  ssh_pub_key = file("ssh_access.key.pub")
  ssh_private_key_file = "ssh_access.key"

  common_tags = {
    for k,v in merge(var.custom_tags, {
      owner: var.owner,
      workload: var.wl_name,
    }) : lower(k) => substr(replace(lower(v), "/[^a-z0-9_-]/", ""), 0, 63)
  }

  instance_profiles = [
    merge(var.worker_profile, {
      data_disk_spec: null,
      network_spec: null,
    }),
    merge(var.client_profile, {
      data_disk_spec: null,
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
    for k,v in module.wsf.instances: k => merge(v, {
      csp = "gcp",
      zone = var.zone,
    })
  }
}

