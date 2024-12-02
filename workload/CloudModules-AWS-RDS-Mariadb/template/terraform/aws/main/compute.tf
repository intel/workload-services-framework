#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "aws_instance" "default" {
  for_each = local.ondemand_instances

  availability_zone = data.aws_availability_zones.available.names[0]
  instance_type = each.value.instance_type
  ami = each.value.os_image!=null?each.value.os_image:data.aws_ami.search[each.value.profile].id

  key_name = "wsf-${var.job_id}-key"
  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id = aws_subnet.public.id
  associate_public_ip_address = true

  depends_on = [aws_internet_gateway.igw]
  
  root_block_device {
    tags = var.common_tags
    volume_size = each.value.os_disk_size
    volume_type = each.value.os_disk_type
  }

  tags = var.common_tags
}

resource "random_password" "default" {
  length      = 12
  min_upper   = 4
  min_lower   = 2
  min_numeric = 4
  special     = false
}

module "optimized-mariadb-server" {
  source                 = "intel/aws-mariadb/intel"
  db_password            = random_password.default.result
  rds_identifier         = local.identifier
  vpc_id                 = aws_vpc.main.id
  version                = "v1.1.1"
  create_security_group  = false
  create_subnet_group    = true
  multi_az               = false
  db_name                = "postdb"
  security_group_ids     = [aws_security_group.rds.id]
  depends_on             = [aws_vpc.main, aws_subnet.private1, aws_subnet.private2]
}
