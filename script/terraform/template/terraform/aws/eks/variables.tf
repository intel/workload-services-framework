#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
variable "common_tags" {
  description = "Resource tags"
  type        = map(string)
  nullable    = false
}

variable "profile" {
  type = string
  default = null
}

variable "region" {
  type = string
  default = null
}

variable "zones" {
  type = list(string)
  nullable = false
}

variable "ssh_pub_key" {
  type = string
  nullable = false
}

variable "vpc_cidr_block" {
  type = string
  default = "10.0.0.0/16"
}

variable "sg_whitelist_cidr_blocks" {
  type     = list(string)
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
    instance_type = string
    threads_per_core = number
    cpu_core_count = number

    os_type = string
    os_disk_type = string
    os_disk_size = number
    os_disk_iops = number
    os_disk_throughput = number
    os_image = string

    data_disk_spec = list(object({
      disk_count = number
      disk_type = string
      disk_size = number
      disk_format = string
      disk_iops = number
      disk_throughput = number
    }))

    network_spec = list(object({
      network_count = number
      network_type  = string
    }))
  }))
  nullable = false
}

variable "spot_instance" {
  type = bool
  default = true
}

variable "service_network_cidr" {
  type = string
  default = "10.100.0.0/16"
}

variable "k8s_version" {
  type = string
  default = "1.24"
}

