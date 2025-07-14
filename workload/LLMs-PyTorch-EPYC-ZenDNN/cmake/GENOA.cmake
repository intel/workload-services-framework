#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
set(platform_precision "fp32")

add_workload("llms_pytorch_epyc-ZenDNN")
 
add_testcase(${workload}_inference_throughput_bf16 "inference_throughput" )
add_testcase(${workload}_inference_latency_bf16 "inference_latency" )
add_testcase(${workload}_inference_throughput_bf16_gated "inference_throughput" )
add_testcase(${workload}_inference_throughput_bf16_pkm "inference_throughput" )
