# Bucket privado de las fotos de identidad de los clientes (cédula por ambas caras y
# selfie, BITS-275). Son datos personales: sin acceso público, sin URL públicas, y solo
# svc-core puede leerlas o escribirlas.

resource "google_storage_bucket" "evidencias" {
  project  = var.project_id
  name     = "${var.project_id}-evidencias"
  location = var.region

  uniform_bucket_level_access = true
  # Aunque algún permiso quede mal, el bucket no se puede hacer público.
  public_access_prevention = "enforced"

  # En dev, los metadatos de las evidencias viven en la base SQLite del pod (efímera): al
  # destruir el clúster se pierden y las fotos quedarían huérfanas. Con `true`, el
  # `terraform destroy` de cada sesión también las borra. En prod debe ser `false`.
  force_destroy = var.force_destroy

  # Sin versionado ni regla de purga: repetir una foto crea una evidencia nueva y las
  # aceptadas se conservan mientras viva la póliza que las referencia. El plazo de purga
  # de las que nunca llegan a una póliza está por definir con cumplimiento.
}

# Mínimo privilegio: leer, crear y borrar objetos de este bucket, no administrarlo ni
# listar otros. La cuenta de servicio es la de svc-core: una cuenta de servicio de
# Kubernetes solo se federa con una cuenta de servicio de GCP a la vez, por eso es la
# misma con la que svc-core publica en Pub/Sub.
resource "google_storage_bucket_iam_member" "svc_core" {
  bucket = google_storage_bucket.evidencias.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${var.service_account_email}"
}
