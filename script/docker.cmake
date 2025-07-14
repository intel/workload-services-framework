#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

function(show_backend_settings)
    message("-- Setting: DOCKER_OPTIONS=${DOCKER_OPTIONS}")
endfunction()

################ TOP-LEVEL-CMAKE ###########################

set(BACKEND_ENVS "DOCKER_CMAKE_OPTIONS='${DOCKER_OPTIONS}'")

file(WRITE "${CMAKE_BINARY_DIR}/.ansible_script_options" "--igt\n--docker\n--compose\n--collectd\n--emon\n--perf\n--sar\n--owner\n--nobomlist\n--nodockerconf\n--skip-app-status-check\n--nosutinfo\n--sutinfo\n--perfspect\n--upgrade-ingredients\n--run_stage_iterations\n")
