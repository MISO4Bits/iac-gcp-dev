output "namespace" {
  description = "Namespace donde corre Argo CD."
  value       = helm_release.argocd.namespace
}
