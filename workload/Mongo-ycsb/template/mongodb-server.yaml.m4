#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
define(`mongodbServer', `dnl
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb-server-$1
  labels:
    app: mongodb-server-$1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb-server-$1
  template:
    metadata:
        labels:
          app: mongodb-server-$1
          name: mongodb-server
          deployPolicy: standalone
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: mongodb-server
        image: IMAGENAME(ycsb-amd64-mongodb604-base)
        resources:
ifelse(KUBERNETES_RESOURCE_REQUESTS,true,`dnl
          requests:
ifelse(KUBERNETES_RESOURCE_REQUESTS_CPU,,,`dnl
            cpu: defn(`KUBERNETES_RESOURCE_REQUESTS_CPU')
')dnl
ifelse(KUBERNETES_RESOURCE_REQUESTS_MEMORY,,,`dnl
            memory: defn(`KUBERNETES_RESOURCE_REQUESTS_MEMORY')
')dnl
',)dnl
ifelse(KUBERNETES_RESOURCE_LIMITS,true,`dnl
          limits:
ifelse(KUBERNETES_RESOURCE_LIMITS_CPU,,,`dnl
            cpu: defn(`KUBERNETES_RESOURCE_LIMITS_CPU')
')dnl
ifelse(KUBERNETES_RESOURCE_LIMITS_MEMORY,,,`dnl
            memory: defn(`KUBERNETES_RESOURCE_LIMITS_MEMORY')
')dnl
',)dnl
        imagePullPolicy: IMAGEPOLICY(Always)
        volumeMounts:
ifelse(DB_HOSTPATH,,,`dnl
        - name: dbpath
          mountPath: /var/lib/mongo
')dnl
ifelse(HERO_FEATURE_IAA,true,`dnl
        - mountPath: /dev
          name: dev
',)dnl
        ports:
          - containerPort: $1
        securityContext:
          privileged: true
        env:
          - name: m_customer_numaopt_server
            value: "defn(`CUSTOMER_NUMAOPT_SERVER')"
          - name: m_run_single_node
            value: "defn(`RUN_SINGLE_NODE')"
          - name: m_client_count
            value: "defn(`CLIENT_COUNT')" 
          - name: server_index
            value: "$1"
          - name: m_numactl_option
            value: "defn(`NUMACTL_OPTION')"
          - name: m_core_nums_each_instance
            value: "defn(`CORE_NUMS_EACH_INSTANCE')"
          - name: m_select_numa_node
            value: "defn(`SELECT_NUMA_NODE')"   
          - name: m_cores
            value: "defn(`CORES')"
          - name: m_client_server_pair
            value: "defn(`CLIENT_SERVER_PAIR')"
          - name: m_cache_size_gb
            value: "defn(`CACHE_SIZE_GB')"
          - name: m_journal_enabled
            value: "defn(`JOURNAL_ENABLED')"
          - name: m_journalcompressor
            value: "defn(`JOURNAL_COMPRESSOR')"
          - name: m_collectionconfig_blockcompressor
            value: "defn(`COLLECTIONCONFIG_BLOCKCOMPRESSOR')"
          - name: m_process_management_fork
            value: "defn(`PROCESS_MANAGEMENT_FORK')"
          - name: m_tls_flag
            value: "defn(`TLS_FLAG')"
          - name: m_config_center_port
            value: "defn(`CONFIG_CENTER_PORT')"
          - name: m_mongo_disk_database_access
            value: "defn(`MONGO_DISK_DATABASE_ACCESS')"
          - name: m_enable_transparent_hugepages
            value: "defn(`ENABLE_TRANSPARENT_HUGEPAGES')"
          - name: m_field_length
            value: "defn(`FIELD_LENGTH')"
          - name: m_field_count
            value: "defn(`FIELD_COUNT')"
          - name: m_record_count
            value: "defn(`RECORD_COUNT')"
      volumes:
ifelse(DB_HOSTPATH,,,`dnl
      - name: dbpath
        hostPath:
          path: $2
          type: DirectoryOrCreate
')dnl
ifelse(HERO_FEATURE_IAA,true,`dnl
      - name: dev
        hostPath:
          path: /dev
          type: Directory
',)dnl
ifelse(RUN_SINGLE_NODE,false,`dnl
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            podAffinityTerm:
              labelSelector:
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
---

apiVersion: v1
kind: Service
metadata:
  name: mongodb-server-service-$1
  labels:
    name: mongodb-server-service-$1
spec:
  ports:
    - port: $1
      protocol: TCP
      name: mongodb-server-$1
  selector:
    app: mongodb-server-$1
  type: ClusterIP

---
')
