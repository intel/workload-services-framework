if(ENABLE_BUILD)
    add_custom_target(build_cumulus bash -c "PLATFORM=X64 IMAGEARCH=linux/amd64 BACKEND=${BACKEND} RELEASE=${RELEASE} REGISTRY=${REGISTRY} CUMULUS_SUT='${CUMULUS_SUT}' CUMULUS_OPTIONS='${CUMULUS_OPTIONS}' SCRIPT='${PROJECT_SOURCE_DIR}/script' '${CMAKE_CURRENT_SOURCE_DIR}/build.sh'")
else()
    add_custom_target(build_cumulus)
endif()

execute_process(COMMAND bash -c "mkdir -p '${CMAKE_CURRENT_SOURCE_DIR}/.docker' > /dev/null; touch '${CMAKE_CURRENT_SOURCE_DIR}/.gitconfig' 2>/dev/null; chmod 600 '${CMAKE_CURRENT_SOURCE_DIR}'/ssh_config" OUTPUT_QUIET ERROR_QUIET)

foreach(cloud aws gcp azure tencent alicloud)
    add_custom_target(${cloud} COMMAND bash -c "REGISTRY=${REGISTRY} RELEASE=${RELEASE} '${CMAKE_CURRENT_SOURCE_DIR}/shell.sh' ${cloud} -v '${CMAKE_CURRENT_SOURCE_DIR}:/home' -v '${CMAKE_CURRENT_SOURCE_DIR}:/root' -t -- bash || true" VERBATIM)
endforeach()

