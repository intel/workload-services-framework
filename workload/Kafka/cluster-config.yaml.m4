include(config.m4)

cluster:
- labels:
    {}
ifelse(index(TESTCASE,_3n),-1,,`dnl
- labels:
    {}
- labels:
    {}
')
