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

{{- define "brokerServerList" }}
  {{- $loop := (int .BROKER_SERVER_NUM) -}}
  {{- range $i := until $loop }}
    {{- print "zookeeper-kafka-server-" $i ".zookeeper-kafka-server-service:9092"  }}
    {{- if lt $i (sub $loop 1) }}
      {{- print "," }}
    {{- end }}
  {{- end }} 
{{- end }}

{{- define "zkServerList" }}
  {{- $loop := (int .BROKER_SERVER_NUM) -}}
  {{- range $i := until $loop }}
    {{- print "zookeeper-kafka-server-" $i ".zookeeper-kafka-server-service:2181"  }}
    {{- if lt $i (sub $loop 1) }}
      {{- print "," }}
    {{- end }}
  {{- end }}   
{{- end }}

{{- define "IMAGESUFFIX" }}
  {{- if eq .IMAGEARCH "linux/amd64" }}
    {{- print ""  }}
  {{- else }}
    {{- regexReplaceAll "(.*)/(.*)" .IMAGEARCH "-${2}" }}
  {{- end }}
{{- end }}
