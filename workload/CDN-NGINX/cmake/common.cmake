#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
if(NOT BACKEND STREQUAL "docker")

  add_workload("cdn_nginx_original")
  foreach(media "vod" "live")
    foreach(mode "http" "https_sync")
      add_testcase(${workload}_${media}_${mode} "${media}" "${mode}")
    endforeach()
  endforeach()
  foreach(mode "http" "https_sync")
    add_testcase(${workload}_live_${mode}_gated "live" "${mode}" "gated")
  endforeach()

  add_workload("cdn_nginx_qatsw")
  foreach(media "vod" "live")
    add_testcase(${workload}_${media}_https_async "${media}" "https_async")
  endforeach() 
  add_testcase(${workload}_live_https_async_gated "live" "https_async" "gated")
  add_testcase(${workload}_live_https_async_pkm "live" "https_async" "pkm")

endif()
