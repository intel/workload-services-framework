if(ENABLE_BUILD)
    add_custom_target(build_csp_common bash -c "PLATFORM=X64 IMAGEARCH=linux/amd64 BACKEND=${BACKEND} RELEASE=${RELEASE} REGISTRY=${REGISTRY} SCRIPT='${PROJECT_SOURCE_DIR}/script' '${CMAKE_CURRENT_SOURCE_DIR}/build.sh'")
else()
    add_custom_target(build_csp_common)
endif()

execute_process(COMMAND bash -c "mkdir -p '${CMAKE_CURRENT_SOURCE_DIR}/.docker' > /dev/null; touch '${CMAKE_CURRENT_SOURCE_DIR}/.gitconfig' 2>/dev/null; chmod 600 '${CMAKE_CURRENT_SOURCE_DIR}'/ssh_config" OUTPUT_QUIET ERROR_QUIET)

foreach(cloud .aws .config .azure .tccli .aliyun)
    if ((NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${cloud}") AND (EXISTS "${PROJECT_SOURCE_DIR}/script/cumulus/${cloud}"))
        execute_process(COMMAND "cp" "-rf" "${PROJECT_SOURCE_DIR}/script/cumulus/${cloud}" "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
endforeach()

