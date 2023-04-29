
add_custom_target(build_terraform COMMAND bash -c "PLATFORM=X64 IMAGEARCH=linux/amd64 BACKEND=${BACKEND} RELEASE=${RELEASE} REGISTRY=${REGISTRY} ${BACKEND_ENVS} PROJECTROOT='${PROJECT_SOURCE_DIR}' SOURCEROOT='${CMAKE_CURRENT_SOURCE_DIR}' BUILDROOT='${CMAKE_BINARY_DIR}' '${CMAKE_CURRENT_SOURCE_DIR}/build.sh' ${BUILDSH_OPTIONS}" DEPENDS build_csp_common)

foreach(cloud aws gcp azure tencent alicloud vsphere oracle)
    add_custom_target(${cloud} COMMAND bash -c "REGISTRY=${REGISTRY} RELEASE=${RELEASE} ${BACKEND_ENVS} PROJECTROOT='${PROJECT_SOURCE_DIR}' SOURCEROOT='${CMAKE_CURRENT_SOURCE_DIR}' BUILDROOT='${CMAKE_BINARY_DIR}' '${CMAKE_CURRENT_SOURCE_DIR}/shell.sh' ${cloud} -v '${CMAKE_CURRENT_SOURCE_DIR}/../csp:/home' -v '${CMAKE_CURRENT_SOURCE_DIR}/../csp:/root' -v '${CMAKE_CURRENT_SOURCE_DIR}:/opt/workspace:ro' -v '${CMAKE_BINARY_DIR}:/opt/build' -t -- bash || true" VERBATIM)
endforeach()

execute_process(COMMAND ln -s -r -f "${CMAKE_CURRENT_SOURCE_DIR}/script/debug.sh" . WORKING_DIRECTORY "${CMAKE_BINARY_DIR}")
