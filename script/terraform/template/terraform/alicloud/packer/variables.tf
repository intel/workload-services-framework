#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

variable "common_tags" {
  type        = map(string)
  default     = {}
}

variable "config_file" {
  type = string
  default = "/home/.aliyun/config.json"
}

variable "profile" {
  type = string
  default = "default"
}

variable "owner" {
  type = string
  nullable = false
}

variable "region" {
  type = string
  default = null
}

variable "zone" {
  type = string
  nullable = false
}

variable "proxy_ip_list" {
  type     = string
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

variable "resource_group_id" {
  type = string
  default = null
}

variable "instance_type" {
  type = string
  nullable = false
}

variable "os_type" {
  type = string
  nullable = false
}

variable "os_image" {
  type = string
  default = null
}

variable "image_name" {
  type = string
  nullable = false
}

