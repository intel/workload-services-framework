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

{{/*
Expand to podAffinity
*/}}
{{- define "podAffinity" }}
      affinity:
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 20
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: {{ .key }}
                  operator: {{ .operator }}
                  values:
                  - "{{ .value }}"
              topologyKey: "kubernetes.io/hostname"
{{- end }}

{{/*
Expand to podAntiAffinity
*/}}
{{- define "podAntiAffinity" }}
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: {{ .key }}
                operator: {{ .operator }}
                values:
                - "{{ .value }}"
            topologyKey: "kubernetes.io/hostname"
{{- end }}
