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
Expand to nodeAffinity
*/}}
{{- define "nodeAffinity" }}
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: {{ .key }}
                operator: {{ .operator }}
                values:
                - "{{ .value }}"
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