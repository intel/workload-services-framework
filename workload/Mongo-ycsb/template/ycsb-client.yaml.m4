define(`ycsbClient', `
apiVersion: batch/v1
kind: Job
metadata:
  name: benchmark
spec:
  parallelism: CLIENT_SERVER_PAIR
  completions: CLIENT_SERVER_PAIR
  completionMode: Indexed
  template:
    metadata:
      labels:
       name: MONGODB-CLIENT
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: benchmark
        image: IMAGENAME(ycsb-0.17.0-base)
        resources:
          requests:
            cpu: 1
        imagePullPolicy: IMAGEPOLICY(Always)
        securityContext:
          privileged: true
        env:
          - name: m_select_numa_node
            value: "defn(`SELECT_NUMA_NODE')" 
          - name: m_numactl_option
            value: "defn(`NUMACTL_OPTION')"
          - name: m_customer_numaopt_client
            value: "defn(`CUSTOMER_NUMAOPT_CLIENT')"
          - name: m_run_single_node
            value: "defn(`RUN_SINGLE_NODE')"
          - name: m_client_count
            value: "defn(`CLIENT_COUNT')"       
          - name: m_cores
            value: "defn(`CORES')"
          - name: m_ycsb_cores
            value: "defn(`YCSB_CORES')"
          - name: MONGODB_SERVER
            value: mongodb-server-service
          - name: test_case
            value: "defn(`TESTCASE')"
          - name: workload_file
            value: "defn(`WORKLOAD_FILE')"
          - name: threads
            value: "defn(`THREADS')"
          - name: operation_count
            value: "defn(`OPERATION_COUNT')"
          - name: record_count
            value: "defn(`RECORD_COUNT')"
          - name: insert_start
            value: "defn(`INSERT_START')"
          - name: insert_count
            value: "defn(`INSERT_COUNT')"
          - name: m_field_count
            value: "defn(`FIELD_COUNT')"
          - name: m_field_length
            value: "defn(`FIELD_LENGTH')"
          - name: m_min_field_length
            value: "defn(`MIN_FIELD_LENGTH')"
          - name: m_read_all_fields
            value: "defn(`READ_ALL_FIELDS')"
          - name: m_write_all_fields
            value: "defn(`WRITE_ALL_FIELDS')"
          - name: m_read_proportion
            value: "defn(`READ_PROPORTION')"
          - name: m_update_proportion
            value: "defn(`UPDATE_PROPORTION')"
          - name: m_insert_proportion
            value: "defn(`INSERT_PROPORTION')"
          - name: m_scan_proportion
            value: "defn(`SCAN_PROPORTION')"
          - name: m_read_modify_write_proportion
            value: "defn(`READ_MODIFY_WRITE_PROPORTION')"
          - name: m_request_distribution
            value: "defn(`REQUEST_DISTRIBUTION')"
          - name: m_min_scanlength
            value: "defn(`MIN_SCANLENGTH')"
          - name: m_max_scanlength
            value: "defn(`MAX_SCANLENGTH')"
          - name: m_scan_length_distribution
            value: "defn(`SCAN_LENGTH_DISTRIBUTION')"
          - name: m_zero_padding
            value: "defn(`ZERO_PADDING')"
          - name: m_insert_order
            value: "defn(`INSERT_ORDER')"
          - name: m_field_name_prefix
            value: "defn(`FIELD_NAME_PREFIX')"
          - name: m_max_execution_time
            value: "defn(`MAX_EXECUTION_TIME')"
          - name: m_jvm_args
            value: "defn(`JVM_ARGS')"
          - name: m_client_server_pair
            value: "defn(`CLIENT_SERVER_PAIR')"
          - name: m_config_center_port
            value: "defn(`CONFIG_CENTER_PORT')"
          - name: m_target
            value: "defn(`TARGET')"
          - name: m_tls_flag
            value: "defn(`TLS_FLAG')"
          - name: m_ycsb_measurement_type
            value: "defn(`YCSB_MEASUREMENT_TYPE')"
ifelse(RUN_SINGLE_NODE,false,`dnl
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: name
                operator: In
                values:
                - MONGODB-SERVER
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
                  - MONGODB-CLIENT
              topologyKey: kubernetes.io/hostname
        node_Affinity(`VM-GROUP',`client')
      topologySpreadConstraints:
        - topologyKey: kubernetes.io/hostname
          maxSkew: defn(`MAX_SKEW')
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              name: MONGODB-CLIENT
',)
      restartPolicy: Never
  backoffLimit: 4

')
