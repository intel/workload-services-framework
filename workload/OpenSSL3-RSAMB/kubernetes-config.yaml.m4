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
        image: IMAGENAME(Dockerfile.2.patsubst(WORKLOAD,`.*_'))
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
      containers:
      - name: benchmark
        image: IMAGENAME(Dockerfile.2.patsubst(WORKLOAD,`.*_'))
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `CONFIG'
          value: "CONFIG"
        securityContext:
          privileged: true
ifelse(index(WORKLOAD,`_qathw'),-1,,`dnl
        resources:
          limits:
            hugepages-2Mi: 8Gi
          requests:
            cpu: 8
            hugepages-2Mi: 8Gi
        volumeMounts:
        - mountPath: /dev
          name: devfs
      nodeSelector:
        HAS-SETUP-QAT-V200: "yes"
        HAS-SETUP-HUGEPAGE-2048kB-4096: "yes"
      volumes:
      - name: devfs
        hostPath:
          path: /dev
          type: Directory
')dnl
      restartPolicy: Never
  backoffLimit: 4
