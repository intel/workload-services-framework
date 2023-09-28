#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

apiVersion: batch/v1
kind: Job
metadata:
  name: speccpu-2017-benchmark
  labels:
    application: speccpu-2017
spec:
  template:
    spec:
      containers:
      - name: speccpu-2017-benchmark
        image: IMAGENAME(defn(`DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `RUNMODE'
          value: "RUNMODE"
        - name: `BENCHMARK'
          value: "BENCHMARK"
        - name: `COPIES'
          value: "COPIES"
        - name: `TUNE'
          value: "TUNE"
        - name: `PLATFORM1'
          value: "PLATFORM1"
        - name: `NUMA'
          value: "NUMA"
        - name: `RELEASE1'
          value: "RELEASE1"
        - name: `COMPILER'
          value: "COMPILER"
        - name: `PA_IP'
          value: "PA_IP"
        - name: `PA_PORT'
          value: "PA_PORT"
        - name: `ARGS'
          value: "ARGS"
        - name: `ITERATION'
          value: "ITERATION"
        - name: `CPU_NODE'
          value: "CPU_NODE"
        securityContext:
          privileged: true
      restartPolicy: Never
  backoffLimit: 4

