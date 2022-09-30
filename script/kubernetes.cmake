
execute_process(COMMAND kubectl get pod RESULT_VARIABLE status_code OUTPUT_QUIET ERROR_QUIET)
if(status_code EQUAL 0)
    set(BACKEND "kubernetes")
else()
    set(BACKEND "docker")
endif()

