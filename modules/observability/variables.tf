variable "project_id" {
  description = "ID del proyecto de GCP."
  type        = string
}

variable "namespace" {
  description = "Namespace donde corre Alloy (Operator + instancias)."
  type        = string
  default     = "observability"
}

variable "cluster_name" {
  description = "Nombre del cluster, usado como etiqueta en toda la telemetría (DI-008)."
  type        = string
  default     = "solventa-dev"
}

variable "chart_version" {
  description = "Versión del chart Helm grafana/k8s-monitoring."
  type        = string
  default     = "4.5.2"
}

variable "grafana_cloud_otlp_endpoint" {
  description = "Endpoint OTLP del stack de Grafana Cloud (Grafana Cloud → tu stack → OpenTelemetry). Grafana Cloud solo acepta HTTP en este endpoint, no gRPC."
  type        = string
}

variable "grafana_cloud_instance_id" {
  description = "Instance ID del stack de Grafana Cloud — es el \"usuario\" en la autenticación básica hacia el endpoint OTLP. No es secreto."
  type        = string
}
