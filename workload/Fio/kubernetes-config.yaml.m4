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
    spec:
      containers:
      - name: benchmark
        image: IMAGENAME(defn(`DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `TEST_TYPE'
          value: "TEST_TYPE"
        - name: `BLOCK_SIZE'
          value: "BLOCK_SIZE"
        - name: `IO_DEPTH'
          value: "IO_DEPTH"
        - name: `FILE_SIZE'
          value: "FILE_SIZE"
        - name: `IO_SIZE'
          value: "IO_SIZE"
        - name: `IO_ENGINE'
          value: "IO_ENGINE"
        - name: `NUM_JOBS'
          value: "NUM_JOBS"
        - name: `CPUS_ALLOWED'
          value: "CPUS_ALLOWED"
        - name: `CPUS_ALLOWED_POLICY'
          value: "CPUS_ALLOWED_POLICY"
        - name: `RUN_TIME'
          value: "RUN_TIME"
        - name: `RWMIX_READ'
          value: "RWMIX_READ"
        - name: `RWMIX_WRITE'
          value: "RWMIX_WRITE"
        - name: `BUFFER_COMPRESS_PERCENTAGE'
          value: "BUFFER_COMPRESS_PERCENTAGE"
        - name: `BUFFER_COMPRESS_CHUNK'
          value: "BUFFER_COMPRESS_CHUNK"
        - name: `FILE_NAME'
          value: "FILE_NAME"
      restartPolicy: Never
  backoffLimit: 4

