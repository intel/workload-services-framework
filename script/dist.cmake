#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

function(add_dist name)
    file(RELATIVE_PATH component_path "${PROJECT_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}")
    set(benchmark "${BENCHMARK}")
    if(BENCHMARK MATCHES "^dist/hybrid/v[0-9]+[.][0-9]+[.]*[0-9]*$")
        string(REPLACE "dist/hybrid/v" "" release1 "${BENCHMARK}")
        if(official_releases MATCHES "${release1}")
            set(benchmark "dist/hybrid")
        endif()
    endif()
    if("/${component_path}//" MATCHES "/[^/]*${benchmark}[^/]*/")
        message("${green}INFO${reset}: Enabled ${BENCHMARK}")
        add_custom_target(dist_${name} ALL COMMAND bash -c "BACKEND=${BACKEND} ${BACKEND_ENVS} PLATFORM=${PLATFORM} REGISTRY=${REGISTRY} REGISTRY_AUTH=${REGISTRY_AUTH} RELEASE=${RELEASE} TIMEOUT=${TIMEOUT} BENCHMARK=${BENCHMARK} PROJECTROOT='${PROJECT_SOURCE_DIR}' BUILDROOT='${CMAKE_BINARY_DIR}' '${CMAKE_SOURCE_DIR}/script/create-dist.sh' '${CMAKE_CURRENT_SOURCE_DIR}'")
    endif()
endfunction()

