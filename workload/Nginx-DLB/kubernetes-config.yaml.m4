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
  name: nginx-cache-server
  labels:
    app: nginx-cache-server
spec:
  template:
    metadata:
      labels:
        app: nginx-cache-server
    spec:
      restartPolicy: Never
ifelse("defn(`USE_KUBERNETES_SERVICE')","false",`dnl
      hostNetwork: true
',)dnl
      containers:
      - name: nginx-cache-server
ifelse(defn(`DLB_ACC'),enable,`dnl
        image: IMAGENAME(Dockerfile.2.CacheServerDLB)
',`dnl
        image: IMAGENAME(Dockerfile.2.CacheServerNative)
')dnl
        imagePullPolicy: IMAGEPOLICY(Always)
        ports:
        - containerPort: 8080
          protocol: TCP
        - containerPort: 8081
          protocol: TCP
        - containerPort: 8082
          protocol: TCP
        env:
        - name: `CACHE_SERVER_CORE'
          value: "defn(`CACHE_SERVER_CORE')"
        - name: `CACHE_SERVER_WORKER'
          value: "defn(`CACHE_SERVER_WORKER')"
        - name: `FILE_SIZE'
          value: "defn(`FILE_SIZE')"
        - name: `USE_KUBERNETES_SERVICE'
          value: "defn(`USE_KUBERNETES_SERVICE')"
        - name: `CACHE_SERVER_IP'
          value: `CACHE_SERVER_IP_REPLACE'
        - name: `CONTENT_SERVER_IP'
          value: `CONTENT_SERVER_IP_REPLACE'
        - name: `DLB_ACC'
          value: "defn(`DLB_ACC')"
        volumeMounts:
        - name: nginx-cache1
          mountPath: /nginx/cache1
          readOnly: false
        - name: nginx-cache2
          mountPath: /nginx/cache2
          readOnly: false
        - name: nginx-cache3
          mountPath: /nginx/cache3
          readOnly: false
        - name: nginx-cache4
          mountPath: /nginx/cache4
          readOnly: false
        - name: nginx-cache5
          mountPath: /nginx/cache5
          readOnly: false
        resources:
          limits:
ifelse(defn(`CACHE_TYPE'),disk,`dnl
            memory: 32Gi
',`dnl
            memory: 300Gi
')dnl
ifelse(defn(`DLB_ACC'),enable,`dnl
            dlb.intel.com/pf: 2
')dnl
          requests:
ifelse(defn(`CACHE_TYPE'),disk,`dnl
            memory: 32Gi
',`dnl
            memory: 300Gi
')dnl
ifelse(defn(`DLB_ACC'),enable,`dnl
            dlb.intel.com/pf: 2
')dnl
      volumes:
ifelse(defn(`CACHE_TYPE'),disk,`dnl
      - name: nginx-cache1
        hostPath:
          path: /nginx/cache1
      - name: nginx-cache2
        hostPath:
          path: /nginx/cache2
      - name: nginx-cache3
        hostPath:
          path: /nginx/cache3
      - name: nginx-cache4
        hostPath:
          path: /nginx/cache4
      - name: nginx-cache5
        hostPath:
          path: /nginx/cache5
',`dnl
      - name: nginx-cache1
        emptyDir:
          medium: Memory
          sizeLimit: 50Gi
      - name: nginx-cache2
        emptyDir:
          medium: Memory
          sizeLimit: 50Gi
      - name: nginx-cache3
        emptyDir:
          medium: Memory
          sizeLimit: 50Gi
      - name: nginx-cache4
        emptyDir:
          medium: Memory
          sizeLimit: 50Gi
      - name: nginx-cache5
        emptyDir:
          medium: Memory
          sizeLimit: 50Gi
')dnl
      nodeSelector:
        HAS-SETUP-NGINX-CACHE: "yes"

---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nginx-cache-server-service
  name: nginx-cache-server-service
spec:
  type: ClusterIP
  selector:
    app: nginx-cache-server
  ports:
  - protocol: TCP
    port: 8080
    targetPort: 8080
    name: cache-server-port1
  - protocol: TCP
    port: 8081
    targetPort: 8081
    name: cache-server-port2
  - protocol: TCP
    port: 8082
    targetPort: 8082
    name: cache-server-port3

---
apiVersion: batch/v1
kind: Job
metadata:
  name: nginx-content-server
  labels:
    app: nginx-content-server
spec:
  template:
    metadata:
      labels:
        app: nginx-content-server
    spec:
      restartPolicy: Never
      nodeSelector:
        VM-GROUP: "worker"
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: VM-GROUP
                operator: NotIn
                values:
                - "client"
              - key: HAS-SETUP-NGINX-CACHE
                operator: NotIn
                values:
                - "yes"
ifelse("defn(`USE_KUBERNETES_SERVICE')","false",`dnl
      hostNetwork: true
',)dnl
      containers:
      - name: nginx-content-server
        image: IMAGENAME(Dockerfile.1.ContentServer)
        imagePullPolicy: IMAGEPOLICY(Always)
        ports:
        - containerPort: 18080
          protocol: TCP
        - containerPort: 18081
          protocol: TCP
        - containerPort: 18082
          protocol: TCP
        env:
        - name: `CONTENT_SERVER_CORE'
          value: "defn(`CONTENT_SERVER_CORE')"
        - name: `CONTENT_SERVER_WORKER'
          value: "defn(`CONTENT_SERVER_WORKER')"
        - name: `FILE_SIZE'
          value: "defn(`FILE_SIZE')"
        - name: `USE_KUBERNETES_SERVICE'
          value: "defn(`USE_KUBERNETES_SERVICE')"
        - name: `CONTENT_SERVER_IP'
          value: `CONTENT_SERVER_IP_REPLACE'

---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: nginx-content-server-service
  name: nginx-content-server-service
spec:
  type: ClusterIP
  selector:
    app: nginx-content-server
  ports:
  - protocol: TCP
    port: 18080
    targetPort: 18080
    name: content-server-port1
  - protocol: TCP
    port: 18081
    targetPort: 18081
    name: content-server-port2
  - protocol: TCP
    port: 18082
    targetPort: 18082
    name: content-server-port3

---
apiVersion: batch/v1
kind: Job
metadata:
  name: wrk-client
  labels:
    app: wrk-client
spec:
  template:
    metadata:
      labels:
        app: wrk-client
    spec:
      restartPolicy: Never
      nodeSelector:
        VM-GROUP: "client"
ifelse("defn(`USE_KUBERNETES_SERVICE')","false",`dnl
      hostNetwork: true
',)dnl
      containers:
      - name: wrk-client
        image: IMAGENAME(Dockerfile.3.WrkClient)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `WRK_CORE'
          value: "defn(`WRK_CORE')"
        - name: `WRK_THREADS'
          value: "defn(`WRK_THREADS')"
        - name: `FILE_SIZE'
          value: "defn(`FILE_SIZE')"
        - name: `CACHE_TYPE'
          value: "defn(`CACHE_TYPE')"
        - name: `WRK_DURATION'
          value: "defn(`WRK_DURATION')"
        - name: `WRK_TEXT_CONNECTIONS'
          value: "defn(`WRK_TEXT_CONNECTIONS')"
        - name: `WRK_AUDIO_CONNECTIONS'
          value: "defn(`WRK_AUDIO_CONNECTIONS')"
        - name: `WRK_VIDEO_CONNECTIONS'
          value: "defn(`WRK_VIDEO_CONNECTIONS')"
        - name: `USE_KUBERNETES_SERVICE'
          value: "defn(`USE_KUBERNETES_SERVICE')"
        - name: `CACHE_SERVER_IP'
          value: `CACHE_SERVER_IP_REPLACE'
