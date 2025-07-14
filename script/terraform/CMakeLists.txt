
add_custom_target(build_terraform COMMAND bash -c "PLATFORM=X64 IMAGEARCH=linux/amd64 BACKEND=${BACKEND} RELEASE=${RELEASE} REGISTRY=${REGISTRY} ${BACKEND_ENVS} PROJECTROOT='${PROJECT_SOURCE_DIR}' SOURCEROOT='${CMAKE_CURRENT_SOURCE_DIR}' BUILDROOT='${CMAKE_BINARY_DIR}' '${CMAKE_CURRENT_SOURCE_DIR}/build.sh' ${BUILDSH_OPTIONS}")

foreach(cloud aws gcp azure tencent alicloud vsphere oracle)
    add_custom_target(${cloud} COMMAND bash -c "REGISTRY=${REGISTRY} RELEASE=${RELEASE} ${BACKEND_ENVS} PROJECTROOT='${PROJECT_SOURCE_DIR}' SOURCEROOT='${CMAKE_CURRENT_SOURCE_DIR}' BUILDROOT='${CMAKE_BINARY_DIR}' '${CMAKE_CURRENT_SOURCE_DIR}/shell.sh' ${cloud} -v '${CMAKE_CURRENT_SOURCE_DIR}/../csp:/home' -v '${CMAKE_CURRENT_SOURCE_DIR}/../csp:/root' -v '${CMAKE_CURRENT_SOURCE_DIR}:/opt/workspace:ro' -v '${CMAKE_BINARY_DIR}:/opt/build' -a stdin -a stdout -a stderr -i $([ -t 0 ] && echo -t) -- bash || true" VERBATIM)
endforeach()

execute_process(COMMAND ln -s -r -f "${CMAKE_CURRENT_SOURCE_DIR}/script/debug.sh" . WORKING_DIRECTORY "${CMAKE_BINARY_DIR}")
execute_process(COMMAND bash -c "find template/ansible -ipath '*/defaults/*' -name '*.yaml' -exec sed -n -E '/^[a-zA-Z_0-9-][a-zA-Z_0-9-]*:/{/: *[{][}]/{d};/: *\$/{d};/: *(true|false) *(|#.*)\$/{s/^(.*):.*\$/--\\1\\n--no\\1/};s/^([^:]*):.*\$/--\\1/;p}' '{}' \\;" OUTPUT_FILE "${CMAKE_BINARY_DIR}/.ansible_script_options" WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
