#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

include(config.m4)

ifelse(defn(`STORAGE_MEDIUM'),disk,`dnl
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cache0-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: defn(`DISK_SIZE')
  storageClassName: local-static-storage

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cache1-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: defn(`DISK_SIZE')
  storageClassName: local-static-storage

---
ifelse(defn(`SINGLE_SOCKET'),true,`',`dnl
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cache2-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: defn(`DISK_SIZE')
  storageClassName: local-static-storage

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cache3-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: defn(`DISK_SIZE')
  storageClassName: local-static-storage

---
')dnl
',`')dnl

apiVersion: v1
kind: Service
metadata:
  name: contentserverurl
  labels:
    app: content-server
spec:
  ports:
  - port: 8888
    targetPort: 8888
    protocol: TCP
  selector:
    app: content-server

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: content-server
  labels:
     app: content-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: content-server
  template:
    metadata:
      labels:
        app: content-server
        deployPolicy: server
    spec:
      containers:
      - name: content-server
        image: IMAGENAME(Dockerfile.2.contentserver)
        imagePullPolicy: IMAGEPOLICY(Always)
        ports:
        - containerPort: 8888
        volumeMounts:
        - mountPath: /etc/localtime
          name: timezone
          readOnly: true
      volumes:
      - name: timezone
        hostPath:
          path: /etc/localtime
          type: File
ifelse(defn(`GATED'),gated,`',`dnl
ifelse(defn(`NODE'),3n,`dnl
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            preference:
              matchExpressions:
              - key: HAS-SETUP-DISK-SPEC-1
                operator: DoesNotExist
',`')dnl
')dnl


---

apiVersion: v1
kind: Service
metadata:
  name: originnginxurl
  labels:
    app: origin-nginx
spec:
  ports:
  - port: 18080
    targetPort: 18080
    protocol: TCP
  selector:
    app: origin-nginx

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: origin-nginx
  labels:
     app: origin-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: origin-nginx
  template:
    metadata:
      labels:
        app: origin-nginx
        deployPolicy: server
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: origin-nginx
        image: IMAGENAME(Dockerfile.2.nginx.original)
        imagePullPolicy: IMAGEPOLICY(Always)
        ports:
        - containerPort: 18080
        command: [ "/home/cdn/sbin/nginx", "-c", "/home/cdn/etc/nginx/nginx-origin.conf" ]
        volumeMounts:
        - mountPath: /mnt/content-cache0
          name: content-cache0
        - mountPath: /etc/localtime
          name: timezone
          readOnly: true
      initContainers:
      - name: wait-for-cdn-ready
        image: curlimages/curl:latest
        imagePullPolicy: IMAGEPOLICY(Always)
        command: ["/bin/sh","-c","while [ $(curl -k -sw '%{http_code}' -m 5 'http://contentserverurl:8888' -o /dev/null) -ne 200 ];do echo Waiting...;sleep 1s;done"]
      volumes:
      - name: content-cache0
        emptyDir:
          medium: Memory
          sizeLimit: 10G
      - name: timezone
        hostPath:
          path: /etc/localtime
          type: File
ifelse(defn(`GATED'),gated,`',`dnl
      PODAFFINITY(required,app,content-server)
')dnl


---

apiVersion: v1
kind: Service
metadata:
  name: cachenginxurl
  labels:
    app: cache-nginx
spec:
  ports:
  - port: defn(`HTTPPORT')
    targetPort: defn(`HTTPPORT')
    protocol: TCP
  selector:
    app: cache-nginx

---

apiVersion: apps/v1
kind: Deployment
metadata:
  name: cache-nginx
  labels:
     app: cache-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cache-nginx
  template:
    metadata:
      labels:
        app: cache-nginx
        deployPolicy: server
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: cache-nginx
        image: IMAGENAME(defn(`NGINX_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `WORKLOAD'
          value: "defn(`WORKLOAD')"
        - name: `NODE'
          value: "defn(`NODE')"
        - name: `HTTPMODE'
          value: "defn(`HTTPMODE')"
        - name: `SYNC'
          value: "defn(`SYNC')"
        - name: `GATED'
          value: "defn(`GATED')"
        - name: `QAT_RESOURCE_NUM'
          value: "defn(`QAT_RESOURCE_NUM')"
        - name: `PROTOCOL'
          value: "defn(`PROTOCOL')"
        - name: `CERT'
          value: "defn(`CERT')"
        - name: `CIPHER'
          value: "defn(`CIPHER')"
        - name: `CURVE'
          value: "defn(`CURVE')"
        - name: `NICIP_W2'
          value: "defn(`NICIP_W2')"
        - name: `SINGLE_SOCKET'
          value: "defn(`SINGLE_SOCKET')"
        - name: `CPU_AFFI'
          value: "defn(`CPU_AFFI')"
        - name: `NGINX_WORKERS'
          value: "defn(`NGINX_WORKERS')"
        - name: `NGINX_CPU_LISTS'
          value: "defn(`NGINX_CPU_LISTS')"
ifelse(defn(`STORAGE_MEDIUM'),memory,`dnl
ifelse(index(WORKLOAD,`_qathw'),-1,,`dnl
        resources:
          limits:
            defn(`QAT_RESOURCE_TYPE'): defn(`QAT_RESOURCE_NUM')
            hugepages-2Mi: 8Gi
          requests:
            defn(`QAT_RESOURCE_TYPE'): defn(`QAT_RESOURCE_NUM')
            cpu: 8
            hugepages-2Mi: 8Gi')
',`dnl
ifelse(index(WORKLOAD,`_qathw'),-1,`dnl
        resources:
          limits:
            memory: 12Gi
          requests:
            memory: 10Gi',`dnl
        resources:
          limits:
            defn(`QAT_RESOURCE_TYPE'): defn(`QAT_RESOURCE_NUM')
            hugepages-2Mi: 8Gi
            memory: 12Gi
          requests:
            defn(`QAT_RESOURCE_TYPE'): defn(`QAT_RESOURCE_NUM')
            cpu: 8
            hugepages-2Mi: 8Gi
            memory: 10Gi')
')dnl
        securityContext:
          capabilities:
            add:
            - "CAP_SYS_NICE"
ifelse(index(WORKLOAD,`_qathw'),-1,,`dnl
            - "IPC_LOCK"
')dnl
        ports:
        - containerPort: defn(`HTTPPORT')
        volumeMounts:
        - mountPath: /mnt/cache0
          name: cache0
        - mountPath: /mnt/cache1
          name: cache1
ifelse(defn(`SINGLE_SOCKET'),true,`',`dnl
        - mountPath: /mnt/cache2
          name: cache2
        - mountPath: /mnt/cache3
          name: cache3
')dnl
        - mountPath: /etc/localtime
          name: timezone
          readOnly: true
      initContainers:
      - name: wait-for-cdn-ready
        image: curlimages/curl:latest
        imagePullPolicy: IMAGEPOLICY(Always)
        command: ["/bin/sh","-c","while [ $(curl -k -sw '%{http_code}' -m 5 'http://originnginxurl:18080' -o /dev/null) -ne 200 ];do echo Waiting...;sleep 1s;done"]
      volumes:
      - name: cache0
ifelse(defn(`STORAGE_MEDIUM'),memory,`dnl
        emptyDir:
          medium: Memory
          sizeLimit: defn(`CACHE_SIZE')',`dnl
        persistentVolumeClaim:
          claimName: cache0-claim')
      - name: cache1
ifelse(defn(`STORAGE_MEDIUM'),memory,`dnl
        emptyDir:
          medium: Memory
          sizeLimit: defn(`CACHE_SIZE')',`dnl
        persistentVolumeClaim:
          claimName: cache1-claim')
ifelse(defn(`SINGLE_SOCKET'),true,`',`dnl
      - name: cache2
ifelse(defn(`STORAGE_MEDIUM'),memory,`dnl
        emptyDir:
          medium: Memory
          sizeLimit: defn(`CACHE_SIZE')',`dnl
        persistentVolumeClaim:
          claimName: cache2-claim')
      - name: cache3
ifelse(defn(`STORAGE_MEDIUM'),memory,`dnl
        emptyDir:
          medium: Memory
          sizeLimit: defn(`CACHE_SIZE')',`dnl
        persistentVolumeClaim:
          claimName: cache3-claim')
')dnl
      - name: timezone
        hostPath:
          path: /etc/localtime
          type: File
ifelse(defn(`GATED'),gated,`',`dnl
      nodeSelector:
        HAS-SETUP-DISK-SPEC-1: "yes"
ifelse(defn(`NODE'),3n,`dnl
      PODANTIAFFINITY(required,app,content-server)
',`')dnl
')dnl


ifelse(defn(`GATED'),gated,`dnl
---


apiVersion: batch/v1
kind: Job
metadata:
  name: benchmark
spec:
  template:
    metadata:
      labels:
        deployPolicy: client
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      volumes:
      - name: shared-data
        emptyDir: {}
      containers:
      - name: test1
        image: IMAGENAME(Dockerfile.1.wrk)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
ifdef(`NUSERS',`dnl
        - name: `NUSERS'
          value: "defn(`NUSERS')"
')dnl
ifdef(`NTHREADS',`dnl
        - name: `NTHREADS'
          value: "defn(`NTHREADS')"
')dnl
ifdef(`DURATION',`dnl
        - name: `DURATION'
          value: "defn(`DURATION')"
')dnl
        - name: PORT
          value: "defn(`HTTPPORT')"
        - name: `GATED'
          value: "defn(`GATED')"
        - name: `STORAGE_MEDIUM'
          value: "STORAGE_MEDIUM"
        - name: STATUS_FILE
          value: "status1"
        - name: LOG_FILE
          value: "output1.log"
        - name: `NICIP_W1'
          value: "defn(`NICIP_W1')"
        volumeMounts:
        - name: shared-data
          mountPath: /OUTPUT
      - name: benchmark
        image: IMAGENAME(Dockerfile.1.wrklog)
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
ifdef(`DURATION',`dnl
        - name: `WRKLOG_TIMEOUT'
          value: "defn(`WRKLOG_TIMEOUT')"
')dnl
        volumeMounts:
        - name: shared-data
          mountPath: /OUTPUT
      initContainers:
      - name: wait-for-cdn-ready
        image: curlimages/curl:latest
        imagePullPolicy: IMAGEPOLICY(Always)
        command: ["/bin/sh","-c","while [ $(curl -k -sw \"%{http_code}\" -m 5 \"defn(`HTTPMODE')://cachenginxurl:defn(`HTTPPORT')\" -o /dev/null) -ne 200 ];do echo Waiting...;sleep 1s;done"]
      restartPolicy: Never
')dnl

