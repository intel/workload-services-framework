#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

variable kvm_host {
  type = string
  nullable = false
}

variable kvm_host_user {
  type = string
  nullable = false
}

variable kvm_host_port {
  type = number
  default = 22
}

variable pool_name {
  type = string
  default = "osimages"
}

variable image_name {
  type = string
  nullable = false
}

