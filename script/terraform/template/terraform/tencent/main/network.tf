#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
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
  addresses = var.sg_whitelist_cidr_blocks
}

resource "tencentcloud_security_group_rule" "ssh" {
  security_group_id = tencentcloud_security_group.default.id
  type               = "ingress"
  ip_protocol        = "tcp"
  port_range         = "22"
  policy             = "accept"

  address_template {
    template_id = tencentcloud_address_template.default.id
  }
}

resource "tencentcloud_security_group_rule" "ping" {
  security_group_id = tencentcloud_security_group.default.id
  type        = "ingress"
  ip_protocol = "icmp"
  policy      = "accept"

  address_template {
    template_id = tencentcloud_address_template.default.id
  }
}

resource "tencentcloud_security_group_rule" "infranet_ingress" {
  security_group_id = tencentcloud_security_group.default.id

  type        = "ingress"
  cidr_ip     = var.vpc_cidr_block
  policy      = "accept"
}

resource "tencentcloud_security_group_rule" "outward_traffic" {
  security_group_id = tencentcloud_security_group.default.id

  type        = "egress"
  cidr_ip     = "0.0.0.0/0"
  policy      = "accept"
}

