#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(cmake/common.cmake)

foreach(MODE "RPS-MAX" "RPS-SLA")
    foreach(PROTOCOL "https")
        foreach(NODES "2n")
            foreach(CRYPTO_ACC "cryptomb")
                add_testcase(${workload}_${MODE}_${PROTOCOL}_${CRYPTO_ACC}_${NODES} ${MODE} ${PROTOCOL} ${CRYPTO_ACC} ${NODES})
            endforeach()
        endforeach()        
    endforeach()        
endforeach()
