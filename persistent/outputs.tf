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
