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
    spec:
      containers:
      - name: benchmark
        image: IMAGENAME(Dockerfile.1.TCSUFFIX)
        imagePullPolicy: IMAGEPOLICY(Always)
      restartPolicy: Never
ifelse(index(STACK,`qathw'),-1,,`dnl
      nodeSelector: 
        HAS-SETUP-QAT: "yes"
')dnl
  backoffLimit: 4

