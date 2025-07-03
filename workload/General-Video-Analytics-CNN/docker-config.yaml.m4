#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)
worker-0:
- image: IMAGENAME(Dockerfile.1.dlstreamer`'defn(`K_INTERNAL').m4)
  options:
  - --privileged
  - --network=host
  - -e TESTCASE=defn(`K_TESTCASE')
  - -e TestName=defn(`K_TestName')
  - -e TestTimeout=defn(`K_TestTimeout')
  - -e G_NumofVAStreams=defn(`K_G_NumofVAStreams')
  - -e G_Bind=defn(`K_G_Bind')
  - -e G_CPU_Bind=defn(`K_G_CPU_Bind')
  - -e SCALING_GOVERNOR=defn(`K_SCALING_GOVERNOR')
  - --device /dev/dri:/dev/dri
  export-logs: true
