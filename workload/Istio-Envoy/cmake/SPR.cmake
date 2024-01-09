#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(cmake/common.cmake)

foreach(MODE "rps_max" "rps_sla")
    foreach(PROTOCOL "https")
        foreach(NODES "2n")
            foreach(CRYPTO_ACC "cryptomb" "qathw")
                add_testcase(${workload}_${MODE}_${PROTOCOL}_${NODES}_${CRYPTO_ACC} ${MODE} ${PROTOCOL} ${NODES} ${CRYPTO_ACC})
            endforeach()
        endforeach()        
    endforeach()
    foreach(PROTOCOL "http1" "http2" "https")
        foreach(NODES "2n")
            foreach(DLB_ACC "dlb")
                add_testcase(${workload}_${MODE}_${PROTOCOL}_${NODES}_${DLB_ACC} ${MODE} ${PROTOCOL} ${NODES} ${DLB_ACC})
            endforeach()
        endforeach()
    endforeach()        
endforeach()
