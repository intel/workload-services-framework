#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

# The cluster-config.yaml.m4 manifest specifies the workload running environment. 
# For the simple dummy workload, the manifest requests to run the workload on a 
# single-node cluster, without any special requirement of host setup. See 
# doc/developer-guide/component-design/cluster-config.md for full documentation.

cluster:
- labels: {}
