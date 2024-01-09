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
Expand to the image.
*/}}
{{- define "config-volumeMounts" -}}
- name: hadoop-configmap-vol1
  mountPath: /usr/local/hadoop/etc/hadoop/workers
  subPath: workers
{{- end -}}

{{- define "config-volumes" -}}
- name: hadoop-configmap-vol1
  configMap:
    name: conf-file
    items:
      - key: workers
        path: workers
{{- end -}}

{{/*
Expand to pod affinity
*/}}
{{- define "podAntiAffinity" }}
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - hadoop-cluster
              topologyKey: "kubernetes.io/hostname"
{{- end }}


{{- define "nodeAffinity" }}
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            preference:
              matchExpressions:
              - key: {{ .nkey }}
                operator: In
                values:
                - {{ .nvalue }}
{{- end }}
