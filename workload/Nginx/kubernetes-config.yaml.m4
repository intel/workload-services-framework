#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

---

apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: nginx-server
  name: nginx-server-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-server
  template:
    metadata:
      labels:
        app: nginx-server
        deployPolicy: server
    spec:
ifelse(defn(`NODE'),1,`dnl
',`dnl
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: VM-GROUP
                operator: In
                values:
                - "worker"
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - client
                - client2
            topologyKey: "kubernetes.io/hostname"
')dnl
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: nginx-server
        image: IMAGENAME(defn(`NGINX_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        ports:
        - containerPort: defn(`PORT')
        env:
        - name: `WORKLOAD'
          value: "defn(`WORKLOAD')"
        - name: `MODE'
          value: "defn(`MODE')"
        - name: `NODE'
          value: "defn(`NODE')"
        - name: `PORT'
          value: "defn(`PORT')"
        - name: `QATACCL'
          value: "defn(`QATACCL')"
        - name: `PROTOCOL'
          value: "defn(`PROTOCOL')"
        - name: `CERT'
          value: "defn(`CERT')"
        - name: `NGINX_CPU_LISTS'
          value: "defn(`NGINX_CPU_LISTS')"
        - name: `CIPHER'
          value: "defn(`CIPHER')"
        - name: `NGINX_WORKERS'
          value: "defn(`NGINX_WORKERS')"
        - name: `MAX_CORE_WORKER_CLIENT'
          value: "defn(`MAX_CORE_WORKER_CLIENT')"
        - name: `CURVE'
          value: "defn(`CURVE')"
        - name: `QAT_POLICY'
          value: "defn(`QAT_POLICY')"
        - name: POD_OWN_IP_ADDRESS
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: NODE_OWN_IP_ADDRESS
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
ifelse(index(WORKLOAD,`_qathw'),-1,,`dnl
        securityContext:
           capabilities:
             add:
              ["IPC_LOCK"]
        resources:
          limits:
            defn(`QAT_RESOURCE_TYPE'): defn(`QAT_RESOURCE_NUM')
            hugepages-2Mi: 8Gi
          requests:
            defn(`QAT_RESOURCE_TYPE'): defn(`QAT_RESOURCE_NUM')
            cpu: 8
            hugepages-2Mi: 8Gi
')dnl
ifelse(index(WORKLOAD,`_sgx'),-1,,`dnl
        securityContext:
          privileged: true
')dnl
      nodeSelector: 
ifelse(index(WORKLOAD,`_sgx'),-1,,`dnl
        feature.node.kubernetes.io/cpu-sgx.enabled: "true"
')dnl
ifelse(index(WORKLOAD,`_qathw'),-1,,`dnl
        HAS-SETUP-QAT-V200: "yes"
        HAS-SETUP-HUGEPAGE-2048kB-4096: "yes"
')dnl

---

apiVersion: v1
kind: Service
metadata:
  labels:
    app: defn(`NGINX_SERVICE_NAME')
  name: defn(`NGINX_SERVICE_NAME')
spec:
  selector:
    app: nginx-server
  ports:
  - protocol: TCP
    port: defn(`PORT')
    targetPort: defn(`PORT')

---

apiVersion: batch/v1
kind: Job
metadata:
  name: client
  labels:
    application: "client"
spec:
  template:
    metadata:
      labels:
        app: client
    spec:
      affinity:
ifelse(defn(`NODE'),1,`dnl
        podAffinity:
',`dnl
        podAntiAffinity:
')dnl
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - nginx-server
ifelse(defn(`NODE'),3,`dnl
                - client2
',`dnl
')dnl
            topologyKey: "kubernetes.io/hostname"
ifelse(defn(`NODE'),1,`dnl
',`dnl
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: VM-GROUP
                operator: In
                values:
                - "client"
')dnl
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: client
ifelse(defn(`MODE'),https,`dnl
ifelse(defn(`CLIENT_TYPE'),openssl,`dnl
        image: IMAGENAME(Dockerfile.7.openssl.K_ARCH)
',`dnl
ifelse(defn(`CLIENT_TYPE'),ab,`dnl
        image: IMAGENAME(Dockerfile.9.ab.K_ARCH)
',`dnl
        image: IMAGENAME(Dockerfile.8.wrk.K_ARCH)
')dnl
')dnl
',`dnl
        image: IMAGENAME(Dockerfile.9.ab.K_ARCH)
')dnl
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `NGINX_SERVICE_NAME'
          value: "defn(`NGINX_SERVICE_NAME')"
        - name: `NODE'
          value: "defn(`NODE')"
        - name: `MODE'
          value: "defn(`MODE')"
        - name: `PORT'
          value: "defn(`PORT')"
        - name: `PROTOCOL'
          value: "defn(`PROTOCOL')"
        - name: `CIPHER'
          value: "defn(`CIPHER')"
        - name: `REQUESTS'
          value: "defn(`REQUESTS')"
        - name: `CONCURRENCY'
          value: "defn(`CONCURRENCY')"
        - name: `CLIENT_CPU_NUM'
          value: "defn(`CLIENT_CPU_NUM')"
        - name: `CLIENT_CPU_LISTS'
          value: "defn(`CLIENT_CPU_LISTS')"
        - name: `NGINX_WORKERS'
          value: "defn(`NGINX_WORKERS')"
        - name: `CLIENT_ID'
          value: "1"
        - name: `OPENSSL_CLIENTS'
          value: "defn(`OPENSSL_CLIENTS')"
        - name: `GETFILE'
          value: "defn(`GETFILE')"
        - name: `CLIENT_TYPE'
          value: "defn(`CLIENT_TYPE')"
        - name: `SWEEPING'
          value: "defn(`SWEEPING')"
        - name: `PACE'
          value: "defn(`PACE')"
        - name: `MAX_CORE_WORKER_CLIENT'
          value: "defn(`MAX_CORE_WORKER_CLIENT')"
      restartPolicy: Never
  backoffLimit: 5


ifelse(defn(`NODE'),3,`dnl

---

apiVersion: v1
kind: Service
metadata:
  labels:
    app: client2-service
  name: client2-service
spec:
  selector:
    app: client2
  ports:
  - protocol: TCP
    port: 999
    targetPort: 999

---

apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: client2
  name: client2-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: client2
  template:
    metadata:
      labels:
        app: client2
        deployPolicy: server
    spec:
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: VM-GROUP
                operator: In
                values:
                - "client"
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - nginx-server
                - client
            topologyKey: "kubernetes.io/hostname"
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: client2
ifelse(defn(`MODE'),https,`dnl
ifelse(defn(`CLIENT_TYPE'),openssl,`dnl
        image: IMAGENAME(Dockerfile.7.openssl.K_ARCH)
',`dnl
ifelse(defn(`CLIENT_TYPE'),ab,`dnl
        image: IMAGENAME(Dockerfile.9.ab.K_ARCH)
',`dnl
        image: IMAGENAME(Dockerfile.8.wrk.K_ARCH)
')dnl
')dnl
',`dnl
        image: IMAGENAME(Dockerfile.9.ab.K_ARCH)
')dnl
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `NGINX_SERVICE_NAME'
          value: "defn(`NGINX_SERVICE_NAME')"
        - name: `NODE'
          value: "defn(`NODE')"
        - name: `MODE'
          value: "defn(`MODE')"
        - name: `PORT'
          value: "defn(`PORT')"
        - name: `PROTOCOL'
          value: "defn(`PROTOCOL')"
        - name: `CIPHER'
          value: "defn(`CIPHER')"
        - name: `REQUESTS'
          value: "defn(`REQUESTS')"
        - name: `CONCURRENCY'
          value: "defn(`CONCURRENCY')"
        - name: `CLIENT_CPU_NUM'
          value: "defn(`CLIENT_CPU_NUM')"
        - name: `CLIENT_CPU_LISTS'
          value: "defn(`CLIENT_CPU_LISTS')"
        - name: `NGINX_WORKERS'
          value: "defn(`NGINX_WORKERS')"
        - name: `CLIENT_ID'
          value: "2"
        - name: `OPENSSL_CLIENTS'
          value: "defn(`OPENSSL_CLIENTS')"
        - name: `GETFILE'
          value: "defn(`GETFILE')"
        - name: `CLIENT_TYPE'
          value: "defn(`CLIENT_TYPE')"
        - name: `SWEEPING'
          value: "defn(`SWEEPING')"
        - name: `PACE'
          value: "defn(`PACE')"
        - name: `MAX_CORE_WORKER_CLIENT'
          value: "defn(`MAX_CORE_WORKER_CLIENT')"
',`dnl
')dnl
