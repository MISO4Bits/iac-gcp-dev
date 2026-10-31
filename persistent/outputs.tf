output "edge_static_ip" {
  description = "IP estática reservada para el punto de entrada único del ambiente (API Gateway/APISIX) — usar este valor en el registro DNS de dev.solventa4bits.com (a mano en Squarespace, DI-010)."
  value       = google_compute_global_address.edge.address
}

output "edge_static_ip_name" {
  description = "Nombre del recurso de IP estática — es lo que va en spec.addresses[].value (NamedAddress) del Gateway en deploy/apps/api-gateway/base/gateway.yaml."
  value       = google_compute_global_address.edge.name
}

output "edge_certificate_map_name" {
  description = "Nombre del CertificateMap — es lo que va en la anotación networking.gke.io/certmap del Gateway en deploy/apps/api-gateway/base/gateway.yaml."
  value       = google_certificate_manager_certificate_map.edge.name
}

output "edge_certificate_status" {
  description = "Estado del certificado (PROVISIONING hasta que el DNS apunte a la IP y un Gateway real la sirva; luego ACTIVE)."
  value       = google_certificate_manager_certificate.edge.id
}

output "portal_static_ip" {
  description = "IP estática del portal — registro A de solventa4bits.com (y de www) en Squarespace."
  value       = google_compute_global_address.portal.address
}

output "portal_bucket" {
  description = "Bucket donde el CI de fe-web publica el build (gs://<nombre>)."
  value       = google_storage_bucket.portal.name
}

output "firebase_android_app_id" {
  description = "ID de la app Android en Firebase (avisos push, BITS-229)."
  value       = google_firebase_android_app.movil.app_id
}

output "google_services_json" {
  description = "Contenido de google-services.json para fe-mobile (guardar en fe-mobile/app/google-services.json). `terraform output -raw google_services_json`."
  value       = base64decode(data.google_firebase_android_app_config.movil.config_file_contents)
}
