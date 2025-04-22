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

variable "config_file" {
  type = string
  default = "/home/.aliyun/config.json"
}

variable "profile" {
  type = string
  default = "default"
}

variable "region" {
  type = string
  default = null
}

variable "zone" {
  type = string
  nullable = false
}

variable "ssh_pub_key" {
  type = string
  nullable = false
}

variable "ssh_pri_key_file" {
  type = string
  default = "ssh_access.key"
}

variable "sg_whitelist_cidr_blocks" {
  type     = list(string)
  nullable = false
}

variable "vpc_cidr_block" {
  type = string
  default = "10.2.0.0/16"
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
    cpu_model_regex = string
    accelerators = string

    os_type = string
    os_disk_type = string
    os_disk_size = number
    os_disk_performance = string
    os_image = string

    data_disk_spec = list(object({
      disk_count = number
      disk_type = string
      disk_size = number
      disk_format = string
      disk_performance = string
    }))
  }))
  nullable = false
}

variable "internet_bandwidth" {
  type = number
  default = 100
}

variable "spot_instance" {
  type = bool
  default = false
}

variable "spot_price" {
  type = number
  default = 0
}

variable "resource_group_id" {
  type = string
  default = null
}

variable "cpu_model_timeout" {
  type = string
  default = "10m"
}

variable "credit_specification" {
  type = string
  default = "Unlimited"
}

