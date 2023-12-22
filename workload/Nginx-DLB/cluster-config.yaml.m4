#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

cluster:
- labels:
    HAS-SETUP-NGINX-CACHE: required
  vm_group: worker
- labels: {}
  vm_group: worker
- labels: {}
  vm_group: client
