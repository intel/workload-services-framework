define(`IMAGENAME',`defn(`REGISTRY')regexp(esyscmd(`im="$(echo|head -n 2 $1 2>/dev/null|grep -E "^# "|tail -n 1|cut -f2 -d" ")" && test -z "$im" && echo "$1" || echo "$im"'),`\(.*\)',`\1')`'ifelse(defn(`IMAGEARCH'),`linux/amd64',,-patsubst(defn(`IMAGEARCH'),`.*/',`'))`'defn(`RELEASE')')dnl
define(`IMAGEPOLICY',`ifelse(defn(`REGISTRY'),`',`IfNotPresent',$1)')dnl
define(`PODANTIAFFINITY',`affinity:
ifelse($#,3,`      ',$4)  podAntiAffinity:
ifelse($1,`preferred',`dnl
ifelse($#,3,`      ',$4)    preferredDuringSchedulingIgnoredDuringExecution:
ifelse($#,3,`      ',$4)    - weight: 1
ifelse($#,3,`      ',$4)      podAffinityTerm:
ifelse($#,3,`      ',$4)        labelSelector:
ifelse($#,3,`      ',$4)          matchExpressions:
ifelse($#,3,`      ',$4)          - key: $2
ifelse($#,3,`      ',$4)            operator: In
ifelse($#,3,`      ',$4)            values:
ifelse($#,3,`      ',$4)            - $3
ifelse($#,3,`      ',$4)        topologyKey: "kubernetes.io/hostname"
',`dnl
ifelse($#,3,`      ',$4)    requiredDuringSchedulingIgnoredDuringExecution:
ifelse($#,3,`      ',$4)    - labelSelector:
ifelse($#,3,`      ',$4)        matchExpressions:
ifelse($#,3,`      ',$4)        - key: $2
ifelse($#,3,`      ',$4)          operator: In
ifelse($#,3,`      ',$4)          values:
ifelse($#,3,`      ',$4)          - $3
ifelse($#,3,`      ',$4)      topologyKey: "kubernetes.io/hostname"
')')dnl
define(`PODAFFINITY',`affinity:
ifelse($#,3,`      ',$4)  podAffinity:
ifelse($1,`preferred',`dnl
ifelse($#,3,`      ',$4)    preferredDuringSchedulingIgnoredDuringExecution:
ifelse($#,3,`      ',$4)    - weight: 1
ifelse($#,3,`      ',$4)      podAffinityTerm:
ifelse($#,3,`      ',$4)        labelSelector:
ifelse($#,3,`      ',$4)          matchExpressions:
ifelse($#,3,`      ',$4)          - key: $2
ifelse($#,3,`      ',$4)            operator: In
ifelse($#,3,`      ',$4)            values:
ifelse($#,3,`      ',$4)            - $3
ifelse($#,3,`      ',$4)        topologyKey: "kubernetes.io/hostname"
',`dnl
ifelse($#,3,`      ',$4)    requiredDuringSchedulingIgnoredDuringExecution:
ifelse($#,3,`      ',$4)    - labelSelector:
ifelse($#,3,`      ',$4)        matchExpressions:
ifelse($#,3,`      ',$4)        - key: $2
ifelse($#,3,`      ',$4)          operator: In
ifelse($#,3,`      ',$4)          values:
ifelse($#,3,`      ',$4)          - $3
ifelse($#,3,`      ',$4)      topologyKey: "kubernetes.io/hostname"
')')dnl
define(`NODEAFFINITY',`affinity:
ifelse($#,3,`      ',$4)  nodeAffinity:
ifelse($1,`preferred',`dnl
ifelse($#,3,`      ',$4)    preferredDuringSchedulingIgnoredDuringExecution:
ifelse($#,3,`      ',$4)    - weight: 1
ifelse($#,3,`      ',$4)      preference:
ifelse($#,3,`      ',$4)        matchExpressions:
ifelse($#,3,`      ',$4)        - key: $2
ifelse($#,3,`      ',$4)          operator: In
ifelse($#,3,`      ',$4)          values:
ifelse($#,3,`      ',$4)          - $3
',`dnl
ifelse($#,3,`      ',$4)    requiredDuringSchedulingIgnoredDuringExecution:
ifelse($#,3,`      ',$4)      nodeSelectorTerms:
ifelse($#,3,`      ',$4)      - matchExpressions:
ifelse($#,3,`      ',$4)        - key: $2
ifelse($#,3,`      ',$4)          operator: In
ifelse($#,3,`      ',$4)          values:
ifelse($#,3,`      ',$4)          - $3
')')dnl
define(`loop',`ifelse(eval($2<=$3),1,`pushdef(`$1',$2)$4`'loop(`$1',incr($2),$3,`$4')popdef(`$1')')')dnl
