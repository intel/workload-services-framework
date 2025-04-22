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
      hostNetwork: true
      dnsPolicy: Default 
      containers:
      - name: benchmark
        image: IMAGENAME(VERSION/Dockerfile.1.VERSION.ffmpeg.OPTIONS.unittest)
        imagePullPolicy: IMAGEPOLICY(Always)
      restartPolicy: Never
  backoffLimit: 4

