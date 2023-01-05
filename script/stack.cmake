
include(component)

function(add_stack name)
    add_component_build(stack ${name} ${ARGN})
    set(stack ${component} PARENT_SCOPE)
    set(sut_reqs "${sut_reqs}" PARENT_SCOPE)
endfunction()

function(add_testcase name)
    add_component_testcase(stack ${stack} ${name} ${ARGN})
endfunction()

