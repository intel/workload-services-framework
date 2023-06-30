#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
define(`rtspService',`
---
apiVersion: v1
kind: Service
metadata:
  name: rtsp-service
  labels:
    app: rtsp
spec:
  ports:
    - port: 8554
      protocol: TCP
      name: rtsp-port-1
    - port: 1935
      protocol: TCP
      name: rtsp-port-2
    - port: 8888
      protocol: TCP
      name: rtsp-port-3
  selector:
    app: rtsp
---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: smt-rtsp
  labels:
    app: rtsp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rtsp
  template:
    metadata:
      labels:
        app: rtsp
        deployPolicy: standalone
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: rtsp
        image: IMAGENAME(Dockerfile.4.rtsp)
        imagePullPolicy: IMAGEPOLICY(Always)
        securityContext:
          privileged: true
        ports:
        - containerPort: 8554
        - containerPort: 1935 
        - containerPort: 8888
        env:
        - name: NODE_IP
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
      nodeSelector:
        HAS-SETUP-STORAGE: "yes"
')