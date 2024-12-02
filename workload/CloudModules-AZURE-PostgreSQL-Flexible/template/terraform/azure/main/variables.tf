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

variable "subscription_id" {
  type = string
  default = null
}

variable "ssh_pub_key" {
  type = string
  nullable = false
}

variable "vpc_cidr_block" {
  type = string
  default = "10.0.0.0/16"
}

variable "public_cidr" {
  type = string
  default = "10.0.1.0/24"
}

variable "private1_cidr" {
  type = string
  default = "10.0.2.0/24"
}

variable "sg_whitelist_cidr_blocks" {
  type = list(string)
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

    os_type = string
    os_disk_type = string
    os_disk_size = number
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
    }))
  }))
  nullable    = false
}

variable "common_tags" {
  description = "Resource tags"
  type        = map(string)
  nullable    = false
}

variable "spot_instance" {
  type = bool
  default = true
}

variable "spot_price" {
  type = number
  default = -1
}

variable "admin_username" {
  description = "The administrator login name for the new SQL Server"
  default     = null
}

variable "port" {
  description = "The administrator login port for the new SQL Server"
  default     = 5432
}

variable "admin_password" {
  description = "The password associated with the admin_username user"
  default     = null
}

variable "database_name" {
  description = "The name of the database"
  default     = ""
}
