# Observabilidad del ambiente (DI-008): Grafana Alloy dentro del cluster,
# reenviando trazas/métricas/logs hacia Grafana Cloud (LGTM gestionado).
#
# El token de acceso de Grafana Cloud NUNCA se pasa como valor plano en
# Terraform. Se crea el contenedor vacío en Secret Manager (mismo patrón que
# la API key de Identity Platform, ver modules/secrets) — el valor real se
# sube a mano con `gcloud secrets versions add` (ver README). Alloy necesita
# un Secret NATIVO de Kubernetes, no un archivo montado — el add-on de
# Secret Manager de GKE que usan los demás servicios solo monta archivos, no
# sincroniza a un Secret de Kubernetes (limitación real, ya documentada en
# la decisión de modules/secrets). Por eso aquí se lee la última versión del
# secreto vía data source y se crea un Secret de Kubernetes aparte,
# específicamente para lo que este chart necesita.
resource "google_secret_manager_secret" "grafana_cloud_token" {
  project   = var.project_id
  secret_id = "grafana-cloud-otlp-token"

  replication {
    auto {}
  }
}

data "google_secret_manager_secret_version" "grafana_cloud_token" {
  project = var.project_id
  secret  = google_secret_manager_secret.grafana_cloud_token.secret_id

  depends_on = [google_secret_manager_secret.grafana_cloud_token]
}

resource "kubernetes_namespace_v1" "observability" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_secret_v1" "grafana_cloud_otlp" {
  metadata {
    name      = "grafana-cloud-otlp"
    namespace = kubernetes_namespace_v1.observability.metadata[0].name
  }

  data = {
    # El chart siempre lee AMBAS credenciales desde el Secret referenciado
    # cuando se le da un `secret.name` — el valor literal de auth.username
    # en los values de Helm se ignora por completo en ese caso (encontrado
    # en vivo: el pod de Alloy fallaba con "no credential source provided"
    # hasta agregar esta clave). El Instance ID no es secreto, pero vive
    # aquí porque el propio mecanismo del chart lo exige así.
    username = var.grafana_cloud_instance_id
    token    = data.google_secret_manager_secret_version.grafana_cloud_token.secret_data
  }
}

# Chart grafana/k8s-monitoring (4.x): ya no despliega Alloy directamente,
# instala el Alloy Operator + un recurso personalizado (CRD `Alloy`) que el
# operador reconcilia para crear el Deployment/Service reales — confirmado
# con `helm template` antes de escribir esto (no había forma de saberlo solo
# leyendo el values.yaml). El nombre real del Service que exponen los
# receptores solo se conoce después de aplicar de verdad (ver README).
resource "helm_release" "k8s_monitoring" {
  name      = "k8s-monitoring"
  namespace = kubernetes_namespace_v1.observability.metadata[0].name

  depends_on = [kubernetes_secret_v1.grafana_cloud_otlp]

  repository = "https://grafana.github.io/helm-charts"
  chart      = "k8s-monitoring"
  version    = var.chart_version

  values = [yamlencode({
    cluster = {
      name = var.cluster_name
    }

    destinations = {
      grafanaCloud = {
        type = "otlp"
        url  = var.grafana_cloud_otlp_endpoint
        # Grafana Cloud solo acepta HTTP en este endpoint — el chart usa
        # gRPC por defecto para destinos OTLP, hay que fijarlo a mano o
        # falla en silencio contra el gateway real.
        protocol = "http"
        # username/password se leen del Secret referenciado abajo (claves
        # "username"/"token") — un auth.username literal aquí se ignora en
        # silencio cuando se especifica `secret.name`, confirmado en vivo.
        auth = {
          type        = "basic"
          passwordKey = "token"
        }
        secret = {
          create    = false
          name      = kubernetes_secret_v1.grafana_cloud_otlp.metadata[0].name
          namespace = kubernetes_namespace_v1.observability.metadata[0].name
        }
        metrics = { enabled = true }
        logs    = { enabled = true }
        traces  = { enabled = true }
      }
    }

    # Receptor OTLP para las aplicaciones (bff-web, svc-core,
    # svc-cotizacion) — puerto 4317, gRPC (el default de los SDK de
    # OpenTelemetry). Sin destinations explícito: como solo hay un destino
    # capaz de recibir métricas/logs/trazas (grafanaCloud), el chart lo usa
    # automáticamente.
    applicationObservability = {
      enabled   = true
      collector = "alloy-receiver"
      receivers = {
        otlp = {
          grpc = { enabled = true }
        }
      }
    }

    collectors = {
      alloy-receiver = {
        presets = ["deployment"]
      }
    }
  })]
}
