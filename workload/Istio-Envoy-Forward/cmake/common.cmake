#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
    add_workload("Istio-Envoy-Forward")

    foreach(MODE "RPS-MAX" "RPS-SLA")
        foreach(PROTOCOL "http1")
            add_testcase(${workload}_${MODE}_${PROTOCOL}_2n ${MODE} ${PROTOCOL})
        endforeach()
    endforeach()

    add_testcase(${workload}_RPS-MAX_http1_2n_pkm RPS-MAX http1 2n)
    add_testcase(${workload}_RPS-MAX_http1_2n_gated RPS-MAX http1 2n)
