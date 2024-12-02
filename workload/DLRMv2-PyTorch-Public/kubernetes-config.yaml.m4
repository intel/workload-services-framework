#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

apiVersion: batch/v1
kind: Job
metadata:
  name: dlrmv2-pytorch-public
spec:
  template:
    spec:
      containers:
      - name: dlrmv2-pytorch-public
        volumeMounts:
        - mountPath: defn(`K_DATASET_MODEL_PATH_CONTAINER')
          name: dataset
        image: IMAGENAME(defn(`DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: WORKLOAD
          value: "defn(`K_WORKLOAD')"
        - name: TARGET_PLATFORM
          value: "defn(`K_TARGET_PLATFORM')"
        - name: MODE
          value: "defn(`K_MODE')"
        - name: TOPOLOGY
          value: "defn(`K_TOPOLOGY')"
        - name: PRECISION
          value: "defn(`K_PRECISION')"
        - name: FUNCTION
          value: "defn(`K_FUNCTION')"
        - name: DATA_TYPE
          value: "defn(`K_DATA_TYPE')"
        - name: WARMUP_STEPS
          value: "defn(`K_WARMUP_STEPS')"
        - name: BATCH_SIZE
          value: "defn(`K_BATCH_SIZE')"
        - name: STEPS
          value: "defn(`K_STEPS')"
        - name: INSTANCE_MODE
          value: "defn(`K_INSTANCE_MODE')"
        - name: ONEDNN_VERBOSE
          value: "defn(`K_ONEDNN_VERBOSE')"
        - name: NUMA_NODES_USE
          value: "defn(`K_NUMA_NODES_USE')"
        - name: TORCH_TYPE
          value: "defn(`K_TORCH_TYPE')"
        - name: USE_JEMALLOC
          value: "defn(`K_USE_JEMALLOC')"
        - name: USE_TCMALLOC
          value: "defn(`K_USE_TCMALLOC')"
        - name: SRC
          value: "defn(`K_SRC')"
        - name: DATASET_MODEL_PATH_HOST
          value: "defn(`K_DATASET_MODEL_PATH_HOST')"
        - name: DATASET_MODEL_PATH_CONTAINER
          value: "defn(`K_DATASET_MODEL_PATH_CONTAINER')"
        - name: FULL_PLATFORM_NAME
          value: "defn(`K_FULL_PLATFORM_NAME')"
        - name: CORES_PER_INSTANCE
          value: "defn(`K_CORES_PER_INSTANCE')"
        securityContext:
          privileged: true
      NODEAFFINITY(preferred,HAS-SETUP-BKC-AI,"yes")
      NODEAFFINITY(required,HAS-SETUP-DATASET-DLRMV2-PYTORCH,"yes")
      volumes:
      - name: dataset
        hostPath:
          path: defn(`K_DATASET_MODEL_PATH_HOST')
      restartPolicy: Never

