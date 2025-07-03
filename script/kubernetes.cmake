#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

execute_process(COMMAND kubectl get pod RESULT_VARIABLE status_code OUTPUT_QUIET ERROR_QUIET)
if(status_code EQUAL 0)
    set(BACKEND "kubernetes")
    if (NOT REGISTRY)
        message("${red}WARNING:${reset} A valid REGISTRY value is required after Kuberentes v1.24+")
        message("")
    endif()
else()
    set(BACKEND "docker")
    message("${red}WARNING:${reset} Falled to detect a valid Kubernetes setup.")
    message("  Default to the docker backend.")
    message("")
endif()

function(show_backend_settings)
    message("-- Setting: KUBERNETES_OPTIONS=${KUBERNETES_OPTIONS}")
endfunction()

file(WRITE "${CMAKE_BINARY_DIR}/.ansible_script_options" "--kubernetes\n--owner\n--nobomlist\n--nodockerconf\n--skip-app-status-check\n--upgrade-ingredients\n--run_stage_iterations\n")
