#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(config.m4)

apiVersion: batch/v1
kind: Job
metadata:
  name: benchmark
spec:
  template:
    metadata:
      labels:
        app: benchmark
    spec:
      containers:
      - name: benchmark
        image: IMAGENAME(defn(`DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        volumeMounts:
        - mountPath: /dev/shm
          name: dshm
        env:
        - name: `N_SIZE'
          value: "defn(`K_N_SIZE')"
        - name: `P_SIZE'
          value: "defn(`K_P_SIZE')"
        - name: `Q_SIZE'
          value: "defn(`K_Q_SIZE')"
        - name: `NB_SIZE'
          value: "defn(`K_NB_SIZE')"
        - name: `ASM'
          value: "defn(`K_ASM')"
        securityContext:
          privileged: true
      volumes:
      - name: dshm
        emptyDir:
          medium: Memory
          sizeLimit: "16Gi"
      restartPolicy: Never
