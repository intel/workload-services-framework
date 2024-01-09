#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

apiVersion: batch/v1
kind: Job
metadata:
  name: benchmark
spec:
  template:
    metadata:
      labels:
        deployPolicy: standalone
    spec:
      hostNetwork: true
      dnsPolicy: Default 
      containers:
      - name: benchmark
        image: "defn(`REGISTRY')ffmpegmediaxcode-x264-defn(`K_IMAGE_TYPE')defn(`IMAGESUFFIX')defn(`RELEASE')"
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: USECASE
          value: "defn(`K_USECASE')"
        - name: TOOL
          value: "defn(`K_TOOL')"
        - name: ARCH
          value: "defn(`K_ARCH')"
        - name: COMPILER
          value: "defn(`K_COMPILER')"
        - name: MODE
          value: "defn(`K_MODE')"
        - name: NUMACTL
          value: "defn(`K_NUMACTL')"
        - name: CORES_PER_INSTANCE
          value: "defn(`K_CORES_PER_INSTANCE')"
        - name: HT
          value: "defn(`K_HT')"
        - name: CORES_LIST
          value: "defn(`K_CORES_LIST')"
        - name: NUMA_MEM_SET
          value: "defn(`K_NUMA_MEM_SET')"
        - name: VIDEOCLIP
          value: "defn(`K_VIDEOCLIP')"
        - name: CLIP_EXTRACT_DURATION
          value: "defn(`K_CLIP_EXTRACT_DURATION')"
        - name: CLIP_EXTRACT_FRAME
          value: "defn(`K_CLIP_EXTRACT_FRAME')"
        - name: CONFIG_FILE
          value: "defn(`K_CONFIG_FILE')"
        - name: http_proxy
          value: "defn(`K_http_proxy')"
        - name: https_proxy
          value: "defn(`K_https_proxy')"
        - name: HTTP_PROXY
          value: "defn(`K_HTTP_PROXY')"
        - name: HTTPS_PROXY
          value: "defn(`K_HTTPS_PROXY')"
      restartPolicy: Never
  backoffLimit: 4

