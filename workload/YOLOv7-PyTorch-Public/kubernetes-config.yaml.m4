#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

apiVersion: batch/v1
kind: Job
metadata:
  name: yolov7-pytorch-public
spec:
  template:
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: yolov7-pytorch-public
        volumeMounts:
        - mountPath: /dev/shm
          name: dshm
        image: IMAGENAME(defn(`DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: MODE
          value: "defn(`K_MODE')"
        - name: PRECISION
          value: "defn(`K_PRECISION')"
        - name: BATCH_SIZE
          value: "defn(`K_BATCH_SIZE')"
        - name: CORES_PER_INSTANCE
          value: "defn(`K_CORES_PER_INSTANCE')"
        - name: ONEDNN_VERBOSE
          value: "defn(`K_ONEDNN_VERBOSE')"
        - name: WARMUP_STEPS
          value: "defn(`K_WARMUP_STEPS')"
        - name: STEPS
          value: "defn(`K_STEPS')"
        - name: TORCH_TYPE
          value: "defn(`K_TORCH_TYPE')"
        - name: HARDWARE
          value: "defn(`K_HARDWARE')"
        securityContext:
          privileged: true  
      NODEAFFINITY(preferred,HAS-SETUP-PVC,"yes")
      volumes:
      - name: dshm
        emptyDir:
          medium: Memory
          sizeLimit: 4Gi
      restartPolicy: Never