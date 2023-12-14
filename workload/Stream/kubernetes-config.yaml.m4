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
        image: IMAGENAME(defn(`DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `INSTRUCTION_SET'
          value: "defn(`INSTRUCTION_SET')"
        - name: `NTIMES'
          value: "defn(`NTIMES')"
        - name: `WORKLOAD'
          value: "defn(`WORKLOAD')"
        - name: `CLOUDFLAG'
          value: "defn(`CLOUDFLAG')"
      restartPolicy: Never
