#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
output "packer" {
  value = {
    region: local.region
    zone: var.zone
    compartment: var.compartment
    vcn_id: oci_core_vcn.default.id
    subnet_id: oci_core_subnet.default.id
  }
}
