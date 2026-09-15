output "namespace" {
  description = "Namespace donde corre Alloy."
  value       = kubernetes_namespace_v1.observability.metadata[0].name
}

output "grafana_cloud_token_secret_id" {
  description = "Nombre del secreto en Secret Manager — subir el valor real a mano después de aplicar (ver README)."
  value       = google_secret_manager_secret.grafana_cloud_token.secret_id
}

output "otlp_receiver_note" {
  description = "El nombre real del Service que expone el receptor OTLP (puerto 4317) solo se conoce después de que el Alloy Operator reconcilie el recurso Alloy — revisar con `kubectl get svc -n observability` y usarlo para BFF_OTEL_EXPORTER_OTLP_ENDPOINT en deploy/."
  value       = "kubectl get svc -n ${kubernetes_namespace_v1.observability.metadata[0].name}"
}
