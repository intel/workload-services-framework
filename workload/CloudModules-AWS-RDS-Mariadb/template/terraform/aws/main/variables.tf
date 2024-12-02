#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

variable "common_tags" {
  type = map
  nullable = false
}

variable "profile" {
  type = string
  default = null
}

variable "region" {
  type = string
  default = null
}

variable "zone" {
  type = string
  nullable = false
}

variable "ssh_pub_key" {}

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

variable "private2_cidr" {
  type = string
  default = "10.0.3.0/24"
}

variable "sg_whitelist_cidr_blocks" {
  type     = list(string)
  nullable = false
}

variable "job_id" {
  type     = string
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
    }))
  }))
}

variable "spot_instance" {
  type = bool
  default = true
}

variable "spot_price" {
  type = number
  default = 0
}

variable "identifier" {
  type = string
  default = "wsf"
}

variable "engine" {
  type = string
  default = "mysql"
}

variable "engine_version" {
  type = string
  default = "8.0.26"
}

variable "family" {
  type = string
  default = "mysql8.0"
}

variable "major_engine_version" {
  type = string
  default = "8.0"
}

variable "enabled_cloudwatch_logs_exports" {
  type = string
  default = "general"
}

variable "create_cloudwatch_log_group" {
  type = bool
  default = true
}


variable "skip_final_snapshot" {
  type = bool
  default = true
}

variable "deletion_protection" {
  type = bool
  default = false
}

variable "performance_insights_enabled" {
  type = bool
  default = true
}

variable "performance_insights_retention_period" {
  type = number
  default = 7
}

variable "allocated_storage" {
  type = number
  default = 500
}

variable "storage_type" {
  type = string
  default = "io1"
}

variable "db_name" {
  type = string
  default = "mydb"
}

variable "username" {
  type = string
  default = "root"
}
 
variable "password" {
  type = string
  default = "Mysql123"
}

variable "port" {
  type = number
  default = 3306
}

variable "iops" {
  type = number
  default = 25000
}

variable "instance_class" {
  type = string
  default = "db.t3.micro"
}



