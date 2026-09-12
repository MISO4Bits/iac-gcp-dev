output "cluster_name" {
  description = "Nombre del cluster de GKE Autopilot."
  value       = google_container_cluster.this.name
}

output "cluster_location" {
  description = "Región del cluster de GKE Autopilot."
  value       = google_container_cluster.this.location
}

output "cluster_endpoint" {
  description = "Endpoint del plano de control del cluster, para configurar el provider de Kubernetes/Helm (bootstrap de Argo CD, DI-007)."
  value       = google_container_cluster.this.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Certificado CA del cluster, codificado en base64, para configurar el provider de Kubernetes/Helm."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "node_service_account_email" {
  description = "Correo de la cuenta de servicio de los nodos administrados por Autopilot."
  value       = google_service_account.gke_nodes.email
}
