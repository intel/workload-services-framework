#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  os_image_type = {
    "ubuntu" : "ubuntu_containerd"
  }
  os_image_user = {
    "ubuntu": "ubuntu",
  }
}
