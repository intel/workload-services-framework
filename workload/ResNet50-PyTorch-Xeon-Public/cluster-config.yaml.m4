include(config.m4)

cluster:
ifelse(index(WORKLOAD,`_sgx'),-1,`dnl
- labels:
    HAS-SETUP-BKC-AI: "preferred"
',`dnl
- labels:
    HAS-SETUP-BKC-AI: "preferred"
    HAS-SETUP-GRAMINE-SGX: required
')
