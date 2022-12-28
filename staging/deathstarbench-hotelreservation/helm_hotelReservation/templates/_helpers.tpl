{{/*
Expand the name of the chart.
*/}}
{{- define "hotelres.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 43 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 43 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "hotelres.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 43 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 43 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 43 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "hotelres.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 43 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "hotelres.labels" -}}
helm.sh/chart: {{ include "hotelres.chart" . }}
{{ include "hotelres.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
death-star-project: hotel-res
{{- end }}

{{/*
Selector labels
*/}}
{{- define "hotelres.selectorLabels" -}}
app.kubernetes.io/name: {{ include "hotelres.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "hotelres.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "hotelres.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
special string indicating value is not found
*/}}
{{- define "hotelres.notfound" -}}
{{- "hotelres.get.internal-notfound-6bf08c82" }}
{{- end }}

{{/*
Get the json encoded value of a optional value
*/}}
{{- define "hotelres.get.internal" -}}
  {{- $mapToCheck := index . 0 }}
  {{- $keyToFind := index . 1 }}
  {{- $keySet := (splitList "." $keyToFind) }}
  {{- $firstKey := first $keySet }}
  {{- if hasKey $mapToCheck $firstKey }}
    {{- if eq 1 (len $keySet) -}}{{/* final key element */}}
      {{- index $mapToCheck $firstKey | toJson }}
    {{- else }}{{/* recusive to find next level key */}}
      {{- include "hotelres.get.internal" (list (index $mapToCheck $firstKey) (join "." (rest $keySet))) }}
    {{- end }}
  {{- else }}{{/* key is not found, return special string indicating value is not found */}}
    {{- include "hotelres.notfound" . }}
  {{- end }}
{{- end }}


{{/*
Get optional string value of a subMap or return the global value
Usage:
  include "hotelres.get" (list <mapToCheck> <subMapKey> <keyToFind> [encode json/yaml])
  e.g.
    $servicetype := include "hotelres.get" (list .Values "geo" "service.type" )
*/}}
{{- define "hotelres.get" -}}
  {{- $mapToCheck := index . 0 }}
  {{- $subMapKey := index . 1 }}
  {{- $keyToFind := index . 2 }}
  {{- $encode := "string" }}
  {{- if gt (len .) 3 }}
    {{- $encode = index . 3 }}
  {{- end }}
  {{- $ret := include "hotelres.notfound" . }}
  {{- if hasKey $mapToCheck $subMapKey }}
    {{- $ret = include "hotelres.get.internal" (list (index $mapToCheck $subMapKey) $keyToFind) }}
  {{- end }}
  {{- if eq $ret (include "hotelres.notfound" .) }}
    {{- $ret = include "hotelres.get.internal" (list $mapToCheck $keyToFind) }}
  {{- end }}
  {{- if eq $ret (include "hotelres.notfound" .) }}
    {{- "" }}
  {{- else if eq $encode "json" }}
    {{- $ret }}
  {{- else if eq $encode "yaml" }}
    {{- mustFromJson $ret | toYaml }}
  {{- else }}
    {{- mustFromJson $ret | toString }}
  {{- end }}
{{- end }}


{{/*
Check if hugepage is needed
Usage:
  include "hotelres.needhugepage" (list <mapToCheck> <subMapKey>)
  e.g.
    if include "hotelres.needhugepage" (list .Values "geo")
*/}}
{{- define "hotelres.needhugepage" -}}
  {{- $mapToCheck := index . 0 }}
  {{- $subMapKey := index . 1 }}
  {{- if (include "hotelres.get" (list $mapToCheck $subMapKey "resources.limits")) }}
    {{- with (include "hotelres.get" (list $mapToCheck $subMapKey "resources.limits" "json") | mustFromJson) }}
      {{- if hasKey . "hugepages-2Mi" }}
        {{- "True" }}
      {{- end }}
        {{- "" }}
    {{- end }}
  {{- end }}
{{- end }}
