output "bff_web_static_ip" {
  description = "IP estática reservada para el Gateway de bff-web — usar este valor en el registro DNS de bff-web.dev.solventa4bits.com (a mano en Squarespace, DI-010)."
  value       = google_compute_global_address.bff_web.address
}

output "bff_web_static_ip_name" {
  description = "Nombre del recurso de IP estática — es lo que va en spec.addresses[].value (NamedAddress) del Gateway en deploy/apps/bff-web/base/gateway.yaml."
  value       = google_compute_global_address.bff_web.name
}

output "bff_web_certificate_map_name" {
  description = "Nombre del CertificateMap — es lo que va en la anotación networking.gke.io/certmap del Gateway en deploy/apps/bff-web/base/gateway.yaml."
  value       = google_certificate_manager_certificate_map.bff_web.name
}

output "bff_web_certificate_status" {
  description = "Estado del certificado (PROVISIONING hasta que el DNS apunte a la IP y un Gateway real la sirva; luego ACTIVE)."
  value       = google_certificate_manager_certificate.bff_web.id
}
