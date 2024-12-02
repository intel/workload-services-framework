#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
    add_workload("mlc")

    foreach(check "local_latency" "local_latency_random" "remote_latency" "remote_latency_random" "llc_bandwidth"
        "local_read_bandwidth" "peak_remote_bandwidth" "peak_remote_bandwidth_reverse" "peak_bandwidth_rw_combo_1tpc" "peak_bandwidth_rw_combo_2tpc"
        "loaded_latency" "local_socket_remote_cluster_memory_latency" "local_socket_local_cluster_l2hit_latency" "remote_socket_remotely_homed_l2hitm_latency"
        "local_socket_remote_cluster_locally_homed_l2hitm_latency" "local_socket_local_cluster_l3hit_latency" "local_socket_remote_cluster_l3hit_latency"
        "remote_socket_remotely_homed_l3hit_latency" "idle_latency" "latency_matrix" "peak_injection_bandwidth" "cache_to_cache_transfer_latency" "memory_bandwidth_matrix" "latency_matrix_random_access")

        add_testcase(${workload}_${check} ${check})
    endforeach()

    add_testcase(${workload}_local_latency_gated "local_latency")
    add_testcase(${workload}_local_latency_pkm "local_latency")