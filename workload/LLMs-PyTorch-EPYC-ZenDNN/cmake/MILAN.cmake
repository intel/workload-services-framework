#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
set(platform_precision "fp32")

add_workload("llms_pytorch_epyc-ZenDNN")
 
add_testcase(${workload}_inference_throughput_paiv "inference_throughput_paiv")
add_testcase(${workload}_inference_latency_paiv "inference_latency_paiv")
add_testcase(${workload}_inference_throughput_paiv_gated "inference_throughput_paiv_gated")
add_testcase(${workload}_inference_throughput_paiv_pkm "inference_throughput_paiv_pkm")
