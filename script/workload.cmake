#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

include(component)

function(add_workload name)
    add_component_build(workload ${name} ${ARGN})
    set(workload ${component} PARENT_SCOPE)
    set(sut_reqs "${sut_reqs}" PARENT_SCOPE)
    set(build_args "${build_args}" PARENT_SCOPE)
endfunction()

function(add_testcase name)    
    add_component_testcase(workload ${workload} ${name} ${ARGN})    
endfunction()
