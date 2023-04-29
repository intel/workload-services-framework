include(config.m4)

apiVersion: batch/v1
kind: Job
metadata:
  name: specjbb
spec:
  template:
    metadata:
      labels:
        app: specjbb
    spec:
      # namespaced /sys settings
      securityContext:
        sysctls:
        - name: net.ipv4.ip_local_port_range
          value: "1024 65535"
        - name: net.ipv4.tcp_syncookies
          value: "1"                
              
      # Specjbb container
      containers:
      - name: specjbb
        image: IMAGENAME(defn(`DOCKER_IMAGE'))
        imagePullPolicy: IMAGEPOLICY(Always)
        env:                       
        - name: `SPECJBB_RUN_TYPE'
          value: "defn(`SPECJBB_RUN_TYPE')"
        - name: `SPECJBB_GROUPS'
          value: "defn(`SPECJBB_GROUPS')"
        - name: `SPECJBB_DURATION'
          value: "defn(`SPECJBB_DURATION')"
        - name: `SPECJBB_PRESET_IR'
          value: "defn(`SPECJBB_PRESET_IR')"
        # Following variables are primarily used for Multi-mode runs
        - name: `SPECJBB_BACKEND_SURVIVOR_RATIO'
          value: "defn(`SPECJBB_BACKEND_SURVIVOR_RATIO')"
        - name: `SPECJBB_CLIENT_POOL_SIZE'
          value: "defn(`SPECJBB_CLIENT_POOL_SIZE')"
        - name: `SPECJBB_RT_CURVE_WARMUP_STEP'
          value: "defn(`SPECJBB_RT_CURVE_WARMUP_STEP')"
        - name: `SPECJBB_SM_REPLENISH_LOCALPERCENT'
          value: "defn(`SPECJBB_SM_REPLENISH_LOCALPERCENT')"
        - name: `SPECJBB_CONTROLLER_HEAP_MEMORY'
          value: "defn(`SPECJBB_CONTROLLER_HEAP_MEMORY')"
        - name: `SPECJBB_CUSTOMER_DRIVER_THREADS'
          value: "defn(`SPECJBB_CUSTOMER_DRIVER_THREADS')"
        - name: `SPECJBB_CUSTOMER_DRIVER_THREADS_PROBE'
          value: "defn(`SPECJBB_CUSTOMER_DRIVER_THREADS_PROBE')"
        - name: `SPECJBB_CUSTOMER_DRIVER_THREADS_SATURATE'
          value: "defn(`SPECJBB_CUSTOMER_DRIVER_THREADS_SATURATE')"
        - name: `SPECJBB_GC_THREADS'
          value: "defn(`SPECJBB_GC_THREADS')"
        - name: `SPECJBB_INJECTOR_HEAP_MEMORY'
          value: "defn(`SPECJBB_INJECTOR_HEAP_MEMORY')"
        - name: `SPECJBB_JAVA_PARAMETERS'
          value: "defn(`SPECJBB_JAVA_PARAMETERS')"
        - name: `SPECJBB_INJECTOR_JAVA_PARAMETERS'
          value: "defn(`SPECJBB_INJECTOR_JAVA_PARAMETERS')"
        - name: `SPECJBB_CONTROLLER_JAVA_PARAMETERS'
          value: "defn(`SPECJBB_CONTROLLER_JAVA_PARAMETERS')"
        - name: `SPECJBB_HUGE_PAGE_SIZE'
          value: "defn(`SPECJBB_HUGE_PAGE_SIZE')"
        - name: `SPECJBB_LOADLEVEL_START'
          value: "defn(`SPECJBB_LOADLEVEL_START')"
        - name: `SPECJBB_LOADLEVEL_STEP'
          value: "defn(`SPECJBB_LOADLEVEL_STEP')"
        - name: `SPECJBB_MAPREDUCER_POOL_SIZE'
          value: "defn(`SPECJBB_MAPREDUCER_POOL_SIZE')"
        - name: `SPECJBB_RTSTART'
          value: "defn(`SPECJBB_RTSTART')"
        - name: `SPECJBB_SELECTOR_RUNNER_COUNT'
          value: "defn(`SPECJBB_SELECTOR_RUNNER_COUNT')"
        - name: `SPECJBB_TIER_1_THREADS'
          value: "defn(`SPECJBB_TIER_1_THREADS')"
        - name: `SPECJBB_TIER_2_THREADS'
          value: "defn(`SPECJBB_TIER_2_THREADS')"
        - name: `SPECJBB_TIER_3_THREADS'
          value: "defn(`SPECJBB_TIER_3_THREADS')"        
        - name: `SPECJBB_USE_AVX'
          value: "defn(`SPECJBB_USE_AVX')"
        - name: `SPECJBB_USE_HUGE_PAGES'
          value: "defn(`SPECJBB_USE_HUGE_PAGES')"
        - name: `SPECJBB_WORKER_POOL_MAX'
          value: "defn(`SPECJBB_WORKER_POOL_MAX')"
        - name: `SPECJBB_WORKER_POOL_MIN'
          value: "defn(`SPECJBB_WORKER_POOL_MIN')"
        - name: `SPECJBB_XMN'
          value: "defn(`SPECJBB_XMN')"
        - name: `SPECJBB_XMS'
          value: "defn(`SPECJBB_XMS')"
        - name: `SPECJBB_XMX'
          value: "defn(`SPECJBB_XMX')"
        - name: `SPECJBB_PRINT_VARS'
          value: "defn(`SPECJBB_PRINT_VARS')"
        - name: `SPECJBB_TUNE_OPTION'
          value: "defn(`SPECJBB_TUNE_OPTION')"
        - name: `SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS'
          value: "defn(`SPECJBB_DEFAULT_T1_T2_T3_MULTIPLIERS')"
        - name: `HUGEPAGE_MEMORY_NUM'
          value: "defn(`HUGEPAGE_MEMORY_NUM')"     
        - name: `PLATFORM'
          value: "defn(`PLATFORM')"
        - name: `SPECJBB_WORKLOAD_CONFIG'
          value: "defn(`SPECJBB_WORKLOAD_CONFIG')"
        - name: `SPECJBB_USE_NUMA_NODES'
          value: "defn(`SPECJBB_USE_NUMA_NODES')"
        securityContext:
          runAsUser: defn(`WORKLOAD_USER_ID')
          runAsNonRoot: true
          capabilities:
            add:
            - SYS_NICE        # Needed for numa
ifelse("defn(`SPECJBB_USE_HUGE_PAGES')","true",`dnl
            - IPC_LOCK

        volumeMounts:
        - name: hugepage
          mountPath: /dev/hugepages
          readOnly: false

        resources:
          limits:
            defn(`HUGEPAGE_KB8_DIRECTIVE'): "defn(`HUGEPAGE_LIMIT')"
          requests:
            cpu: defn(`HUGEPAGE_KB8_CPU_UNITS')
            defn(`HUGEPAGE_KB8_DIRECTIVE'): "defn(`HUGEPAGE_LIMIT')"

      volumes:
      - name: hugepage
        emptyDir:
          medium: HugePages
',)dnl

      restartPolicy: Never
