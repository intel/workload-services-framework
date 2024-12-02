#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
variable "common_tags" {
  type    = map(string)
  default = {}
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

variable "vpc_cidr_block" {
  type = string
  default = "10.0.0.0/16"
}

variable "proxy_ip_list" {
  type     = string
  nullable = false
}

variable "job_id" {
  type = string
  nullable = false
}

variable "compartment" {
  type = string
  nullable = false
}

variable "image_name" {
  type = string
  nullable = false
}
