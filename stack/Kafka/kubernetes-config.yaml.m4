#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)
---

apiVersion: batch/v1
kind: Job
metadata:
  name: kafka-version-check
spec:
  template:
    spec:
      containers:
      - name: kafka-version-check
        image: IMAGENAME(Dockerfile.1.kafka.unittest)
      restartPolicy: Never