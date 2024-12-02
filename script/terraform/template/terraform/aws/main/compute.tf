#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
resource "aws_key_pair" "default" {
  key_name   = "wsf-${var.job_id}-key"
  public_key = var.ssh_pub_key

  tags = {
    Name  = "wsf-${var.job_id}-key"
  }
}

resource "aws_instance" "default" {
  for_each = local.ondemand_instances

  availability_zone = aws_subnet.default.availability_zone
  instance_type = each.value.instance_type
  cpu_core_count = each.value.cpu_core_count
  cpu_threads_per_core = each.value.threads_per_core

  ami = each.value.os_image==null?data.aws_ami.search[each.value.profile].id:(startswith(each.value.os_image,"ami-")?each.value.os_image:data.aws_ami.image[each.key].image_id)

  key_name = aws_key_pair.default.key_name
  vpc_security_group_ids = [aws_default_security_group.default.id]
  subnet_id = aws_subnet.default.id

  depends_on = [aws_internet_gateway.default]

  user_data_base64 = local.is_windows[each.key]?base64encode(data.template_file.windows[each.key].rendered):data.template_cloudinit_config.linux[each.key].rendered
  instance_initiated_shutdown_behavior = "terminate"
  get_password_data = local.is_windows[each.key]

  root_block_device {
    tags = {
      Name = "wsf-${var.job_id}-${each.key}-root-disk"
    }
    volume_size = each.value.os_disk_size
    volume_type = each.value.os_disk_type
    iops = each.value.os_disk_iops
    throughput = each.value.os_disk_throughput
  }

  dynamic "ephemeral_block_device" {
    for_each = local.isv_disks[each.key]
    content {
      device_name = ephemeral_block_device.value.device_name
      virtual_name = ephemeral_block_device.value.virtual_name
    }
  }

  tags = {
    Name = "wsf-${var.job_id}-instance-${each.key}"
  }
}

resource "aws_spot_instance_request" "default" {
  for_each = local.spot_instances

  availability_zone = aws_subnet.default.availability_zone
  instance_type = each.value.instance_type
  cpu_core_count = each.value.cpu_core_count
  cpu_threads_per_core = each.value.threads_per_core
  ami = each.value.os_image==null?data.aws_ami.search[each.value.profile].id:(startswith(each.value.os_image,"ami-")?each.value.os_image:data.aws_ami.image[each.key].image_id)

  key_name = aws_key_pair.default.key_name
  vpc_security_group_ids = [aws_default_security_group .default.id]
  subnet_id = aws_subnet.default.id

  spot_price = var.spot_price
  wait_for_fulfillment = true
  spot_type = "one-time"
  instance_interruption_behavior = "terminate"

  depends_on = [aws_internet_gateway.default]

  user_data_base64 = local.is_windows[each.key]?base64encode(data.template_file.windows[each.key].rendered):data.template_cloudinit_config.linux[each.key].rendered
  instance_initiated_shutdown_behavior = "terminate"
  get_password_data = local.is_windows[each.key]

  root_block_device {
    tags = {
      Name = "wsf-${var.job_id}-${each.key}-root-disk"
    }
    volume_size = each.value.os_disk_size
    volume_type = each.value.os_disk_type
  }

  dynamic "ephemeral_block_device" {
    for_each = local.isv_disks[each.key]
    content {
      device_name = ephemeral_block_device.value.device_name
      virtual_name = ephemeral_block_device.value.virtual_name
    }
  }

  tags = {
    Name = "wsf-${var.job_id}-spot-request-${each.key}"
    Region = local.region
  }

  provisioner "local-exec" {
    command = format("aws ec2 create-tags --color=off --region %s --resources %s --tags %s", local.region, self.spot_instance_id, join(" ", [
      for k,v in merge(var.common_tags, {
        Name = "wsf-${var.job_id}-instance-${each.key}"
      }): format("Key=%s,Value=%s", k, v)
    ]))
  }

  provisioner "local-exec" {
    when = destroy
    command = format("aws ec2 delete-tags --color=off --region %s --resources %s %s;true", self.tags_all["Region"], self.id, self.spot_instance_id)
  }
}

