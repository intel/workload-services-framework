#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

function(show_backend_settings)
    message("-- Setting: TERRAFORM_OPTIONS=${TERRAFORM_OPTIONS_ESC}")
    message("-- Setting: TERRAFORM_SUT=${TERRAFORM_SUT}")
    if(DEFINED SPOT_INSTANCE)
        message("-- Setting: SPOT_INSTANCE=${SPOT_INSTANCE}")
    endif()
endfunction()

function(detect_backend_warnings)
    if(NOT DEFINED SPOT_INSTANCE)
        set(spot_found "")
        string(REPLACE " " ";" suts "${TERRAFORM_SUT}")
        foreach(sut ${suts})
            execute_process(COMMAND sed -n "/^\\s*variable\\s*[\"]spot_instance[\"]\\s*[{]/,/^\\s*[}]/p" "terraform-config.${sut}.tf" WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}/script/terraform" ERROR_QUIET OUTPUT_VARIABLE spot_det)
            if(spot_det MATCHES "true")
                set(spot_found "${spot_found} ${sut}")
            endif()
        endforeach()
        if(spot_found)
            message("${red}WARNING:${reset} SPOT instance detected in SUT:${spot_found}")
            message("  For performance, disable spot instance with 'cmake -DSPOT_INSTANCE=false ..'")
        endif()
    endif()
endfunction()

function(add_backend_dependencies type name)
    add_dependencies(build_${name} build_terraform)
    set_property(DIRECTORY APPEND PROPERTY ADDITIONAL_MAKE_CLEAN_FILES "${CMAKE_CURRENT_BINARY_DIR}/.signature")
endfunction()

function(add_backend_tools type)
    execute_process(COMMAND ln -s -r -f "${PROJECT_SOURCE_DIR}/script/terraform/script/debug.sh" . WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}")
endfunction()

function(add_backend_testcase type component name)
    foreach(sut1 ${sut_reqs})
        if(sut1)
            string(REGEX REPLACE "^-" "" sut2 "${sut1}")
            add_testcase_1("${sut2}_${name}" "BACKEND=${BACKEND} ${BACKEND_ENVS} TERRAFORM_CONFIG_IN='${PROJECT_SOURCE_DIR}/script/terraform/terraform-config.${sut1}.tf' TERRAFORM_SUT=${sut1}" ${ARGN})
        endif()
    endforeach()
endfunction()

################ TOP-LEVEL-CMAKE ###########################

execute_process(COMMAND bash -c "echo \"\"$(find -name 'terraform-config.*.tf' | sed 's|.*/terraform-config.\\(.*\\).tf$|\\1|')" OUTPUT_VARIABLE sut_all OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/script/terraform")

if (NOT TERRAFORM_OPTIONS)
    set(TERRAFORM_OPTIONS "--docker --svrinfo --intel_publish")
endif()

set(TERRAFORM_OPTIONS_ESC "${TERRAFORM_OPTIONS}")
if (PLATFORM MATCHES "ARMv")
    string(REGEX REPLACE "--emon" "${red}${strikethrough}--emon${reset}" TERRAFORM_OPTIONS_ESC "${TERRAFORM_OPTIONS_ESC}")
    string(REGEX REPLACE "--emon *" "" TERRAFORM_OPTIONS "${TERRAFORM_OPTIONS}")
endif()
if(NOT EXISTS "${PROJECT_SOURCE_DIR}/script/terraform/script/publish-intel.py")
    string(REGEX REPLACE "--intel_publish" "${red}${strikethrough}--intel_publish${reset}" TERRAFORM_OPTIONS_ESC "${TERRAFORM_OPTIONS_ESC}")
    string(REGEX REPLACE "--intel_publish *" "" TERRAFORM_OPTIONS "${TERRAFORM_OPTIONS}")
endif()

if (TERRAFORM_SUT STREQUAL "")
    set(TERRAFORM_SUT "${sut_all}")
elseif (NOT DEFINED TERRAFORM_SUT)
    set(TERRAFORM_SUT "static")
    message("${green}INFO:${reset} Default to use the static SUT type for quick evaluation.")
    message("  Enable specific SUT type(s) with cmake -DTERRAFORM_SUT=<name> .. or")
    message("  Enable all SUT types with cmake -DTERRAFORM_SUT= ..")
    message("")
endif()

string(REPLACE " " ";" configs "${TERRAFORM_SUT}")
foreach(config ${configs})
    if(NOT " ${sut_all} " MATCHES " ${config} ")
        message(FATAL_ERROR "Failed to locate terraform config: ${config}")
    endif()
endforeach()

set(BACKEND_ENVS "TERRAFORM_OPTIONS='${TERRAFORM_OPTIONS}' TERRAFORM_SUT='${TERRAFORM_SUT}'")
if(DEFINED SPOT_INSTANCE)
  if(SPOT_INSTANCE)
    set(SPOT_INSTANCE "true")
  else()
    set(SPOT_INSTANCE "false")
  endif()
  set(BACKEND_ENVS "${BACKEND_ENVS} SPOT_INSTANCE='${SPOT_INSTANCE}'")
endif()
add_subdirectory(script/csp)
add_subdirectory(script/terraform)
if(EXISTS "${CMAKE_SOURCE_DIR}/script/dashboard")
    add_subdirectory(script/dashboard)
endif()

