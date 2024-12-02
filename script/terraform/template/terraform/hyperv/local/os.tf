#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  os = {
    "windows2022": {
      "path": "windows-server-2022-gen${var.generation}.vhdx",
      "user": "wsfuser",
    },
    "ubuntu2204": {
      "path": "ubuntu-server-2204.vhdx",
      "user": "ubuntu",
    },
  }
}

