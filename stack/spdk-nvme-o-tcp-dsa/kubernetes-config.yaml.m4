#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)


# for spdk nvme/tcp target deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: defn(`BENCH_STACK_NAME')
spec:
  selector:
    matchLabels:
      app: defn(`BENCH_STACK_NAME')
  replicas: 1
  template:
    metadata:
      labels:
        app: defn(`BENCH_STACK_NAME')
        deployPolicy: nvmf-target
    spec:
      containers:
      - name: defn(`BENCH_STACK_NAME')
        image: IMAGENAME(Dockerfile.2.spdk-dsa)
        imagePullPolicy: IMAGEPOLICY(Always)
ifelse("defn(`DEBUG_MODE')","1",`dnl
        command: ["sleep"]
        args: ["infinity"]
',)dnl
        env:
        - name: `TEST_CASE'
          value: "defn(`TEST_CASE')"
        - name: `BENCHMARK_OPTIONS'
          value: "defn(`BENCHMARK_OPTIONS')"
        - name: `CONFIGURATION_OPTIONS'
          value: "defn(`CONFIGURATION_OPTIONS')"
        - name: `DEBUG_MODE'
          value: "defn(`DEBUG_MODE')"
        securityContext:
          privileged: true
        resources:
          limits:
            hugepages-2Mi: defn(`SPDK_HUGEMEM')Mi
          requests:
            cpu: 1
            hugepages-2Mi: defn(`SPDK_HUGEMEM')Mi
        volumeMounts:
        - mountPath: /dev
          name: dev
        - mountPath: /sys
          name: sys
        - mountPath: /lib/modules
          name: modules
      restartPolicy: Always
      hostNetwork: true
      volumes:
      - name: dev
        hostPath:
          path: /dev
          type: Directory
      - name: sys
        hostPath:
          path: /sys
          type: Directory
      - name: modules
        hostPath:
          path: /lib/modules
          type: Directory
      nodeSelector:
        HAS-SETUP-DISK-SPEC-1: "yes"
        HAS-SETUP-HUGEPAGE-2048kB-4096: "yes"
        HAS-SETUP-MODULE-VFIO-PCI: "yes"
        HAS-SETUP-DSA: "yes"
---

# for spdk nvme/tcp initiator deployment and test
apiVersion: batch/v1
kind: Job
metadata:
  name: defn(`BENCH_JOB_NAME')
spec:
  template:
    metadata:
      labels:
        app: defn(`BENCH_JOB_NAME')
        deployPolicy: nvmf-initiator
    spec:
      containers:
      - name: defn(`BENCH_JOB_NAME')
        image: IMAGENAME(Dockerfile.1.functest)
        imagePullPolicy: IMAGEPOLICY(Always)
ifelse("defn(`DEBUG_MODE')","1",`dnl
        command: ["sleep"]
        args: ["infinity"]
',)dnl
        env:
        - name: `TEST_CASE'
          value: "defn(`TEST_CASE')"
        - name: `BENCHMARK_OPTIONS'
          value: "defn(`BENCHMARK_OPTIONS')"
        - name: `CONFIGURATION_OPTIONS'
          value: "defn(`CONFIGURATION_OPTIONS')"
        - name: `DEBUG_MODE'
          value: "defn(`DEBUG_MODE')"
        securityContext:
          privileged: true
        volumeMounts:
        - mountPath: /dev
          name: dev
        - mountPath: /sys
          name: sys
        - mountPath: /lib/modules
          name: modules
      restartPolicy: Never
      hostNetwork: true
      volumes:
      - name: dev
        hostPath:
          path: /dev
          type: Directory
      - name: sys
        hostPath:
          path: /sys
          type: Directory
      - name: modules
        hostPath:
          path: /lib/modules
          type: Directory
      initContainers:
      - name: wait-for-target-ready
        image: curlimages/curl:latest
        imagePullPolicy: IMAGEPOLICY(Always)
        command: ["/bin/sh","-c","sleep 100s"]
      restartPolicy: Never
      nodeSelector:
        HAS-SETUP-NVME-TCP: "yes"
  backoffLimit: 4
