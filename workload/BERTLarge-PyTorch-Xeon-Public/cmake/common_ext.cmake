#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("bertlarge-pytorch-xeon-public-inference")

foreach (option   
                "throughput"
                "latency"
                "accuracy"
        )

        add_testcase(${workload}_${option}_${platform_precision} "inference_${option}_${platform_precision}")
endforeach()

add_testcase(${workload}_throughput_${platform_precision}_gated "inference_throughput_${platform_precision}_gated")
add_testcase(${workload}_throughput_${platform_precision}_pkm "inference_throughput_${platform_precision}_pkm")
