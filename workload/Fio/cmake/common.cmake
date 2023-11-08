#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
    add_workload("fio")
    add_testcase(${workload}_gated sequential_read)
    add_testcase(${workload}_sequential_read_pkm sequential_read)
    add_testcase(${workload}_sequential_write_pkm sequential_write)
    add_testcase(${workload}_sequential_read sequential_read)
    add_testcase(${workload}_sequential_write sequential_write)
    add_testcase(${workload}_random_read random_read)
    add_testcase(${workload}_random_write random_write)
    add_testcase(${workload}_sequentialreadwrite sequential_read_write)
    add_testcase(${workload}_randomreadwrite random_read_write)
