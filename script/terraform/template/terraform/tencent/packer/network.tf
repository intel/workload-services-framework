#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  sg_whitelist_cidr_blocks = [
    for p in split("\n", file(var.proxy_ip_list)): p
      if replace(p,"/[0-9.]+/[0-9]+/","") != p
  ]
}

resource "tencentcloud_vpc" "default" {
  name = "wsf-${var.job_id}-vpc"
  cidr_block           = var.vpc_cidr_block
  tags = var.common_tags
}

resource "tencentcloud_subnet" "default" {
  name                    = "wsf-${var.job_id}-subnet"
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 8, 1)
  availability_zone       = var.zone
  vpc_id                  = tencentcloud_vpc.default.id
  route_table_id          = tencentcloud_vpc.default.default_route_table_id

  tags = var.common_tags
}

resource "tencentcloud_security_group" "default" {
  name = "wsf-${var.job_id}-sg"
  tags = var.common_tags
}

resource "tencentcloud_address_template" "default" {
  name      = "wsf-${var.job_id}-adr"
  addresses = local.sg_whitelist_cidr_blocks
}

resource "tencentcloud_security_group_lite_rule" "default" {
  security_group_id = tencentcloud_security_group.default.id

  ingress = [
    format("ACCEPT#%s#22#TCP", tencentcloud_address_template.default.id),
    format("ACCEPT#%s#ALL#ALL", var.vpc_cidr_block),
    "DROP#0.0.0.0/0#ALL#ALL"
  ]

  egress = [
    "ACCEPT#0.0.0.0/0#ALL#ALL"
  ]
}

