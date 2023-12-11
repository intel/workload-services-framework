include(config.m4)

cluster:
- labels: {}

  sysfs:
    /sys/kernel/mm/transparent_hugepage/enabled : never
