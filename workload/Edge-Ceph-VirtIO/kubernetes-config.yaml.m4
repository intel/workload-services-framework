#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)
---
# Service account for the Rook-Ceph benchmark operator
apiVersion: v1
kind: ServiceAccount
metadata:
  name: defn(`BENCH_OPERATOR_NAME')

---
# Grant the benchmark operator the cluster-wide access to manage the Rook CRDs, PVCs, and storage classes
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: defn(`BENCH_OPERATOR_NAME')-global
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: rook-ceph-global
subjects:
  - kind: ServiceAccount
    name: defn(`BENCH_OPERATOR_NAME')
    namespace: defn(`NAMESPACE')
---

kind: ClusterRoleBinding
# Give Rook-Ceph Operator permissions to provision ObjectBuckets in response to ObjectBucketClaims.
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: defn(`BENCH_OPERATOR_NAME')-rook-ceph-object-bucket
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: rook-ceph-object-bucket
subjects:
  - kind: ServiceAccount
    name: defn(`BENCH_OPERATOR_NAME')
    namespace: defn(`NAMESPACE') # namespace:operator
---

kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: defn(`BENCH_OPERATOR_NAME')-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: rook-ceph-system
subjects:
  - kind: ServiceAccount
    name: defn(`BENCH_OPERATOR_NAME')
    namespace: defn(`NAMESPACE') # namespace:operator

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: defn(`BENCH_OPERATOR_NAME')-psp
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: 'psp:rook'
subjects:
  - kind: ServiceAccount
    name: defn(`BENCH_OPERATOR_NAME')
    namespace: defn(`NAMESPACE') # namespace:operator
---

# Allow the operator to create resources in this cluster's namespace
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: defn(`BENCH_OPERATOR_NAME')-rook-ceph-cluster-mgmt
  namespace: defn(`NAMESPACE') # namespace:cluster
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: rook-ceph-cluster-mgmt
subjects:
  - kind: ServiceAccount
    name: defn(`BENCH_OPERATOR_NAME')
    namespace: defn(`NAMESPACE') # namespace:operator
---
# Grant the operator, agent, and discovery agents access to resources in the rook-ceph-system namespace
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: defn(`BENCH_OPERATOR_NAME')-rook-ceph-system
  namespace: defn(`NAMESPACE') # namespace:operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: rook-ceph-system
subjects:
  - kind: ServiceAccount
    name: defn(`BENCH_OPERATOR_NAME')
    namespace: defn(`NAMESPACE') # namespace:operator
---


# Bind the cluster role and role for kubevirt
# if SUPPORT_KUBEVIRT TRUE; then
#
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    kubevirt.io: ""
  name: defn(`BENCH_OPERATOR_NAME')-kubevirt-operator-rolebinding
  namespace:  defn(`NAMESPACE') # namespace:operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: kubevirt-operator
subjects:
- kind: ServiceAccount
  name: defn(`BENCH_OPERATOR_NAME')
  namespace: defn(`NAMESPACE') # namespace:operator

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    kubevirt.io: ""
  name: defn(`BENCH_OPERATOR_NAME')-kubevirt-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kubevirt-operator
subjects:
- kind: ServiceAccount
  name: defn(`BENCH_OPERATOR_NAME')
  namespace: defn(`NAMESPACE') # namespace:operator

---

# BEGIN ROOK-CEPH Benchmark OPERATOR DEPLOYMENT
apiVersion: apps/v1
kind: Deployment
metadata:
  name: defn(`BENCH_OPERATOR_NAME')
  namespace: defn(`NAMESPACE')  # namespace
  labels:
    storage-backend: ceph
    cloud-native-vm: kubevirt
spec:
  selector:
    matchLabels:
      app: defn(`BENCH_OPERATOR_NAME')
  replicas: 1
  template:
    metadata:
      labels:
        app: defn(`BENCH_OPERATOR_NAME')
    spec:
      serviceAccountName: defn(`BENCH_OPERATOR_NAME')
      containers:
        - name: defn(`BENCH_OPERATOR_NAME')
          image: IMAGENAME(Dockerfile.1.edge_ceph_operator)
          imagePullPolicy: IMAGEPOLICY(Always)
ifelse("defn(`DEBUG_MODE')","1",`dnl
          command: ["sleep"]
          args: ["infinity"]
',)dnl
          securityContext:
            privileged: true
            runAsUser: 0
          volumeMounts:
            - mountPath: /dev
              name: dev
            - mountPath: /sys/bus
              name: sysbus
            - mountPath: /lib/modules
              name: libmodules
          ports:
            - containerPort: 9443
              name: https-webhook
              protocol: TCP
          env:
            - name: CLUSTER_WORKERS
              value: ""
            - name: CLUSTER_NS
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace  #My current POD namespace.
            - name: `DOCKER_IMAGE_GUESTOS'
              value: "IMAGENAME(Dockerfile.1.guestOS)"
            - name: `DOCKER_IMAGE_VHOST'
              value: "IMAGENAME(Dockerfile.1.rook_ceph_spdk_vhost)"
            - name: `KUBEVIRT_OPERATOR_DOCKER_IMAGE'
              value: "defn(`REGISTRY')`virt-operator'defn(`RELEASE')"
            - name: `ROOK_CEPH_STORAGE_NS'
              value: "defn(`ROOK_CEPH_STORAGE_NAMESPACE')"
            - name: `TEST_CASE'
              value: "defn(`TEST_CASE')"
            - name: `CLUSTERNODES'
              value: "defn(`CLUSTERNODES')"
            - name: `TEST_DURATION'
              value: "defn(`TEST_DURATION')"
            - name: `BENCHMARK_OPTIONS'
              value: "defn(`BENCHMARK_OPTIONS')"
            - name: `CONFIGURATION_OPTIONS'
              value: "defn(`CONFIGURATION_OPTIONS')"
            - name: `DEBUG_MODE'
              value: "defn(`DEBUG_MODE')"
      volumes:
        - name: dev
          hostPath:
            path: /dev
        - name: sysbus
          hostPath:
            path: /sys/bus
        - name: libmodules
          hostPath:
            path: /lib/modules
      tolerations:
        - key: node-role.kubernetes.io/master
          #operator: Exists
          effect: NoSchedule
# END ROOK-CEPH OPERATOR DEPLOYMENT
