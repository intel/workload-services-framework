
file(GLOB wdirs "*")
foreach(dir ${wdirs})
    if(EXISTS ${dir}/CMakeLists.txt)
        add_subdirectory(${dir})
    endif()
endforeach()

