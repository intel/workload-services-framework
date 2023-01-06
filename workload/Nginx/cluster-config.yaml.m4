include(config.m4)

cluster:
ifelse(defn(`NODE'),3,`dnl
- labels: {}
- labels: {}
')dnl
ifelse(defn(`NODE'),2,`dnl
- labels: {}
')dnl
- labels: {}