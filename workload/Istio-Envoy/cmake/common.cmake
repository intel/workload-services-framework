#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
    add_workload("istio_envoy")

    # native max sla 2n
    foreach(MODE "rps_max" "rps_sla")
        foreach(PROTOCOL "http1" "http2" "https")
            foreach(NODES "2n")
                add_testcase(${workload}_${MODE}_${PROTOCOL}_${NODES} ${MODE} ${PROTOCOL} ${NODES})
            endforeach()        
        endforeach()        
    endforeach()

    # native max 1n
    foreach(MODE "rps_max")
        foreach(PROTOCOL "http1")
            foreach(NODES "1n")
                add_testcase(${workload}_${MODE}_${PROTOCOL}_${NODES} ${MODE} ${PROTOCOL} ${NODES})
            endforeach()
        endforeach()
    endforeach()

    # ebpf case
    foreach(MODE "rps_max")
        foreach(PROTOCOL "http1" "http2")
            foreach(NODES "1n" "2n")
                foreach(EBPF "ebpf")
                    add_testcase(${workload}_${MODE}_${PROTOCOL}_${NODES}_${EBPF} ${MODE} ${PROTOCOL} ${NODES} ${EBPF})
                endforeach()
            endforeach()
        endforeach()
    endforeach()

    # boringssl with vAES + vPCLMULQDQ patch
    foreach(MODE "rps_max" "rps_sla")
        foreach(PROTOCOL "http1" "https")
            foreach(NODES "2n")
                foreach(AVX512_PATCH "avx512")
                    add_testcase(${workload}_${MODE}_${PROTOCOL}_${NODES}_${AVX512_PATCH} ${MODE} ${PROTOCOL} ${NODES} ${AVX512_PATCH})
                endforeach() 
            endforeach()        
        endforeach()        
    endforeach()

    add_testcase(${workload}_rps_max_http2_2n_pkm rps_max http2 2n)
    add_testcase(${workload}_rps_max_http1_1n_gated rps_max http1 1n)
