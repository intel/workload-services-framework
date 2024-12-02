#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

output "packer" {
  value = {
    region = local.region
    zone = var.zone
    vpc_id = tencentcloud_vpc.default.id
    security_group_id = tencentcloud_security_group.default.id
    subnet_id = tencentcloud_subnet.default.id
    os_image_id = data.tencentcloud_images.search.images.0.image_id
  }
}
