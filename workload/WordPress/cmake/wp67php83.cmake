#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_workload("wordpress_wp6.7_php8.3")
foreach(nodes "1n" "2n")
    foreach(phpmode "nojit")
        foreach(httpmode "http" "https")
            if(" http " MATCHES " ${httpmode} ")
                add_testcase(${workload}_${phpmode}_${httpmode}_${nodes})
            elseif(" https " MATCHES " ${httpmode} ")
                foreach(opensslversion "openssl3.3.1")
                    foreach(syncmode "sync" "async")
                        add_testcase(${workload}_${phpmode}_${httpmode}_${opensslversion}_${syncmode}_${nodes})
                    endforeach()
                endforeach()
            endif()
        endforeach()
    endforeach()
endforeach()

add_testcase(wordpress_wp6.7_php8.3_nojit_https_openssl3.3.1_sync_1n_gated)
add_testcase(wordpress_wp6.7_php8.3_nojit_https_openssl3.3.1_async_1n_pkm)
