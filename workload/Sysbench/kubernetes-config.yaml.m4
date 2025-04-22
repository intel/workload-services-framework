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
    spec:
      containers:
      - name: benchmark
        image: IMAGENAME(defn(`DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        env:
        - name: `MODE'
          value: "MODE"
        - name: `THREADS'
          value: "THREADS"
        - name: `TIME'
          value: "TIME"
        - name: `CPU_MAX_PRIME'
          value: "CPU_MAX_PRIME"
        - name: `TEST_TYPE'
          value: "TEST_TYPE"
        - name: `MEMORY_BLOCK_SIZE'
          value: "MEMORY_BLOCK_SIZE"
        - name: `MEMORY_TOTAL_SIZE'
          value: "MEMORY_TOTAL_SIZE"
        - name: `MEMORY_SCOPE'
          value: "MEMORY_SCOPE"
        - name: `MEMORY_OPER'
          value: "MEMORY_OPER"
        - name: `MEMORY_ACCESS_MODE'
          value: "MEMORY_ACCESS_MODE"
        - name: `MYSQL_ROOT_PASSWORD'
          value: "MYSQL_ROOT_PASSWORD"
        - name: `MUTEX_LOCKS'
          value: "MUTEX_LOCKS"
        - name: `TABLES_NUM'
          value: "TABLES_NUM"
        - name: `TABLE_SIZE'
          value: "TABLE_SIZE"
      restartPolicy: Never
