include(config.m4)

cluster:
- labels: {}
  vm_group: worker
ifelse(DB_HUGEPAGE_STATUS,true,`dnl
 sysfs:
    /sys/kernel/mm/transparent_hugepage/enabled: always
    /sys/kernel/mm/transparent_hugepage/defrag: always
',
` dnl
 sysfs:
    /sys/kernel/mm/transparent_hugepage/enabled: never
    /sys/kernel/mm/transparent_hugepage/defrag: never
')dnl
loop(`i', `0', eval(CLIENT_COUNT-1), `dnl 
- labels: {}
  vm_group: client
')

