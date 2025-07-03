{{/*
Expand to the image pull policy.
*/}}
{{- define "imagepolicy" }}
{{- if ne .REGISTRY "" }}
{{- "Always" }}
{{- else }}
{{- "IfNotPresent" }}
{{- end }}
{{- end }}

{{/*
Expand to the image .
*/}}
{{- define "hadoop-config-volumeMounts" -}}
- name: hadoop-configmap-vol1
  mountPath: /usr/local/hadoop/etc/hadoop/mapred-site.xml_example
  subPath: mapred-site.xml
- name: hadoop-configmap-vol2
  mountPath: /usr/local/hadoop/etc/hadoop/yarn-site.xml_example
  subPath: yarn-site.xml
- name: hadoop-configmap-vol3
  mountPath: /usr/local/hadoop/etc/hadoop/workers
  subPath: workers
{{- end -}}

{{- define "hadoop-config-volumes" -}}
- name: hadoop-configmap-vol1
  configMap:
    name: hadoop-file-conf
    items:
      - key: mapred-site.xml
        path: mapred-site.xml
- name: hadoop-configmap-vol2
  configMap:
    name: hadoop-file-conf
    items:
      - key: yarn-site.xml
        path: yarn-site.xml
- name: hadoop-configmap-vol3
  configMap:
    name: hadoop-file-conf
    items:
      - key: workers
        path: workers
{{- end -}}

{{- define "hadoopENV" }}
env:
- name: HADOOP_NODE_TYPE
  value: {{ .value }}
- name: HDFS_MASTER_SERVICE
  valueFrom:
    configMapKeyRef:
      name: hadoop-file-conf
      key: HDFS_MASTER_SERVICE
- name: HDOOP_YARN_MASTER
  valueFrom:
    configMapKeyRef:
      name: hadoop-file-conf
      key: HDOOP_YARN_MASTER
{{- end -}}

{{- define "nodeAffinity" }}
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            preference:
              matchExpressions:
              - key: {{ .nkey }}
                operator: In
                values:
                - {{ .nvalue }}
{{- end }}


{{- define "podAntiAffinity" }}
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: name
                  operator: In
                  values:
                  - hibench-cluster
              topologyKey: "kubernetes.io/hostname"
{{- end }}
