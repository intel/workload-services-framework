#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  sg_whitelist_cidr_blocks = [
    for p in var.sg_whitelist_cidr_blocks: p
      if replace(p,"/[0-9.]+/[0-9]+/","") != p
  ]
}

locals {
  support_multicast = ["ap-beijing", "ap-shanghai", "ap-guangzhou", "ap-chengdu", "ap-chongqing",
  "ap-nanjing", "ap-hongkong", "ap-singapore", "ap-seoul", "ap-tokyo", "ap-bangkok", "na-toronto",
  "na-siliconvalley", "na-ashburn", "eu-frankfurt"]
}

resource "tencentcloud_vpc" "default" {
  name         = "wsf-${var.job_id}-vpc"
  cidr_block   = var.vpc_cidr_block
  is_multicast = contains(local.support_multicast, local.region) ? true : false
  tags         = var.common_tags
}

resource "tencentcloud_subnet" "default" {
  name                    = "wsf-${var.job_id}-subnet"
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 8, 1)
  availability_zone       = var.zone
  vpc_id                  = tencentcloud_vpc.default.id
  route_table_id          = tencentcloud_vpc.default.default_route_table_id
  is_multicast            = contains(local.support_multicast, local.region) ? true : false
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

resource "tencentcloud_security_group_rule_set" "default" {
  security_group_id = tencentcloud_security_group.default.id

  ingress {
    action = "ACCEPT"
    address_template_id = tencentcloud_address_template.default.id
  }

  ingress {
    action = "ACCEPT"
    cidr_block = var.vpc_cidr_block
  }

  ingress {
    action = "DROP"
    cidr_block = "0.0.0.0/0"
  }

  egress {
    action = "ACCEPT"
    cidr_block = "0.0.0.0/0"
  }
}

