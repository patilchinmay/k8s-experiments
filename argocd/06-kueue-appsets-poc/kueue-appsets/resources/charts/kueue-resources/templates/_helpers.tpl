{{/*
Expand the name of the chart.
*/}}
{{- define "kueue-resources.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "kueue-resources.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "kueue-resources.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "kueue-resources.labels" -}}
helm.sh/chart: {{ include "kueue-resources.chart" . }}
{{ include "kueue-resources.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "kueue-resources.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kueue-resources.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Render a list of Kueue resourceGroups (used by ClusterQueues and Cohorts).
Limits are emitted whenever they are set to a non-null value, including 0.
A missing or null limit is omitted, which Kueue treats as "no limit".
Usage: {{ include "kueue-resources.resourceGroups" $resourceGroups | nindent 2 }}
*/}}
{{- define "kueue-resources.resourceGroups" -}}
{{- range $i, $rg := . }}
{{- if $i }}{{ "\n" }}{{ end -}}
- coveredResources: {{- $rg.coveredResources | toYaml | nindent 4 }}
  flavors:
  {{- range $rg.flavors }}
  - name: {{ .name }}
    resources:
    {{- range .resources }}
    - name: {{ .name }}
      nominalQuota: {{ .nominalQuota }}
      {{- if not (kindIs "invalid" .borrowingLimit) }}
      borrowingLimit: {{ .borrowingLimit }}
      {{- end }}
      {{- if not (kindIs "invalid" .lendingLimit) }}
      lendingLimit: {{ .lendingLimit }}
      {{- end }}
    {{- end }}
  {{- end }}
{{- end }}
{{- end }}
