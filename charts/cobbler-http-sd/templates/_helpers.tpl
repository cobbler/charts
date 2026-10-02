{{/*
Expand the name of the chart.
*/}}
{{- define "cobbler-http-sd.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cobbler-http-sd.fullname" -}}
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
{{- define "cobbler-http-sd.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cobbler-http-sd.labels" -}}
helm.sh/chart: {{ include "cobbler-http-sd.chart" . }}
{{ include "cobbler-http-sd.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cobbler-http-sd.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/name: {{ include "cobbler-http-sd.name" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cobbler-http-sd.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cobbler-http-sd.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the Secret carrying servers.json - either the chart's own (when secrets.create is
true) or the externally-provisioned one named by .Values.configSecretName.
*/}}
{{- define "cobbler-http-sd.configSecretName" -}}
{{- if .Values.secrets.create }}
{{- include "cobbler-http-sd.fullname" . }}
{{- else }}
{{- .Values.configSecretName }}
{{- end }}
{{- end }}
