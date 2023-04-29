include(config.m4)

cluster:

ifelse("defn(`CLUSTERNODES')","1",`dnl
- labels: {}
',`dnl
- labels:
    HAS-SETUP-STORAGE: "required"
- labels:
    HAS-SETUP-SMART-SCIENCE-LAB: "required"
')dnl