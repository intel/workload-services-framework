# Define the workload usecase in this file, in this workload we will benchmark the use case with DSA feature enabled.
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if(" SPR " MATCHES " ${PLATFORM} ")
	add_workload("spdk_nvme_o_tcp")

	# For gated case
	add_testcase(${workload}_gated)

	foreach (type "withDSA" "noDSA")
			foreach (operation_mode "sequential" "random")
				foreach (io_operation "read" "write" "mixedrw")
					add_testcase(${workload}_${type}_${operation_mode}_${io_operation} "${type}_${operation_mode}_${io_operation}")
				endforeach()
			endforeach()
	endforeach()

	# for pkm
	add_testcase(${workload}_withDSA_sequential_read_pkm "withDSA_sequential_read_pkm")

endif()
