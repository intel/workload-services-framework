#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
include(../../template/config.m4)
include(template/mongodb-server.yaml.m4)
include(template/ycsb-client.yaml.m4)
include(template/config-center.yaml.m4)

define(`node_Affinity', `dnl
nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: $1
                operator: In
                values:
                - "$2"
')dnl

# generate N pair of client-server, where N=CLIENT_SERVER_PAIR
loop(`i', `27017', eval(27017+CLIENT_SERVER_PAIR-1), `dnl
ifelse(DB_HOSTPATH,,,`dnl
define(`getdbpath', `esyscmd(echo -n DBPATH$1)')dnl
define(tmpdbpath, getdbpath(eval(i%NUM_DBPATH+27017)))dnl
')dnl
mongodbServer(i,tmpdbpath)dnl
ifelse(DB_HOSTPATH,,,`dnl
undefine(`tmpdbpath')dnl
')dnl
')

configCenter()
---
ycsbClient()
