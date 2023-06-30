#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(../../template/config.m4)
include(template/mysql.yaml.m4)
include(template/redis.yaml.m4)
include(template/rtsp.yaml.m4)

mysqlService()
redisService()
rtspService()


---

apiVersion: batch/v1
kind: Job
metadata:
  name: instance
spec:
  parallelism: 1
  completions: 1
  completionMode: Indexed
  template:
    metadata:
      labels:
        name: "benchmark"
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: benchmark
        image: IMAGENAME(Dockerfile.1.instance)
        imagePullPolicy: IMAGEPOLICY(Always)
        securityContext:
          privileged: true
        env:
          - name: `CLUSTERNODES'
            value: "defn(`CLUSTERNODE')"
          - name: REDIS_HOST
            value: "smt-redis"
          - name: REDIS_PORT
            value: "6380"
          - name: MYSQL_HOST
            value: "mysql-service"
          - name: NODE_IP
            valueFrom:
              fieldRef:
                fieldPath: status.hostIP
          - name: `DATABASE'
            value: "dbenchmark.yaml.m4efn(`K_DATABASE')"
          - name: `VIDEO_DECODE'
            value: "defn(`K_VIDEO_DECODE')"
          - name: `AI_DEVICE'
            value: "defn(`K_AI_DEVICE')"
      nodeSelector:
        HAS-SETUP-SMART-SCIENCE-LAB: "yes"            
      restartPolicy: Never