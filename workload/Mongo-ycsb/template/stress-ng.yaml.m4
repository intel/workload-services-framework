#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
define(`stressNg', `
ifelse(MONGO_DISK_DATABASE_ACCESS,true,`dnl
apiVersion: batch/v1
kind: Job
metadata:
  name: stress-ng
spec:
  template:
    metadata:
      labels:
       name: stress-ng
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      restartPolicy: Never
      containers:
      - name: stress-ng
        image: IMAGENAME(ycsb-ifelse(regexp(PLATFORM, ARMv[0-9]),-1,`amd64',`arm64')-patsubst(patsubst(WORKLOAD,`ycsb_', `'),`_',`-'))
        imagePullPolicy: IMAGEPOLICY(Always)
        command: ["/bin/bash", "-c", "stress-ng.sh"]
        securityContext:
          privileged: true
        env:
          - name: m_mongo_disk_database_access
            value: "defn(`MONGO_DISK_DATABASE_ACCESS')"
          - name: m_enable_transparent_hugepages
            value: "defn(`ENABLE_TRANSPARENT_HUGEPAGES')"
          - name: m_mongodb_percentage_db_cache_db
            value: "defn(`MONGODB_PERCENTAGE_DB_CACHE_DB')"
          - name: m_field_length
            value: "defn(`FIELD_LENGTH')"
          - name: m_field_count
            value: "defn(`FIELD_COUNT')"
          - name: m_record_count
            value: "defn(`RECORD_COUNT')"
          - name: m_client_server_pair
            value: "defn(`CLIENT_SERVER_PAIR')"
ifelse(RUN_SINGLE_NODE,false,`dnl
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: name
                operator: In
                values:
                - mongodb-client
            topologyKey: kubernetes.io/hostname              
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: name
                  operator: In
                  values:
                  - mongodb-server
              topologyKey: kubernetes.io/hostname
        node_Affinity(`VM-GROUP',`worker')dnl
',)dnl
  backoffLimit: 4
',)

')
