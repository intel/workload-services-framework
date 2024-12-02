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

