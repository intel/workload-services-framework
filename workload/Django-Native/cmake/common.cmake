#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("django_native")

foreach (nodes "1")
    foreach (option "django_native_pkm")
        foreach(tls "on" "off")
            add_testcase(${workload}_tls_${tls}_${nodes}_nodes_${option} "tls_${tls}_${nodes}_nodes_${option}")
	    endforeach()
    endforeach()
endforeach()
add_testcase(${workload}_tls_off_1_nodes_django_native_gated "tls_off_1_nodes_django_native_gated")