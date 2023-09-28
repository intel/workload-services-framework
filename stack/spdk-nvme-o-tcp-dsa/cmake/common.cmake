#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
add_stack(spdk_nvme_tcp_dsa_service)


foreach (type "withDSA" "noDSA")
        foreach (operation_mode "sequential" "random")
            # Add more test case here: "read/write/mixedrw"
            foreach (io_operation "read" )
                add_testcase(${stack}_${type}_${operation_mode}_${io_operation} "${type}_${operation_mode}_${io_operation}")
            endforeach()
        endforeach()
endforeach()
