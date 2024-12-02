#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
variable "region" {
  type = string
  default = null
}

variable "zone" {
  type = string
  nullable = false
}

variable "vpc_cidr_block" {
  type = string
  default = "10.0.0.0/16"
}

variable "ssh_pub_key" {
  type = string
  nullable = false
}

variable "ssh_private_key_file" {
  type = string
  nullable = false
}

variable "sg_whitelist_cidr_blocks" {
  type = list(string)
  nullable = false
}

variable "common_tags" {
  description = "Resource tags"
  type        = map(string)
  nullable    = false
}

variable "job_id" {
  type = string
  nullable = false
}

variable "instance_profiles" {
  type = list(object({
    name = string

    vm_count = number
    instance_type = string
    min_cpu_platform = string
    nic_type = string

    os_type = string
    os_disk_type = string
    os_disk_size = string

    data_disk_spec = list(object({
      disk_count = number
      disk_type = string
      disk_size = number
      disk_format = string
      disk_iops = number
    }))

    network_spec = list(object({
      network_count = number
    }))
  }))
  nullable = false
}

variable "project_id" {
  type = string
  default = null
}

variable "spot_instance" {
  type = bool
  default = false
}

variable "instance_storage_interface" {
  type = string
  default = "NVME"
}

variable "kubelet_config" {
  type = object({
    cpu_manager_policy = string
  })
  default = null
}

variable "enable_kubernetes_alpha" {
  type = bool
  default = false
}

variable "pod_network_cidr" {
  type = string
  default = "10.244.0.0/16"
}

