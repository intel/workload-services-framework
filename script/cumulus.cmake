
function(show_backend_settings)
    message("-- Setting: CUMULUS_OPTIONS=${CUMULUS_OPTIONS}")
    message("-- Setting: CUMULUS_SUT=${CUMULUS_SUT}")
endfunction()

function(add_backend_dependencies type name)
    add_dependencies(build_${name} build_cumulus)
endfunction()

function(add_backend_testcase type component name)
    if(";${sut_reqs};" STREQUAL ";;")
        string(REPLACE " " ";" cumulus_sut "${CUMULUS_SUT}")
        set(sut_list "")
        foreach(sut1 ${cumulus_sut})
            if(NOT sut1 MATCHES "^-")
                set(sut_list "${sut_list};${sut1}")
            endif()
        endforeach()
    else()
        set(sut_list "${sut_reqs}")
    endif()
    foreach(sut1 ${sut_list})
        if(sut1 AND (" ${CUMULUS_SUT} " MATCHES " ${sut1} "))
            string(REGEX REPLACE "^-" "" sut2 "${sut1}")
            add_testcase_1("${sut2}_${name}" "BACKEND=${BACKEND} CUMULUS_OPTIONS='${CUMULUS_OPTIONS}' CUMULUS_CONFIG_IN='${PROJECT_SOURCE_DIR}/script/cumulus/cumulus-config.${sut1}.yaml'" ${ARGN})
        endif()
    endforeach()
endfunction()

################ TOP-LEVEL-CMAKE ###########################

execute_process(COMMAND bash -c "echo \"\"$(find -name 'cumulus-config.*.yaml' | sed 's|.*/cumulus-config.\\(.*\\).yaml$|\\1|')" OUTPUT_VARIABLE sut_all OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/script/cumulus")
execute_process(COMMAND bash -c "echo \"\"$(find -name 'cumulus-config.*.yaml' ! -exec grep -q cloud: '{}' \\; -print | sed 's|.*/cumulus-config.\\(.*\\).yaml$|\\1|')" OUTPUT_VARIABLE CUMULUS_SUT_STATIC OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/script/cumulus")

if (NOT CUMULUS_OPTIONS)
    set(CUMULUS_OPTIONS "--docker-run --nosvrinfo")
endif()

if ((NOT DEFINED CUMULUS_SUT) OR (CUMULUS_SUT STREQUAL ""))
    set(CUMULUS_SUT "${sut_all}")
endif()

string(REPLACE " " ";" configs "${CUMULUS_SUT}")
foreach(config ${configs})
    if(NOT " ${sut_all} " MATCHES "${config}")
        message(FATAL_ERROR "Failed to locate cumulus config: ${config}")
    endif()
endforeach()

add_subdirectory(script/cumulus)
execute_process(COMMAND bash -c "ln -s -r -f '${PROJECT_SOURCE_DIR}'/script/cumulus/script/setup-sut.sh ." WORKING_DIRECTORY "${CMAKE_BINARY_DIR}")

