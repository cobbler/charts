{{/*
Expand the name of the chart.
*/}}
{{- define "cobblerd.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "cobblerd.fullname" -}}
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
{{- define "cobblerd.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cobblerd.labels" -}}
helm.sh/chart: {{ include "cobblerd.chart" . }}
{{ include "cobblerd.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cobblerd.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/name: {{ include "cobblerd.name" . }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "cobblerd.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "cobblerd.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Name of the PersistentVolumeClaim to use for cobblerd's state, whether
chart-managed or user-supplied via persistence.existingClaim.
*/}}
{{- define "cobblerd.pvcName" -}}
{{- default (include "cobblerd.fullname" .) .Values.persistence.existingClaim }}
{{- end }}

{{/*
Regular (non-sidecar, run-to-completion) init container that seeds the
shared "data" volume from the image's own baked-in /etc/cobbler and
/var/lib/cobbler content (the RPM's defaults: users.digest, users.conf,
distro_signatures.json, collections/, etc.) on first start.

Unlike Docker named volumes, Kubernetes volumes (emptyDir or PVC) are never
auto-seeded from the image's content at the mount point -- mounting the
"data" volume's "etc"/"var-lib" subPaths straight over /etc/cobbler and
/var/lib/cobbler, with nothing else, would silently hide all of that and
cobblerd would fail immediately (e.g. "FileNotFoundError:
/var/lib/cobbler/distro_signatures.json"). This container mounts "data" at a
path *other* than /etc/cobbler or /var/lib/cobbler so the image's own
unmounted copies stay visible, and copies whatever the volume is still
missing ("cp -an", no-clobber) before "cobblerd" starts -- idempotent, so it
never overwrites state an operator or cobblerd itself already wrote to a
persistent volume on a later Pod restart.
*/}}
{{- define "cobblerd.seedDataInitContainer" -}}
- name: seed-data
  image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  command: ["sh", "-c"]
  args:
    - |
      set -e
      mkdir -p /mnt/data/etc /mnt/data/var-lib
      cp -an /etc/cobbler/. /mnt/data/etc/
      cp -an /var/lib/cobbler/. /mnt/data/var-lib/
  volumeMounts:
    - name: data
      mountPath: /mnt/data
{{- end }}

{{/*
volumeMounts shared by every "cobblerd" container definition (it runs
identically whether httpApi.enabled puts it in initContainers or
containers): the full set of state directories, subPath-mounted from a
single "data" volume to mirror compose.yml's six named volumes, plus the
two ConfigMap-backed config files layered on top of the "etc" subPath.
*/}}
{{- define "cobblerd.cobblerdVolumeMounts" -}}
- name: data
  mountPath: /etc/cobbler
  subPath: etc
- name: data
  mountPath: /var/lib/cobbler
  subPath: var-lib
- name: data
  mountPath: /srv/www/cobbler
  subPath: webdir
- name: data
  mountPath: /srv/tftpboot
  subPath: tftpboot
- name: data
  mountPath: /etc/cobbler-dhcp
  subPath: cobbler-dhcp
- name: data
  mountPath: /etc/cobbler-dns
  subPath: cobbler-dns
- name: settings
  mountPath: /etc/cobbler/settings.yaml
  subPath: settings.yaml
  readOnly: true
- name: settings
  mountPath: /etc/cobbler/logging_config.conf
  subPath: logging_config.conf
  readOnly: true
{{- end }}
