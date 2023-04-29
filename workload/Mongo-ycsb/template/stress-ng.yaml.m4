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
        image: IMAGENAME(Dockerfile.1.mongodb)
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
          - name: m_network_rps_tune_enable
            value: "defn(`NETWORK_RPS_TUNE_ENABLE')"
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
  backoffLimit: 4
',)

')
