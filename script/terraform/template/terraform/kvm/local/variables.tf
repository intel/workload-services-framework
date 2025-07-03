#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

variable "ssh_pub_key" {
  type = string
  nullable = false
}

variable "job_id" {
  type = string
  nullable = false
}

variable "instance_profiles" {
  type = list(object({
    name = string

    vm_count = number
    cpu_core_count = number
    memory_size = number
    cpu_set = string
    node_set = string

    os_image = string
    os_type = string
    os_disk_size = number

    data_disk_spec = list(object({
      disk_count = number
      disk_size = number
      disk_format = string
      disk_pool = string
    }))

    network_spec = list(object({
      network_count = number
    }))

    kvm_hosts = list(number)
  }))
  nullable = false
}

variable "kvm_index" {
  type = number
  nullable = false
}

variable "kvm_host" {
  type = object({
    user     = string
    host     = string
    port     = number
    networks = list(string)
    pool     = string
  })
  nullable = false
}

variable "winrm_port" {
  type = number
  default = 5986
}

variable "winrm_lport" {
  type = number
  default = 25986
}

variable "winrm_timeout" {
  type = number
  default = 60
}

variable "mac_prefix" {
  type = list(number)
  default = [170, 0, 4]
}

