#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

resource "alicloud_ecs_key_pair" "default" {
  key_pair_name = replace("wsf-${var.job_id}", "-", "_")
  public_key = var.ssh_pub_key
  resource_group_id = var.resource_group_id
  tags = var.common_tags
}

resource "alicloud_instance" "default" {
  for_each = local.instances

  instance_name = "wsf-${var.job_id}-${each.key}-instance"
  host_name = each.key
  image_id = local.images[each.value.profile]
  instance_type = each.value.instance_type
  security_groups = [ alicloud_security_group.default.id ]
  system_disk_category = each.value.os_disk_type
  system_disk_size = each.value.os_disk_size
  system_disk_performance_level = each.value.os_disk_performance
  resource_group_id = var.resource_group_id
  vswitch_id = alicloud_vswitch.default.id

  credit_specification = "Unlimited"

  spot_strategy = var.spot_instance?(var.spot_price>0?"SpotWithPriceLimit":"SpotAsPriceGo"):"NoSpot"
  spot_price_limit = var.spot_instance?var.spot_price:null

  internet_max_bandwidth_out = var.internet_bandwidth

  key_name = alicloud_ecs_key_pair.default.id

  user_data = "${data.template_cloudinit_config.default[each.key].rendered}"

  tags = var.common_tags
}

