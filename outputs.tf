output "project_id" {
  description = "Proyecto de GCP del ambiente dev."
  value       = var.project_id
}

output "region" {
  description = "Región primaria de los recursos de dev."
  value       = var.region
}

output "gke_cluster_name" {
  description = "Nombre del cluster de GKE Autopilot de dev."
  value       = module.gke.cluster_name
}

output "gke_cluster_location" {
  description = "Región del cluster de GKE Autopilot de dev."
  value       = module.gke.cluster_location
}

output "gke_node_service_account_email" {
  description = "Correo de la cuenta de servicio de los nodos del cluster."
  value       = module.gke.node_service_account_email
}

output "argocd_namespace" {
  description = "Namespace donde corre Argo CD."
  value       = module.argocd.namespace
}

output "spanner_core_database" {
  description = "Instancia y base de datos de Spanner de CoreTransaccional."
  value       = "${module.spanner.core_instance_name}/${module.spanner.core_database_name}"
}

output "spanner_services_databases" {
  description = "Instancia compartida de Spanner y sus bases de datos por servicio."
  value       = "${module.spanner.services_instance_name}: ${join(", ", module.spanner.services_database_names)}"
}

output "secret_reader_service_account_emails" {
  description = "Correo de la GSA dedicada a cada secreto — pegar en la anotación `iam.gke.io/gcp-service-account` de la KSA correspondiente en `deploy`."
  value       = module.secrets.reader_service_account_emails
}

output "identity_platform_secret_id" {
  description = "Nombre del secreto en Secret Manager donde va la API key de Identity Platform — subir el valor a mano después de aplicar (ver README)."
  value       = module.secrets.secret_ids["bff-web-secrets"]
}

output "api_gateway_namespace" {
  description = "Namespace donde corre APISIX — lo necesita el GatewayProxy en deploy/apps/api-gateway/."
  value       = module.api_gateway.namespace
}

output "api_gateway_admin_service_name" {
  description = "Nombre del Service del Admin API de APISIX — lo necesita el GatewayProxy en deploy/apps/api-gateway/."
  value       = module.api_gateway.admin_service_name
}

output "api_gateway_admin_key_secret_name" {
  description = "Nombre del Secret con la clave real del Admin API de APISIX — el GatewayProxy en deploy/apps/api-gateway/ la referencia por secretKeyRef."
  value       = module.api_gateway.admin_key_secret_name
}
