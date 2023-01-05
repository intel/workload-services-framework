
execute_process(COMMAND kubectl get pod RESULT_VARIABLE status_code OUTPUT_QUIET ERROR_QUIET)
if(status_code EQUAL 0)
    set(BACKEND "kubernetes")
    if (NOT REGISTRY)
        message("A valid REGISTRY value is required after Kuberentes v1.24+")
    endif()
else()
    set(BACKEND "docker")
endif()


