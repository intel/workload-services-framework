#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if (NOT BACKEND STREQUAL "docker")
    foreach (IPERF_VER 2)
        add_workload("iperf${IPERF_VER}")
        if (BACKEND STREQUAL "terraform")
            set(MODES "pod2pod;pod2svc;ingress")
        else()
            set(MODES "pod2pod;pod2svc")
        endif()

        foreach (MODE ${MODES})
            add_testcase("${workload}-${MODE}_tcp_base" "${IPERF_VER}" "TCP" "${MODE}")
            add_testcase("${workload}-${MODE}_udp_base" "${IPERF_VER}" "UDP" "${MODE}")
        endforeach()
    endforeach()
    add_testcase("iperf2-pod2pod_tcp_pkm" "2" "TCP" "pod2pod")
    add_testcase("iperf2-pod2pod_tcp_gated" "2" "TCP" "pod2pod")
endif()
