#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
    add_workload("Istio-Envoy")

    # native max sla 2n
    foreach(MODE "RPS-MAX" "RPS-SLA")
        foreach(PROTOCOL "http1" "http2" "https")
            foreach(NODES "2n")
                add_testcase(${workload}_${MODE}_${PROTOCOL}_${NODES} ${MODE} ${PROTOCOL} ${NODES})
            endforeach()        
        endforeach()        
    endforeach()

    # native max 1n
    foreach(MODE "RPS-MAX")
        foreach(PROTOCOL "http1")
            foreach(NODES "1n")
                add_testcase(${workload}_${MODE}_${PROTOCOL}_${NODES} ${MODE} ${PROTOCOL} ${NODES})
            endforeach()
        endforeach()
    endforeach()

    add_testcase(${workload}_RPS-MAX_http2_2n_pkm RPS-MAX http2 2n)
    add_testcase(${workload}_RPS-MAX_http1_1n_gated RPS-MAX http1 1n)
