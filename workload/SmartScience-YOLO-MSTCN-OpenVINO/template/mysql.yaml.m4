#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
define(`mysqlService',`
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-service
  labels:
    app: mysql
spec:
  ports:
    - port: 3306
      protocol: TCP
      name: mysql-port
  selector:
    app: mysql


---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: smt-mysql
  labels:
    app: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
        deployPolicy: standalone
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: mysql
        image: IMAGENAME(Dockerfile.2.mysql)
        imagePullPolicy: IMAGEPOLICY(Always)
        securityContext:
          privileged: true
        ports:
        - containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: root
        - name: NODE_IP
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
      nodeSelector:
        HAS-SETUP-STORAGE: "yes"
')