define(`mongodbServer', `
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
          name: MONGODB-SERVER
          deployPolicy: standalone
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: mongodb-server-$1
        image: IMAGENAME(ycsb-amd64-mongodb441-base)
        resources:
          requests:
            cpu: 1
        imagePullPolicy: IMAGEPOLICY(Always)
ifelse(DB_HOSTPATH,,,`dnl
        volumeMounts:
        - name: dbpath
          mountPath: /var/lib/mongo
')dnl 
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
          - name: m_network_rps_tune_enable
            value: "defn(`NETWORK_RPS_TUNE_ENABLE')"
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
          - name: m_collectionconfig_blockcompressor
            value: "defn(`COLLECTIONCONFIG_BLOCKCOMPRESSOR')"
          - name: m_tls_flag
            value: "defn(`TLS_FLAG')"
          - name: m_config_center_port
            value: "defn(`CONFIG_CENTER_PORT')"
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
ifelse(DB_HOSTPATH,,,`dnl
      volumes:
      - name: dbpath
        hostPath:
          path: "defn(`DB_HOSTPATH')"
          type: DirectoryOrCreate
')dnl      
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
                  - MONGODB-CLIENT
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
                  - MONGODB-SERVER
              topologyKey: kubernetes.io/hostname
        node_Affinity(`VM-GROUP',`worker')
',)           
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

