#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: ceph-spdk-vhost-daemon
  namespace: defn(`ROOK_CEPH_STORAGE_NS')
  labels:
    app: ceph-spdk-vhost-daemon
spec:
  selector:
    matchLabels:
      app: ceph-spdk-vhost-daemon
  template:
    metadata:
      labels:
        app: ceph-spdk-vhost-daemon
    spec:
      dnsPolicy: ClusterFirstWithHostNet
      containers:
        - name: ceph-spdk-vhost-daemon
          image: defn(`DOCKER_IMAGE_VHOST')
          #command: ["/bin/bash"]
          #args: ["-m", "-c", "/usr/local/bin/toolbox.sh"]
ifelse("defn(`DEBUG_MODE')","3",`dnl
          command: ["sleep"]
          args: ["infinity"]
',)dnl
          imagePullPolicy: Always
          tty: true
          env:
            - name: `VHOST_CPU_NUM'
              value: "defn(`VHOST_CPU_NUM')"
            - name: `CHECK_CEPH_STATUS'
              value: "defn(`CHECK_CEPH_STATUS')"
            - name: MY_POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: MY_POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
            - name: ROOK_CEPH_USERNAME
              valueFrom:
                secretKeyRef:
                  name: rook-ceph-mon
                  key: ceph-username
            - name: ROOK_CEPH_SECRET
              valueFrom:
                secretKeyRef:
                  name: rook-ceph-mon
                  key: ceph-secret
          securityContext:
            privileged: true
            runAsUser: 0
            capabilities:
              add:
                - ALL
          resources:
            limits:
              cpu: defn(`SPDK_CPU_NUM')
              hugepages-2Mi: defn(`SPDK_HUGEMEM')
              memory: defn(`SPDK_HUGEMEM')
            requests:
              cpu: defn(`SPDK_CPU_NUM')
              hugepages-2Mi: defn(`SPDK_HUGEMEM')
              memory: defn(`SPDK_HUGEMEM')
          volumeMounts:
            - mountPath: /var/tmp
              name: tmp
            - mountPath: /sys
              name: sys
            - mountPath: /proc
              name: proc
            - mountPath: /dev
              name: dev
            - mountPath: /dev/shm
              name: devshm
            - mountPath: /sys/bus
              name: sysbus
            - mountPath: /lib/modules
              name: libmodules
            - name: mon-endpoint-volume
              mountPath: /etc/rook
      #restartPolicy: Never
      # if hostNetwork: false, the "rbd map" command hangs, see https://github.com/rook/rook/issues/2021
      hostNetwork: true
      volumes:
        - name: tmp
          hostPath:
            path: /var/tmp
            type: Directory
        - name: sys
          hostPath:
            path: /sys
            type: Directory
        - name: proc
          hostPath:
            path: /proc
            type: Directory
        - name: dev
          hostPath:
            path: /dev
        - name: devshm
          hostPath:
            path: /dev/shm
            type: Directory
        - name: sysbus
          hostPath:
            path: /sys/bus
        - name: libmodules
          hostPath:
            path: /lib/modules
        - name: mon-endpoint-volume
          configMap:
            name: rook-ceph-mon-endpoints
            items:
              - key: data
                path: mon-endpoints
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: HAS-SETUP-CEPH-STORAGE
                key: HAS-SETUP-HUGEPAGE-2048kB-32768
                operator: Exists
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - ceph-spdk-vhost-daemon
            topologyKey: kubernetes.io/hostname
---
