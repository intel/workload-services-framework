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
Expand to pod affinity
*/}}
{{- define "podAntiAffinity" }}
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: {{ .key }}
                  operator: In
                  values:
                  - {{ .value }}
              topologyKey: "kubernetes.io/hostname"
{{- end }}

{{/*
Expand to node affinity
*/}}
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

{{/*
Expand to nodeAffinityPreferred
*/}}
{{- define "nodeAffinityPreferred" }}
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 20
            preference:
              matchExpressions:
              - key: {{ .key }}
                operator: {{ .operator }}
                values:
                - "{{ .value }}"
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: {{ .key1 }}
                operator: {{ .operator1 }}
                values:
                - "{{ .value1 }}"
            topologyKey: "kubernetes.io/hostname"
{{- end }}

