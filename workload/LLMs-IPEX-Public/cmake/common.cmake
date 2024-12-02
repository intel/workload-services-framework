#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("llms_ipex_public")

add_testcase(${workload}_inference_throughput_${platform_precision} "inference_throughput_${platform_precision}")
add_testcase(${workload}_inference_accuracy_${platform_precision} "inference_accuracy_${platform_precision}")
add_testcase(${workload}_inference_latency_${platform_precision} "inference_latency_${platform_precision}")
add_testcase(${workload}_inference_latency_${platform_precision}_gated "inference_latency_${platform_precision}_gated")
add_testcase(${workload}_inference_latency_${platform_precision}_pkm "inference_latency_${platform_precision}_pkm")