variable "argocd_chart_version" {
  description = "Versión del chart Helm argo-cd (argoproj/argo-helm)."
  type        = string
  default     = "10.9.0"
}

variable "deploy_repo_url" {
  description = "URL del repositorio GitOps `deploy` (Kustomize apps/<svc>/base + overlays/{dev,prod}, DI-007)."
  type        = string
  default     = "https://github.com/MISO4Bits/deploy.git"
}

variable "deploy_repo_revision" {
  description = "Rama del repo `deploy` que sigue el root Application."
  type        = string
  default     = "main"
}
