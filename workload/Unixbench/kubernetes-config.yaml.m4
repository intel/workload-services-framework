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
        image: IMAGENAME(Dockerfile)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
          - name: K_ITERATION_COUNT
            value: "ITERATION_COUNT"
          - name: K_PARALLEL_COUNT
            value: "PARALLEL_COUNT"
          - name: K_NUMACTL_OPTIONS
            value: "NUMACTL_OPTIONS"
          - name: K_TEST_CASES
            value: "TEST_CASES"
          - name: NUMA_ENABLE
            value: "NUMA_ENABLE"
      restartPolicy: Never
