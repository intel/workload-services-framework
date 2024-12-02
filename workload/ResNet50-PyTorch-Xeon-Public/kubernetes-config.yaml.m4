#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

apiVersion: batch/v1
kind: Job
metadata:
  name: resnet50-pytorch-xeon-public-benchmark
spec:
  template:
    spec:
      containers:
      - name: resnet50-pytorch-xeon-public-benchmark
        image: IMAGENAME(defn(`K_DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        volumeMounts:
        - mountPath: /dev/shm
          name: dshm
        env:
        - name: `WORKLOAD'
          value: "defn(`K_WORKLOAD')"
        - name: `PLATFORM'
          value: "defn(`K_PLATFORM')"
        - name: MODE
          value: "defn(`K_MODE')"
        - name: TOPOLOGY
          value: "defn(`K_TOPOLOGY')"
        - name: FUNCTION
          value: "defn(`K_FUNCTION')"
        - name: PRECISION
          value: "defn(`K_PRECISION')"
        - name: BATCH_SIZE
          value: "defn(`K_BATCH_SIZE')"
        - name: WARMUP_STEPS
          value: "defn(`K_WARMUP_STEPS')"
        - name: STEPS
          value: "defn(`K_STEPS')"
        - name: DATA_TYPE
          value: "defn(`K_DATA_TYPE')"
        - name: CORES_PER_INSTANCE
          value: "defn(`K_CORES_PER_INSTANCE')"
        - name: WEIGHT_SHARING
          value: "defn(`K_WEIGHT_SHARING')"
        - name: CASE_TYPE
          value: "defn(`K_CASE_TYPE')"
        - name: VERBOSE
          value: "defn(`K_VERBOSE')"
        - name: CUSTOMER_ENV
          value: "defn(`K_CUSTOMER_ENV')"
        - name: TRAIN_EPOCH
          value: "defn(`K_TRAIN_EPOCH')"
        - name: DISTRIBUTED
          value: "defn(`K_DISTRIBUTED')"
        - name: CCL_WORKER
          value: "defn(`K_CCL_WORKER')"
        - name: TORCH_TYPE
          value: "defn(`K_TORCH_TYPE')"
      NODEAFFINITY(preferred,HAS-SETUP-BKC-AI,"yes")
      volumes:
      - name: dshm
        emptyDir:
          medium: Memory
          sizeLimit: 8Gi
      restartPolicy: Never
