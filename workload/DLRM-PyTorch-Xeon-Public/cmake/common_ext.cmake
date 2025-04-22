#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("dlrm_pytorch_xeon_public_inference_throughput")
add_testcase(${workload}_${platform_precision} "${workload}_${platform_precision}")
add_testcase(${workload}_${platform_precision}_gated "${workload}_${platform_precision}_gated")
add_testcase(${workload}_${platform_precision}_pkm "${workload}_${platform_precision}_pkm")

add_workload("dlrm_pytorch_xeon_public_inference_accuracy")
add_testcase(${workload}_${platform_precision} "${workload}_${platform_precision}")
