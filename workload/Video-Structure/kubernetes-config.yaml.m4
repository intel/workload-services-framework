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
        image: IMAGENAME(defn(`DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        volumeMounts:
        - name: dev-dri
          mountPath: /dev/dri
        securityContext:
          privileged: true
        env:
        - name: WORKLOAD
          value: "defn(`K_WORKLOAD')"
        - name: CHECK_PKM
          value: "defn(`K_CHECK_PKM')"
        - name: CHECK_GATED
          value: "defn(`K_CHECK_GATED')"
        - name: COREFORSTREAMS
          value: "defn(`K_COREFORSTREAMS')"
        - name: STREAMNUMBER
          value: "defn(`K_STREAMNUMBER')"
        - name: DETECTION_MODEL
          value: "defn(`K_DETECTION_MODEL')"
        - name: DETECTION_INFERENCE_INTERVAL
          value: "defn(`K_DETECTION_INFERENCE_INTERVAL')"
        - name: DETECTION_THRESHOLD
          value: "defn(`K_DETECTION_THRESHOLD')"
        - name: CLASSIFICATION_INFERECE_INTERVAL
          value: "defn(`K_CLASSIFICATION_INFERECE_INTERVAL')"
        - name: CLASSIFICATION_OBJECT
          value: "defn(`K_CLASSIFICATION_OBJECT')"
        - name: DECODER_BACKEND
          value: "defn(`K_DECODER_BACKEND')"
        - name: MODEL_BACKEND
          value: "defn(`K_MODEL_BACKEND')"
      volumes:
      - name: dev-dri
        hostPath:
          path: /dev/dri
          type: Directory
      restartPolicy: Never
