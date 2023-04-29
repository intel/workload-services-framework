include(../../template/config.m4)
include(template/mongodb-server.yaml.m4)
include(template/ycsb-client.yaml.m4)
include(template/stress-ng.yaml.m4)
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
')

# generate N pair of client-server, where N=CLIENT_SERVER_PAIR
loop(`i', `27017', eval(27017+CLIENT_SERVER_PAIR-1), mongodbServer(`i'))

stressNg()
---
configCenter()
---
ycsbClient()