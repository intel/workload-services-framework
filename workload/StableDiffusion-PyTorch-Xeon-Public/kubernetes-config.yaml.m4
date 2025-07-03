#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

apiVersion: batch/v1
kind: Job
metadata:
  name: diffusions-pytorch-public
spec:
  template:
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: diffusions-pytorch-public
        volumeMounts:
ifelse("defn(`K_MODEL_PATH')","",,`dnl
        - mountPath: /root/.cache/huggingface/hub
          name: model-path
')dnl
        - mountPath: /dev/shm
          name: dshm
        image: IMAGENAME(defn(`DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: FUNCTION
          value: "defn(`K_FUNCTION')"
        - name: MODE
          value: "defn(`K_MODE')"
        - name: PRECISION
          value: "defn(`K_PRECISION')"
        - name: DATA_TYPE
          value: "defn(`K_DATA_TYPE')"
        - name: CASE_TYPE
          value: "defn(`K_CASE_TYPE')"
        - name: CORES_PER_INSTANCE
          value: "defn(`K_CORES_PER_INSTANCE')"
        - name: NUMA_NODES_USE
          value: "defn(`K_NUMA_NODES_USE')"
        - name: ONEDNN_VERBOSE
          value: "defn(`K_ONEDNN_VERBOSE')"
        - name: WARMUP_STEPS
          value: "defn(`K_WARMUP_STEPS')"
        - name: STEPS
          value: "defn(`K_STEPS')"
        - name: USE_JEMALLOC
          value: "defn(`K_USE_JEMALLOC')"
        - name: USE_TCMALLOC
          value: "defn(`K_USE_TCMALLOC')"
        - name: MODEL_NAME
          value: "defn(`K_MODEL_NAME')"
        - name: MODEL_PATH
          value: "defn(`K_MODEL_PATH')"
        - name: TORCH_TYPE
          value: "defn(`K_TORCH_TYPE')"
        - name: BATCH_SIZE
          value: "defn(`K_BATCH_SIZE')"
        - name: IMAGE_WIDTH
          value: "defn(`K_IMAGE_WIDTH')"
        - name: IMAGE_HEIGHT
          value: "defn(`K_IMAGE_HEIGHT')"
        - name: DNOISE_STEPS
          value: "defn(`K_DNOISE_STEPS')"
        - name: MODEL_SUBPATH
          value: "defn(`K_MODEL_SUBPATH')"
        securityContext:
          privileged: true
      volumes:
ifelse("defn(`K_MODEL_PATH')","",,`dnl
      - name: model-path
        hostPath:
          path: "defn(`K_MODEL_PATH')"
')dnl
      - name: dshm
        emptyDir:
          medium: Memory
          sizeLimit: 8Gi
      NODEAFFINITY(preferred,HAS-SETUP-DATASET-defn(`K_MODEL_SUBPATH'),"yes")
      restartPolicy: Never
