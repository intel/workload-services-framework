include(config.m4)
cluster:
ifelse("defn(`SPECJBB_USE_HUGE_PAGES')","true",`dnl
- labels:
    HAS-SETUP-HUGEPAGE-defn(`HUGEPAGE_SIZE_KB')kB-defn(`HUGEPAGE_NUMBER_OF_PAGES'): required    
',`dnl
- labels: {}
')dnl
ifelse(index(TESTCASE,`_gated'),-1,`dnl
  sysfs:
    /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor: performance
    /sys/kernel/mm/transparent_hugepage/defrag : always
    /sys/kernel/mm/transparent_hugepage/enabled : always
    /proc/sys/kernel/sched_cfs_bandwidth_slice_us: 10000 
    /proc/sys/kernel/sched_child_runs_first: 0 
    /proc/sys/kernel/sched_latency_ns: 16000000
    /proc/sys/kernel/sched_migration_cost_ns: 1000     
    /proc/sys/kernel/sched_nr_migrate: 9 
    /proc/sys/kernel/sched_rr_timeslice_ms: 100 
    /proc/sys/kernel/sched_rt_period_us: 1000000 
    /proc/sys/kernel/sched_rt_runtime_us: 990000 
    /proc/sys/kernel/sched_schedstats: 0 
    /proc/sys/kernel/sched_tunable_scaling: 1     
    /proc/sys/vm/dirty_expire_centisecs: 3000 
    /proc/sys/vm/dirty_writeback_centisecs: 500 
    /proc/sys/vm/dirty_ratio: 40 
    /proc/sys/vm/dirty_background_ratio: 10 
    /proc/sys/vm/swappiness: 10     
    /proc/sys/kernel/shmmax: 274877906944
    /proc/sys/kernel/shmall: 274877906944
ifelse("defn(`MODE')","composite",`dnl
    /proc/sys/kernel/numa_balancing: 1
',`dnl
    /proc/sys/kernel/numa_balancing: 0
')dnl

# Some configuration may have extra specific kernel configruations
ifelse(index(TESTCASE,`_amazon_'),-1,`dnl
    /proc/sys/kernel/sched_wakeup_granularity_ns: 50000000
    /proc/sys/kernel/sched_min_granularity_ns: 28000000
',`dnl    
    /proc/sys/kernel/sched_min_granularity_ns: 150000000
    /proc/sys/kernel/sched_wakeup_granularity_ns: 1000000000
    /proc/sys/vm/drop_caches: 3
    /proc/sys/vm/compact_memory: 1
    /proc/sys/vm/overcommit_memory: 1        
')dnl

  sysctls:
    net.core.wmem_max: 12582912
    net.core.rmem_max: 12582912
    net.ipv4.tcp_rmem: "10240 87380 12582912"
    net.ipv4.tcp_wmem: "10240 87380 12582912"
    net.core.netdev_max_backlog: 655560    
    net.ipv4.tcp_no_metrics_save: 1
# Some configuration may have extra specific kernel configruations
ifelse(index(TESTCASE,`_amazon_'),-1,`dnl
    net.core.somaxconn: 32768
',`dnl    
    net.core.somaxconn: 65535        
    net.ipv4.tcp_tw_reuse: 1
    net.ipv4.tcp_fin_timeout: 15
    net.ipv4.ip_local_port_range: "1024 65535"
    net.ipv4.tcp_timestamps: 1
    net.ipv4.tcp_syncookies: 1
    net.ipv4.tcp_tw_recycle: 1  
')dnl

',)