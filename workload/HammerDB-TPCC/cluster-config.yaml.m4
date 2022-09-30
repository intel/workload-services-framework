include(config.m4)

define(`SERVER_LABEL_POLICY', `
ifelse(DB_HUGEPAGE_STATUS,on,`- labels:',ENABLE_MOUNT_DIR,true,`- labels:',`- labels: {}')
ifelse(DB_HUGEPAGE_STATUS,on,`dnl
    HAS-SETUP-HUGEPAGE-2048kB-DB_HUGEPAGES: required
')
ifelse(ENABLE_MOUNT_DIR,true,`dnl
    HAS-SETUP-DISK-MOUNT-1: required
')
')dnl

cluster:
ifelse(RUN_SINGLE_NODE,true,`dnl
SERVER_LABEL_POLICY
',`dnl
- labels: {}
SERVER_LABEL_POLICY
')

