{{/*
Expand to the image pull policy.
*/}}
{{- define "imagepolicy" }}
{{- "IfNotPresent" }}
{{- end }}

{{/*
Expand to affinity with podAntiAffinity
*/}}
{{- define  "podAntiAffinity" }}
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: {{ .key }}
          operator: In
          values: {{ splitList "|" .values }}
      topologyKey: "kubernetes.io/hostname"
{{- end }}
