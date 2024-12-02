#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

function(add_dist name)
    file(RELATIVE_PATH component_path "${PROJECT_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}")
    if("/${component_path}//" MATCHES "/[^/]*${BENCHMARK}[^/]*/")
        add_custom_target(dist_${name} ALL COMMAND bash -c "BACKEND=${BACKEND} REGISTRY=${REGISTRY} RELEASE=${RELEASE} '${CMAKE_SOURCE_DIR}/script/create-dist.sh' '${CMAKE_CURRENT_SOURCE_DIR}'")
    endif()
endfunction()

