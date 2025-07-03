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

{{- define "podAffinity" }}
      affinity:
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: {{ .key }}
                operator: In
                values:
                - {{ .value }}
            topologyKey: "kubernetes.io/hostname"
{{- end }}