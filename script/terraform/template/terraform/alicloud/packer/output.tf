#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

output "packer" {
  value = {
    region = local.region
    zone = var.zone
    profile = var.profile
    vpc_id = alicloud_vpc.default.id
    security_group_id = alicloud_security_group.default.id
    resource_group_id = var.resource_group_id
    vswitch_id = alicloud_vswitch.default.id
    os_image_id = values(local.images)[0]
  }
}

