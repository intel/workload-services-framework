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
        image: IMAGENAME(wasmscore)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `CONFIG'
          value: "defn(`CONFIG')"
      restartPolicy: Never
  backoffLimit: 4
