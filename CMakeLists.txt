
cmake_minimum_required (VERSION 2.8...3.24)

Project(workloads NONE)
set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/script/")
include(prerequisite)

add_custom_target(bom)
add_custom_target(kpi)
enable_testing()

if(NOT DEFINED PLATFORM)
    execute_process(COMMAND bash -c "head -n 1 '${CMAKE_SOURCE_DIR}/workload/platforms'" OUTPUT_VARIABLE PLATFORM OUTPUT_STRIP_TRAILING_WHITESPACE)
else()
    execute_process(COMMAND bash -c "grep -E '^${PLATFORM}$' '${CMAKE_SOURCE_DIR}/workload/platforms' | head -n 1" OUTPUT_VARIABLE platform OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(NOT platform)
        message(FATAL_ERROR "Platform ${PLATFORM} not recognized!")
    endif()
    set(PLATFORM "${platform}")
endif()

include(registry OPTIONAL)
execute_process(COMMAND bash -c "GIT_ASKPASS=echo git fetch --tags > /dev/null && git tag" TIMEOUT 5 OUTPUT_VARIABLE tmp RESULT_VARIABLE status OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
if (RELEASE MATCHES "^:?v?[0-9]+[.][0-9]+$")
    string(REPLACE ":" "" release1 "${RELEASE}")
    if ((status EQUAL 0) AND (tmp MATCHES "${release1}"))
        if((NOT DEFINED REGISTRY) OR (NOT REGISTRY))
            set(REGISTRY "${DEFAULT_REGISTRY}")
        elseif((NOT REGISTRY STREQUAL "${DEFAULT_REGISTRY}") AND DEFAULT_REGISTRY)
            message(WARNING "Issue 'cmake -DREGISTRY=${DEFAULT_REGISTRY} ..' to use the official ${RELEASE} images.")
        endif()
    endif()
else ()
    string(REGEX REPLACE ".*\nv?" "" tmp "${tmp}")
    if (tmp AND (status EQUAL 0))
        message("")
        message("*************************************************************")
        message("")
        message("Release ${tmp} detected. Switch to release ${tmp} as follows:")
        message("")
        message("git checkout ${tmp}")
        message("cmake -DRELEASE=v${tmp} ..")
        message("")
        message("*************************************************************")
        message("")
    else()
        message("")
        message("****************************************************************************")
        message("")
        message("Failed to detect official releases.")
        message("Switch to any release as follows:")
        message("")
        message("git checkout <VERSION>")
        message("cmake -DREGISTRY=${DEFAULT_REGISTRY} -DRELEASE=v<VERSION> ..")
        message("")
        message("****************************************************************************")
    endif()
endif()

if (NOT ${REGISTRY} MATCHES "/$")
    set(REGISTRY "${REGISTRY}/")
endif()

set(ENABLE_BUILD ON)
if (REGISTRY STREQUAL "${DEFAULT_REGISTRY}/")
    execute_process(COMMAND bash -c "grep -q -F $(echo ${REGISTRY} | cut -f1 -d/) ~/.docker/config.json" RESULT_VARIABLE disable_build OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
    if(disable_build)
        set(ENABLE_BUILD OFF)
    endif()
endif()

if (NOT DEFINED TIMEOUT)
    set(TIMEOUT "28800,600")
endif()

if (NOT DEFINED RELEASE)
    set(RELEASE ":latest")
elseif (NOT ${RELEASE} MATCHES "^:")
    set(RELEASE ":${RELEASE}")
endif()
string(TOLOWER "${RELEASE}" RELEASE)

if (NOT DEFINED BACKEND)
    set(BACKEND "terraform")
endif()
include(${BACKEND} OPTIONAL)
set(IMAGEARCH "linux/amd64")
include(multi-arch OPTIONAL)

foreach(subdir image stack workload dist)
    if(EXISTS "${PROJECT_SOURCE_DIR}/${subdir}")
        add_subdirectory(${subdir})
    endif()
endforeach()

message("")
message("-- Setting: PLATFORM=${PLATFORM}, ARCH=${IMAGEARCH}")
if(NOT DEFINED REGISTRY_AUTH)
    message("-- Setting: REGISTRY=${REGISTRY}")
else()
    message("-- Setting: REGISTRY=${REGISTRY}, AUTH=${REGISTRY_AUTH}")
endif()
message("-- Setting: RELEASE=${RELEASE}")
message("-- Setting: TIMEOUT=${TIMEOUT}")
if(ACCEPT_LICENSE)
    message("-- Setting: ACCEPT_LICENSE=${ACCEPT_LICENSE}")
endif()
message("-- Setting: BENCHMARK=${BENCHMARK}")
message("-- Setting: BACKEND=${BACKEND}")
if(COMMAND show_backend_settings)
    show_backend_settings()
endif()
message("")
if(NOT ENABLE_BUILD)
    STRING(ASCII 27 esc)
    message("${esc}[32mINFO:${esc}[m Build is disabled as ${DEFAULT_REGISTRY} is readonly.")
    message("")
endif()

execute_process(COMMAND bash -c "ln -s -r -f '${PROJECT_SOURCE_DIR}'/script/benchmark/*.sh ." WORKING_DIRECTORY "${CMAKE_BINARY_DIR}")

