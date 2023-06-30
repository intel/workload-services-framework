# Define the edge ceph virtIO workload usecase in this file, and there is no platform dependence for this storage stack.
#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

if(NOT BACKEND STREQUAL "docker")

		add_workload("edge_ceph_virtio")

		# virtIO - Virtulization IO, traditional kubevirt IO test
		# vhost - Optimizaed VM IO with vhost solution.
		foreach (schema "virtIO" "vhost")
			foreach (operation_mode "sequential" "random")
				foreach (io_operation "read" "write")
					add_testcase(${workload}_block_${schema}_${operation_mode}_${io_operation} "${schema}_${operation_mode}_${io_operation}")
				endforeach()
			endforeach()
		endforeach()

		# Set two PKM use case. For each workload, the we need to define at least 1 pkm case, and no more than 2.
		add_testcase(${workload}_block_virtIO_random_read_pkm "virtIO_random_read_pkm")

		add_testcase(${workload}_block_gated "gated") # gated case

endif()