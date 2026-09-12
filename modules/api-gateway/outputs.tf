output "namespace" {
  description = "Namespace donde corre APISIX y su ingress-controller — lo necesita el GatewayProxy en deploy/apps/api-gateway/ para apuntar al Admin API correcto."
  value       = helm_release.apisix.namespace
}

output "admin_service_name" {
  description = "Nombre del Service del Admin API de APISIX (fijo, generado por el chart a partir del nombre del release) — junto con el namespace de arriba, es lo que va en el GatewayProxy de deploy/apps/api-gateway/."
  value       = "${helm_release.apisix.name}-admin"
}
