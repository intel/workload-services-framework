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
    disk_pool = null
  }
}

variable "disk_spec_2" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_pool = null
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
    cpu_core_count = 2
    memory_size = 2
    cpu_set = null
    node_set = null
    vm_count = 1

    os_image = null
    os_type = "ubuntu2204"
    os_disk_size = 50

    data_disk_spec = null
    network_spec = null

    # Specifies which KVM host must be used to host
    # different workers.
    kvm_hosts = [ 0 ]
  }
}

variable "client_profile" {
  default = {
    name = "client"
    cpu_core_count = 2
    memory_size = 2
    cpu_set = null
    node_set = null
    vm_count = 1

    os_image = null
    os_type = "ubuntu2204"
    os_disk_size = 50

    data_disk_spec = null
    network_spec = null

    # Specifies which KVM host must be used to host
    # different clients.
    kvm_hosts = [ 0 ]
  }
}

variable "controller_profile" {
  default = {
    name = "controller"
    cpu_core_count = 2
    memory_size = 2
    cpu_set = null
    node_set = null
    vm_count = 1

    os_image = null
    os_type = "ubuntu2204"
    os_disk_size = 50

    data_disk_spec = null
    network_spec = null

    # Specifies which KVM host must be used to host
    # different controllers.
    kvm_hosts = [ 0 ]
  }
}

# single KVM host
variable "kvm_hosts" {
  default = [{
    user   = "user"
    host   = "127.0.1.1"
    port   = 22
    # DHCP must be enabled on the network interface
    networks = [ "default" ]
    # if specified, os image will reuse the storage pool
    # images (with same image names.)
    pool   = null
  }]
}

terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
    external = {
      source = "hashicorp/external"
    }
  }
}

data "external" "keyfile" {
  count = length(var.kvm_hosts)
  program = [ "bash", "-c",
    "echo '{\"keyfile\":\"'$(ssh -S none -v -p ${var.kvm_hosts[count.index].port} ${var.kvm_hosts[count.index].user}@${var.kvm_hosts[count.index].host} echo 2>&1 | grep 'Server accepts key:' | cut -f5 -d' ')'\"}'"
  ]
}

provider "libvirt" {
  uri = "qemu+ssh://${var.kvm_hosts.0.user}@${var.kvm_hosts.0.host}:${var.kvm_hosts.0.port}/system?keyfile=${data.external.keyfile.0.result.keyfile}"
  alias = "kvm0"
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

module "wsf_kvm0" {
  source = "./template/terraform/kvm/local"

  job_id = var.wl_namespace
  ssh_pub_key = file("${path.root}/ssh_access.key.pub")
  instance_profiles = local.instance_profiles

  kvm_index = 0
  kvm_host  = var.kvm_hosts.0
  providers = {
    libvirt = libvirt.kvm0
  }
}

output "options" {
  value = merge({
    wl_name : var.wl_name,
    wl_registry_map : var.wl_registry_map,
    wl_namespace : var.wl_namespace,
    k8s_enable_registry: true,
  }, {
    for k,v in try(module.wsf_kvm0.options,{}): k => v
  })
}

output "instances" {
  sensitive = true
  value = merge({
  }, {
    for k,v in module.wsf_kvm0.instances : k => merge(v, {
      csp = "kvm",
    })
  })
}

