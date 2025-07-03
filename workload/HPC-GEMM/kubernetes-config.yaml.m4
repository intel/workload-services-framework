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
        app: benchmark
    spec:
      containers:
      - name: benchmark
        image: IMAGENAME(defn(`K_DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `MATH_LIB'
          value: "defn(`K_MATH_LIB')"
        - name: `FLOAT_TYPE'
          value: "defn(`K_FLOAT_TYPE')"
        - name: `MATRIX_SIZE'
          value: "defn(`K_MATRIX_SIZE')"
        - name: `OMP_NUM_THREADS'
          value: "defn(`K_OMP_NUM_THREADS')"
        securityContext:
          privileged: true
      restartPolicy: Never
