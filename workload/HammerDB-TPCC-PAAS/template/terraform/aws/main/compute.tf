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

resource "aws_db_parameter_group" "default" {
  name   = "${var.common_tags["owner"]}"
  family = "mysql8.0"

  dynamic "parameter" {
    for_each = local.custom_database_parameters

    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = lookup(parameter.value, "apply_method", null)
    }
  }
}

resource "random_password" "default" {
  length      = 12
  min_upper   = 4
  min_lower   = 2
  min_numeric = 4
  special     = false
}

resource "aws_db_instance" "default" {
  identifier            = local.identifier
  engine                = var.engine
  engine_version        = var.engine_version
  instance_class        = local.instance_class
  allocated_storage     = var.allocated_storage
  storage_type          = var.storage_type
  db_name               = var.db_name
  username              = var.username
  password              = random_password.default.result
  port                  = var.port
  apply_immediately     = true

  parameter_group_name   = aws_db_parameter_group.default.id
  db_subnet_group_name   = aws_db_subnet_group.default.id
  vpc_security_group_ids = [aws_security_group.rds.id]
 
  iops                   = var.iops

  enabled_cloudwatch_logs_exports = [var.enabled_cloudwatch_logs_exports]
  deletion_protection             = var.deletion_protection

  skip_final_snapshot  = true
  multi_az             = false
  publicly_accessible  = false

  tags = var.common_tags
}


