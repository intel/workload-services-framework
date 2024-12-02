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
              - key: "app"
                operator: In
                values:
                {{- range $val := . }}
                - "{{ $val }}"
                {{- end }}
            topologyKey: "kubernetes.io/hostname"
{{- end }}
{{- define "podAffinity" }}
        podAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: "app"
                operator: In
                values:
                {{- range $val := . }}
                - "{{ $val }}"
                {{- end }}
            topologyKey: "kubernetes.io/hostname"
{{- end }}
