#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  image_name = replace(lower(var.image_name),"_","-")
}

data "external" "check_image" {
  program = [
    "bash",
    "-c",
    "[ \"$(gcloud compute images list --format=json --filter=\"name = ${local.image_name} AND labels.owner = ${var.owner}\")\" = \"[]\" ];echo \"{\\\"status\\\":\\\"$?\\\"}\""
  ]

  lifecycle {
    postcondition {
      condition = self.result.status == "0"
      error_message = "${var.image_name} already exists"
    }
  }
}

