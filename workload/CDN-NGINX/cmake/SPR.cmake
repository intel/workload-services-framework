#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(cmake/common.cmake)

if(NOT BACKEND STREQUAL "docker")

  add_workload("cdn_nginx_qathw")
  foreach(media "vod" "live")
    add_testcase(${workload}_${media}_https_async "${media}" "https_async")
  endforeach()

endif()