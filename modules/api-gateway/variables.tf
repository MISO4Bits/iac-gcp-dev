variable "namespace" {
  description = "Namespace donde corre APISIX y su ingress-controller."
  type        = string
  default     = "api-gateway"
}

variable "apisix_chart_version" {
  description = "Versión del chart Helm apisix/apisix (apache/apisix-helm-chart)."
  type        = string
  default     = "2.17.0"
}
