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
        - name: CONFIG
          value: "defn(`K_CONFIG')"
        - name: TEST_GATED
          value: "defn(`K_TEST_GATED')"
        - name: X_DIMENSION
          value: "defn(`K_X_DIMENSION')"
        - name: Y_DIMENSION
          value: "defn(`K_Y_DIMENSION')"
        - name: Z_DIMENSION
          value: "defn(`K_Z_DIMENSION')"
        - name: RUN_SECONDS
          value: "defn(`K_RUN_SECONDS')"
        - name: OMP_NUM_THREADS
          value: "defn(`K_OMP_NUM_THREADS')"
        - name: PROCESS_PER_NODE
          value: "defn(`K_PROCESS_PER_NODE')"
        - name: KMP_AFFINITY
          value: "defn(`K_KMP_AFFINITY')"
        - name: MPI_AFFINITY
          value: "defn(`K_MPI_AFFINITY')"
        - name: THREADS_PER_SOCKET
          value: "defn(`K_THREADS_PER_SOCKET')"
        securityContext:
          privileged: true
      volumes:
      - name: dshm
        emptyDir:
          medium: Memory
          sizeLimit: 8Gi 
      restartPolicy: Never
