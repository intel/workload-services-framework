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

resource "alicloud_vpc" "default" {
  vpc_name = "wsf-${var.job_id}-vpc"
  cidr_block = var.vpc_cidr_block
  resource_group_id = var.resource_group_id
  tags = var.common_tags
}

resource "alicloud_vswitch" "default" {
  vswitch_name = "wsf-${var.job_id}-vswitch"
  zone_id = var.zone
  vpc_id = alicloud_vpc.default.id
  cidr_block = cidrsubnet(var.vpc_cidr_block, 8, 1)
  tags = var.common_tags
}

resource "alicloud_security_group" "default" {
  security_group_name = "wsf-${var.job_id}-sg"
  vpc_id = alicloud_vpc.default.id
  security_group_type = "normal"
  resource_group_id = var.resource_group_id
  inner_access_policy = "Accept"
  tags = var.common_tags
}

resource "alicloud_security_group_rule" "ssh" {
  for_each = toset(local.sg_whitelist_cidr_blocks)

  type = "ingress"
  ip_protocol = "tcp"
  port_range = "22/22"
  security_group_id = alicloud_security_group.default.id
  cidr_ip = each.value
}

resource "alicloud_security_group_rule" "outward_traffic" {
  type = "egress"
  ip_protocol = "all"
  security_group_id = alicloud_security_group.default.id
  cidr_ip = "0.0.0.0/0"
}

