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
      containers:
      - name: benchmark
        image: IMAGENAME(Dockerfile)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: WORKLOAD
          value: "defn(`K_WORKLOAD')"
        - name: FRAMEWORK
          value: "defn(`K_FRAMEWORK')"
        - name: PRECISION
          value: "defn(`K_PRECISION')"
        - name: ISA
          value: "defn(`K_ISA')"
        - name: MODE
          value: "defn(`K_MODE')"
        - name: CORES
          value: "defn(`K_CORES')"
        - name: TAG
          value: "defn(`K_TAG')"
      restartPolicy: Never