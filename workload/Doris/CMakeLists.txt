if(EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/CMakeLists_int.cmake)
include(CMakeLists_int.cmake)
else()
include(CMakeLists_ext.cmake)
endif()

