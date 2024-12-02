#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

variable "ssh_pub_key" {
  type = string
  nullable = false
}

variable "config_file" {
  type = string
  default = "/home/.hyperv/config.json"
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

    os_image = string
    os_type = string
    os_disk_size = number

    data_disk_spec = list(object({
      disk_count = number
      disk_size = number
      disk_format = string
    }))

    network_spec = list(object({
      network_count = number
    }))
  }))
  nullable = false
}

variable "hpv_host" {
  type = object({
    host     = string
    port     = number
    networks = list(string)
  })
  nullable = false
}

variable "winrm_port" {
  type = number
  default = 5986
}

variable "winrm_timeout" {
  type = number
  default = 60
}

variable "ssh_port" {
  type = number
  default = 22
}

variable "proxy_port" {
  type = number
  default = 25000
}

variable "data_disk_path" {
  type = string
  default = "C:\\Users\\Public\\Documents\\Hyper-V\\runs"
}

variable "os_disk_path" {
  type = string
  default = "C:\\Users\\Public\\Documents\\Hyper-V\\osimages"
}

variable "script_path" {
  type = string
  default = "C:\\Users\\Public\\Documents\\Hyper-V\\scripts"
}

variable "instance_path" {
  type = string
  default = "C:\\Users\\Public\\Documents\\Hyper-V\\runs"
}

variable "generation" {
  type = number
  default = 1
}

variable "data_disk_vhd_type" {
  type = string
  default = "Dynamic"
}

variable "data_disk_controller" {
  type = object({
    type = string
    number = number
    location = number
  })
  default = {
    type = "SCSI"
    number = 0
    location = 0
  }
}

variable "wait_for_ips_timeout" {
  type = number
  default = 600
}

variable "secure_boot" {
  type = bool
  default = false
}

