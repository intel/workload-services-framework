#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#


data "oci_core_images" "check_image" {
  compartment_id = var.compartment
  display_name = replace(lower(var.image_name), "_", "-")

  lifecycle {
    postcondition {
      condition = length(self.images) == 0
      error_message = "${var.image_name} already exists"
    }
  }
}


