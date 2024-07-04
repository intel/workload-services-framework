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
      # hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: benchmark
        image: IMAGENAME(Dockerfile.1.mysql.oh.unittest)
        imagePullPolicy: IMAGEPOLICY(Always)
        securityContext:
          privileged: true
        ports:
        - containerPort: 3306
        env:
        - name: NODE_IP
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
        - name: MYSQL_ROOT_PASSWORD
          value: "Mysql@123"
      restartPolicy: Never
  backoffLimit: 4
