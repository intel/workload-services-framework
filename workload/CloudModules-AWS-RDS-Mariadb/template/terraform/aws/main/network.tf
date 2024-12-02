#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.common_tags
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = var.common_tags
}

resource "aws_route" "route-public" {
  route_table_id         = aws_vpc.main.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = var.common_tags
  depends_on              = [module.optimized-mariadb-server]
}

resource "aws_subnet" "private1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private1_cidr
  availability_zone       = data.aws_availability_zones.available.names[1]
  tags = var.common_tags
}

resource "aws_subnet" "private2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private2_cidr
  availability_zone       = data.aws_availability_zones.available.names[2]
  tags = var.common_tags
}

resource "aws_eip" "gw" {
  vpc        = true
  depends_on = [aws_internet_gateway.igw]
  tags = var.common_tags
}

resource "aws_nat_gateway" "gw" {
  subnet_id     = aws_subnet.public.id
  allocation_id = aws_eip.gw.id

  tags = var.common_tags
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = var.common_tags
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw.id
  }

  tags = var.common_tags
}

resource "aws_route_table_association" "default" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private1" {
  subnet_id      = aws_subnet.private1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private2" {
  subnet_id      = aws_subnet.private2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "ec2" {
  name        = "wsf-${var.job_id}-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = var.sg_whitelist_cidr_blocks
  }

  ingress {
    description      = "PING"
    from_port        = 8
    to_port          = 0
    protocol         = "icmp"
    cidr_blocks      = var.sg_whitelist_cidr_blocks
  }

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = var.common_tags
}

resource "aws_security_group" "rds" {
  name        = "wsf-${var.job_id}-sg-rds"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = var.common_tags
}
