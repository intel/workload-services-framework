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
        image: IMAGENAME(Dockerfile.1.postgresql.base.unittest)
        imagePullPolicy: IMAGEPOLICY(Always)
        securityContext:
          privileged: true
        ports:
        - containerPort: 5432
        env:
        - name: NODE_IP
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
        - name: POSTGRES_PASSWORD
          value: "Postgres@123"
      restartPolicy: Never
  backoffLimit: 4