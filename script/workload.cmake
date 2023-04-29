
include(component)

function(add_workload name)
    add_component_build(workload ${name} ${ARGN})
    set(workload ${component} PARENT_SCOPE)
    set(sut_reqs "${sut_reqs}" PARENT_SCOPE)
endfunction()

function(add_testcase name)    
    add_component_testcase(workload ${workload} ${name} ${ARGN})    
endfunction()