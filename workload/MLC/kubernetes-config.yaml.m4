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
        - name: `TEST'
          value: "TEST"
        - name: `WORKLOAD'
          value: "WORKLOAD"
        - name: `DURATION'
          value: "DURATION"
        - name: `ARGS'
          value: "ARGS"
        - name: `HUGEPAGE_MEMORY_NUM'
          value: "defn(`HUGEPAGE_MEMORY_NUM')"
        securityContext:
          privileged: true
        resources:
          limits:
            defn(`HUGEPAGE_KB8_DIRECTIVE'): "defn(`HUGEPAGE_LIMIT')"
          requests:
            cpu: defn(`HUGEPAGE_KB8_CPU_UNITS')
            defn(`HUGEPAGE_KB8_DIRECTIVE'): "defn(`HUGEPAGE_LIMIT')"
      nodeSelector:
ifelse(index(WORKLOAD,`_sgx'),-1,,`dnl
        feature.node.kubernetes.io/cpu-sgx.enabled: "true"
')dnl
      restartPolicy: Never
