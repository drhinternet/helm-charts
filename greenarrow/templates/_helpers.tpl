{{- define "ramdisk_config" -}}
{{- $unitDict := (dict "Ki" 1024 "Mi" 1048576 "Gi" 1073741824) -}}
{{- $sizeRaw := .size -}}
{{- $sizeNumber := regexFind "^\\d+" $sizeRaw | int -}}
{{- $sizeUnit := regexFind "[a-zA-Z]+$" $sizeRaw -}}
{{- $sizeBytes := mul $sizeNumber (get $unitDict $sizeUnit) -}}
{{- $messages := max 100 (mul 100 (round (div $sizeBytes 26214400) 0)) -}}
messages: {{ $messages }}
concurrency: {{ max 1000 (min 40000 (mul (.batch_size | int) $messages)) }}
inodes: {{ max 16000 (add 8000 (mul $messages 50)) (div $sizeBytes 16384) }}
size: {{ div $sizeBytes 1048576 }}
batch_size: {{ .batch_size | int }}
{{- end -}}

{{- define "persistent_volume_claims" -}}

{{- if .Values.drainFallbackVolumeClaim -}}
drainFallbackVolumeClaim: {{ .Values.drainFallbackVolumeClaim | quote }}
{{ else if .Values.amazonEfsFilesystemId -}}
drainFallbackVolumeClaim: {{ printf "%s-fallback" .Release.Name | quote }}
{{ else -}}
drainFallbackVolumeClaim: null
{{ end -}}

{{- if .Values.httpsTlsCertVolumeClaim -}}
httpsTlsCertVolumeClaim: {{ .Values.httpsTlsCertVolumeClaim | quote }}
{{ else if .Values.amazonEfsFilesystemId -}}
httpsTlsCertVolumeClaim: {{ printf "%s-tls" .Release.Name | quote }}
{{ else -}}
httpsTlsCertVolumeClaim: null
{{ end -}}

{{- if .Values.prometheusVolumeClaim -}}
prometheusVolumeClaim: {{ .Values.prometheusVolumeClaim | quote }}
{{ else -}}
prometheusVolumeClaim: null
{{ end -}}

amazonEfsFilesystemId: {{ .Values.amazonEfsFilesystemId | quote }}
amazonEfsStorageClass: {{ printf "%s-efs-storage-class" .Release.Name | quote }}
amazonEfsDrainFallbackVolumeClaim: {{ printf "%s-fallback" .Release.Name | quote }}
amazonEfsHttpsTlsCertVolumeClaim: {{ printf "%s-tls" .Release.Name | quote }}
amazonEfsPrometheusVolumeClaim: {{ printf "%s-prometheus" .Release.Name | quote }}
drainFallbackPath: "/mnt/greenarrow-fallback"
drainFallbackVolumeName: "fallback-volume"
httpsTlsCertPath: "/mnt/tls"
httpsTlsCertVolumeName: "tls-volume"

{{- end }}
