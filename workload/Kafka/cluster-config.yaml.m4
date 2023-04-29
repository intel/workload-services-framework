include(config.m4)

cluster:
- labels:
    {}
ifelse(index(TESTCASE,_3n),-1,,`loop(`i', `0', BROKER_SERVER_NUM, `dnl
- labels:
    {}
')')
