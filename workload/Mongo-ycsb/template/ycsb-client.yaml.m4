#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
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
       name: mongodb-client
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: benchmark
        image: IMAGENAME(ifelse(regexp(PLATFORM, `ARMv[0-9]'), -1, `amd64', `arm64')-ycsb-0.17.0-ifelse(regexp(WORKLOAD, \(iaa\|qat\)), -1, `base', `optimized'))
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
          - name: m_threads
            value: "defn(`THREADS')"
          - name: m_operationcount
            value: "defn(`OPERATION_COUNT')"
          - name: m_recordcount
            value: "defn(`RECORD_COUNT')"
          - name: m_insertstart
            value: "defn(`INSERT_START')"
          - name: m_insertcount
            value: "defn(`INSERT_COUNT')"
          - name: m_insertorder
            value: "defn(`INSERT_ORDER')"
          - name: m_fieldcount
            value: "defn(`FIELD_COUNT')"
          - name: m_fieldlength
            value: "defn(`FIELD_LENGTH')"
          - name: m_minfieldlength
            value: "defn(`MIN_FIELD_LENGTH')"
          - name: m_readallfields
            value: "defn(`READ_ALL_FIELDS')"
          - name: m_writeallfields
            value: "defn(`WRITE_ALL_FIELDS')"
          - name: m_readproportion
            value: "defn(`READ_PROPORTION')"
          - name: m_updateproportion
            value: "defn(`UPDATE_PROPORTION')"
          - name: m_insertproportion
            value: "defn(`INSERT_PROPORTION')"
          - name: m_scanproportion
            value: "defn(`SCAN_PROPORTION')"
          - name: m_readmodifywrite_proportion
            value: "defn(`READ_MODIFY_WRITE_PROPORTION')"
          - name: m_requestdistribution
            value: "defn(`REQUEST_DISTRIBUTION')"
          - name: m_minscanlength
            value: "defn(`MIN_SCANLENGTH')"
          - name: m_maxscanlength
            value: "defn(`MAX_SCANLENGTH')"
          - name: m_scanlengthdistribution
            value: "defn(`SCAN_LENGTH_DISTRIBUTION')"
          - name: m_zeropadding
            value: "defn(`ZERO_PADDING')"
          - name: m_fieldnameprefix
            value: "defn(`FIELD_NAME_PREFIX')"
          - name: m_measurementtype
            value: "defn(`YCSB_MEASUREMENT_TYPE')"
          - name: m_maxexecutiontime
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
          - name: m_replica_set
            value: "defn(`REPLICA_SET')"
          - name: m_hero_feature_iaa
            value: "defn(`HERO_FEATURE_IAA')"
ifelse(RUN_SINGLE_NODE,false,`dnl
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: name
                operator: In
                values:
                - mongodb-server
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
                  - mongodb-client
              topologyKey: kubernetes.io/hostname
        node_Affinity(`VM-GROUP',`client')dnl
      topologySpreadConstraints:
        - topologyKey: kubernetes.io/hostname
          maxSkew: defn(`MAX_SKEW')
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              name: mongodb-client
',)dnl
      restartPolicy: Never
  backoffLimit: 4
')
