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
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: "role"
                operator: In
                values:
                {{- range $val := . }}
                - "{{ $val }}"
                {{- end }}
            topologyKey: "kubernetes.io/hostname"
{{- end }}
{{- define "podAffinity" }}
        podAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          {{- range $val := . }}
          - weight: 20
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: "role"
                  operator: In
                  values:
                  - "{{ $val }}"
              topologyKey: "kubernetes.io/hostname"
          {{- end }}
{{- end }}
{{/*
Expand to node anti affinity to HUGEPAGE
*/}}
{{- define "nodeAffinity" }}
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 10
            preference:
              matchExpressions:
              - key: "HAS-SETUP-HUGEPAGE-1048576kB-2"
                operator: NotIn
                values:
                - "yes"
{{- end }}
