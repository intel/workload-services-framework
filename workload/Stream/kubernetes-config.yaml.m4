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
        - name: `INSTRUCTION_SET'
          value: "defn(`INSTRUCTION_SET')"
        - name: `NTIMES'
          value: "defn(`NTIMES')"
        - name: `STREAM_ARRAY_SIZE'
          value: "defn(`STREAM_ARRAY_SIZE')"
        - name: `WORKLOAD'
          value: "defn(`WORKLOAD')"
        - name: `CLOUDFLAG'
          value: "defn(`CLOUDFLAG')"
        - name: `NO_OF_STREAM_ITERATIONS'
          value: "defn(`NO_OF_STREAM_ITERATIONS')"
        - name: `THP_ENABLE'
          value: "defn(`THP_ENABLE')"
        securityContext:
ifelse("defn(`ENABLE_PRIVILEGED_MODE')","true",`dnl
          privileged: true
',`dnl
          privileged: false
')dnl
      restartPolicy: Never
