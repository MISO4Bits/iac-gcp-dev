output "security_policy_name" {
  description = "Nombre de la Cloud Armor Security Policy — es lo que va en spec.default.securityPolicy del GCPBackendPolicy en deploy/apps/api-gateway/."
  value       = google_compute_security_policy.edge.name
}
