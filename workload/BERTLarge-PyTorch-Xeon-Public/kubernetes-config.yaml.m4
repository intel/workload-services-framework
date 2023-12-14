#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)
define(K_NNODES)

ifelse(ifdef(K_NNODES, 1, -1), -1, , `ifelse(eval(K_NNODES>1), 1, `dnl
apiVersion: v1
kind: Service
metadata:
  name: headless-svc
spec:
  clusterIP: None
  selector:
    job-name: bertlarge-pytorch-xeon-public-benchmark

---
')')dnl

apiVersion: batch/v1
kind: Job
metadata:
  name: bertlarge-pytorch-xeon-public-benchmark
spec:
  completions: defn(`K_NNODES')
  parallelism: defn(`K_NNODES')
  completionMode: Indexed
  template:
    metadata:
      labels:
        app: benchmark
    spec:
      subdomain: headless-svc
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - benchmark
            topologyKey: "kubernetes.io/hostname"
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            preference:
              matchExpressions:
              - key: HAS-SETUP-BKC-AI
                operator: In
                values:
                - "yes"
      containers:
      - name: bertlarge-pytorch-xeon-public-benchmark
        image: IMAGENAME(defn(`K_DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        volumeMounts:
        - mountPath: /dev/shm
          name: dshm
        env:
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
        - name: STEPS
          value: "defn(`K_STEPS')"
        - name: BATCH_SIZE
          value: "defn(`K_BATCH_SIZE')"
        - name: CORES_PER_INSTANCE
          value: "defn(`K_CORES_PER_INSTANCE')"
        - name: INSTANCE_NUMBER
          value: "defn(`K_INSTANCE_NUMBER')"
        - name: ONEDNN_VERBOSE
          value: "defn(`K_ONEDNN_VERBOSE')"
        - name: ENABLE_PROFILING
          value: "defn(`K_ENABLE_PROFILING')"
        - name: MAX_SEQ_LENGTH
          value: "defn(`K_MAX_SEQ_LENGTH')"
        - name: WARMUP_STEPS
          value: "defn(`K_WARMUP_STEPS')"
        - name: WEIGHT_SHARING
          value: "defn(`K_WEIGHT_SHARING')"
        - name: DISTRIBUTED
          value: "defn(`K_DISTRIBUTED')"
        - name: NNODES
          value: "defn(`K_NNODES')"
        - name: CCL_WORKER_COUNT
          value: "defn(`K_CCL_WORKER_COUNT')"
        - name: CUSTOMER_ENV
          value: "defn(`K_CUSTOMER_ENV')"
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
      volumes:
      - name: dshm
        emptyDir:
          medium: Memory
          sizeLimit: 8Gi
      restartPolicy: Never