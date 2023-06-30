#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    kubevirt.io: virt-operator
  name: virt-operator
  namespace: kubevirt
spec:
  replicas: 2
  selector:
    matchLabels:
      kubevirt.io: virt-operator
  strategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        kubevirt.io: virt-operator
        name: virt-operator
        prometheus.kubevirt.io: "true"
      name: virt-operator
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: kubevirt.io
                  operator: In
                  values:
                  - virt-operator
              topologyKey: kubernetes.io/hostname
            weight: 1
      containers:
      - command:
        - virt-operator
        - --port
        - "8443"
        - -v
        - "2"
        env:
        - name: OPERATOR_IMAGE
          value: defn(`KUBEVIRT_OPERATOR_DOCKER_IMAGE')
        - name: WATCH_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.annotations['olm.targetNamespaces']
        image: defn(`KUBEVIRT_OPERATOR_DOCKER_IMAGE')
        imagePullPolicy: IfNotPresent
        name: virt-operator
        ports:
        - containerPort: 8443
          name: metrics
          protocol: TCP
        - containerPort: 8444
          name: webhooks
          protocol: TCP
        readinessProbe:
          httpGet:
            path: /metrics
            port: 8443
            scheme: HTTPS
          initialDelaySeconds: 5
          timeoutSeconds: 10
        resources:
          requests:
            cpu: 10m
            memory: 150Mi
        volumeMounts:
        - mountPath: /etc/virt-operator/certificates
          name: kubevirt-operator-certs
          readOnly: true
        - mountPath: /profile-data
          name: profile-data
      priorityClassName: kubevirt-cluster-critical
      securityContext:
        runAsNonRoot: true
      serviceAccountName: kubevirt-operator
      tolerations:
      - key: CriticalAddonsOnly
        operator: Exists
      volumes:
      - name: kubevirt-operator-certs
        secret:
          optional: true
          secretName: kubevirt-operator-certs
      - emptyDir: {}
        name: profile-data
