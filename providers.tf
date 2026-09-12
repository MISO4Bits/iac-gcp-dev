provider "google" {
  project = var.project_id
  region  = var.region

  # Sin esto, algunas APIs (identitytoolkit, entre otras) rechazan las
  # llamadas hechas con credenciales por defecto de la aplicación (ADC)
  # locales con "requires a quota project, which is not set by default" —
  # incluso después de `gcloud auth application-default set-quota-project`,
  # porque ese comando no es lo que el proveedor de Terraform usa para
  # decidir qué proyecto facturar. Esto sí lo fuerza explícitamente.
  billing_project       = var.project_id
  user_project_override = true
}

provider "google-beta" {
  project = var.project_id
  region  = var.region

  billing_project       = var.project_id
  user_project_override = true
}

# Credencial de la identidad ya autenticada (gcloud ADC en local, Workload
# Identity Federation en pipelines) — se reusa para los providers de
# Kubernetes/Helm/kubectl en vez de pedir una credencial aparte.
data "google_client_config" "default" {}

# Apuntan al cluster que crea modules/gke, en el mismo apply (patrón
# estándar de bootstrap GKE + Argo CD). El equipo destruye y re-crea todo
# por sesión, así que esto siempre es una creación desde cero, no un
# reemplazo en caliente del cluster.
provider "kubernetes" {
  host                   = "https://${module.gke.cluster_endpoint}"
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
}

provider "helm" {
  kubernetes = {
    host                   = "https://${module.gke.cluster_endpoint}"
    cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
    token                  = data.google_client_config.default.access_token
  }

  # Explícito en vez de dejar que el provider use su ruta por defecto (cae
  # en el directorio temporal del sistema operativo si no hay un Helm CLI
  # configurado): una caché ajena a este repo, compartida con cualquier
  # otra cosa que haya usado Helm en la máquina, puede quedar con
  # referencias a repositorios que no son de este proyecto y romper
  # "Unable to locate chart" sin relación aparente con este código.
  repository_cache       = "${path.root}/.terraform/helm-cache"
  repository_config_path = "${path.root}/.terraform/helm-repositories.yaml"
}

provider "kubectl" {
  host                   = "https://${module.gke.cluster_endpoint}"
  cluster_ca_certificate = base64decode(module.gke.cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
  load_config_file       = false
  apply_retry_count      = 5
}
