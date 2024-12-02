#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

include(component)

function(add_image name)
    add_component_build(image ${name} ${ARGN})
    set(image ${component} PARENT_SCOPE)
    set(sut_reqs "${sut_reqs}" PARENT_SCOPE)
endfunction()

function(add_testcase name)
    add_component_testcase(image ${image} ${name} ${ARGN})
endfunction()

