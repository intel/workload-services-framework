#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

apiVersion: batch/v1
kind: Job
metadata:
  name: llms-ipex-public
spec:
  template:
    spec:
      dnsPolicy: Default
      containers:
      - name: llms-ipex-public
        volumeMounts:      
ifelse("defn(`K_MODEL_PATH')","",,`dnl
        - mountPath: /root/.cache/huggingface/hub
          name: model-path
')dnl
        - mountPath: /sys
          name: sys-path
        image: IMAGENAME(defn(`DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: http_proxy
          value: "defn(`K_http_proxy')"
        - name: https_proxy
          value: "defn(`K_https_proxy')"
        - name: WORKLOAD
          value: "defn(`K_WORKLOAD')"
        - name: TARGET_PLATFORM
          value: "defn(`K_TARGET_PLATFORM')"
        - name: MODE
          value: "defn(`K_MODE')"
        - name: PRECISION
          value: "defn(`K_PRECISION')"
        - name: FUNCTION
          value: "defn(`K_FUNCTION')"
        - name: DATA_TYPE
          value: "defn(`K_DATA_TYPE')"
        - name: STEPS
          value: "defn(`K_STEPS')"
        - name: NUMA_NODES_USE
          value: "defn(`K_NUMA_NODES_USE')"
        - name: INPUT_TOKENS
          value: "defn(`K_INPUT_TOKENS')"
        - name: OUTPUT_TOKENS
          value: "defn(`K_OUTPUT_TOKENS')"
        - name: GREEDY
          value: "defn(`K_GREEDY')"
        - name: WARMUP_STEPS
          value: "defn(`K_WARMUP_STEPS')"
        - name: BATCH_SIZE
          value: "defn(`K_BATCH_SIZE')"
        - name: MODEL_NAME
          value: "defn(`K_MODEL_NAME')"
        - name: MODEL_PATH
          value: "defn(`K_MODEL_PATH')"
        - name: DATA_PATH
          value: "defn(`K_DATA_PATH')"
        - name: REVISION
          value: "defn(`K_REVISION')"
        - name: USE_IPEX
          value: "defn(`K_USE_IPEX')"
        - name: USE_DEEPSPEED
          value: "defn(`K_USE_DEEPSPEED')"
        - name: ONEDNN_VERBOSE
          value: "defn(`K_ONEDNN_VERBOSE')"
        - name: RANK_USE
          value: "defn(`K_RANK_USE')"
        - name: CORES_PER_INSTANCE
          value: "defn(`K_CORES_PER_INSTANCE')"
        - name: MODEL_SUBPATH
          value: "defn(`K_MODEL_SUBPATH')"
        securityContext:
          privileged: true  
      volumes:       
ifelse("defn(`K_MODEL_PATH')","",,`dnl
      - name: model-path
        hostPath:
          path: defn(`K_MODEL_PATH')
')dnl
      - name: sys-path
        hostPath:
          path: /sys
      - name: dshm
        emptyDir:
          medium: Memory
          sizeLimit: 8Gi
      NODEAFFINITY(preferred,HAS-SETUP-BKC-AI,"yes")
      NODEAFFINITY(preferred,HAS-SETUP-DATASET-defn(`K_MODEL_SUBPATH'),"yes")
      restartPolicy: Never
