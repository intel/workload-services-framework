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
        image: IMAGENAME(Dockerfile)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: INFERENCE_FRAMEWORK
          value: "defn(`K_INFERENCE_FRAMEWORK')"
        - name: INFERENCE_DEVICE
          value: "defn(`K_INFERENCE_DEVICE')"
        - name: INPUT_VIDEO
          value: "defn(`K_INPUT_VIDEO')"
      restartPolicy: Never
