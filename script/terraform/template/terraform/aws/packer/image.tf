#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

data "aws_ami_ids" "check_image" {
  owners = [ "self" ]

  filter {
    name = "name"
    values = [ replace(lower(var.image_name), "_", "-") ]
  }

  lifecycle {
    postcondition {
      condition = length(self.ids) == 0
      error_message = "${var.image_name} already exists"
    }
  }
}

