
# check prerequisite: m4
execute_process(COMMAND m4 --version RESULT_VARIABLE m4check OUTPUT_QUIET ERROR_QUIET)
if(NOT m4check EQUAL 0)
    message(FATAL_ERROR "Missing m4. Please install GNU m4.")
endif()

# check prerequisite: awk
execute_process(COMMAND awk --version RESULT_VARIABLE awkcheck OUTPUT_QUIET ERROR_QUIET)
if(NOT awkcheck EQUAL 0)
    message(FATAL_ERROR "Missing awk. Please install gawk.")
endif()

# check prerequisites
execute_process(COMMAND bash -c "docker --version | cut -f3 -d' ' | tr -d ," OUTPUT_VARIABLE docker_version OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
if(docker_version VERSION_LESS "20.10.10")
    message(FATAL_ERROR "Outdated docker ${docker_version}. Please install docker 20.10.10 or later.")
endif()

