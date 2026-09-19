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

    # Métricas de recursos de Kubernetes (CPU/memoria por pod, vía cAdvisor
    # del kubelet) — DI-008 seguía sin esto, solo telemetría a nivel de
    # aplicación (OTLP). Necesario para separar, durante EXP-01, si el
    # cuello de botella es CPU en bff-web o en svc-cotizacion, no solo
    # "algo se puso lento". Configuración tomada tal cual del ejemplo
    # oficial del chart para esta versión exacta (charts/k8s-monitoring/
    # docs/examples/features/cluster-metrics/default/values.yaml en el tag
    # k8s-monitoring-4.5.2) — no adivinada. `destinations` vacío en
    # clusterMetrics reusa automáticamente grafanaCloud (ya tiene
    # metrics.enabled=true arriba), no hace falta declarar un destino aparte.
    clusterMetrics = {
      enabled   = true
      collector = "alloy-metrics"
    }

    # kube-state-metrics: el propio ejemplo oficial del chart lo incluye
    # junto con clusterMetrics — sin esto, las métricas de cAdvisor no
    # tienen forma de unirse con metadata del pod (nombre del Deployment,
    # namespace legible, etc.) en los dashboards de Grafana Cloud
    # Kubernetes Monitoring.
    telemetryServices = {
      "kube-state-metrics" = {
        deploy = true
      }
    }

    collectors = {
      alloy-receiver = {
        presets = ["deployment"]
      }
      # Instancia aparte de "alloy-receiver" (que corre como Deployment,
      # solo para recibir OTLP de las apps) — "statefulset" la corre como
      # StatefulSet (1 réplica por defecto) y "clustered" activa el
      # clustering de Alloy, para que pueda repartirse el scraping de
      # cAdvisor de todos los nodos entre réplicas si algún día se escala
      # a más de una (no es un DaemonSet: no necesita un pod por nodo,
      # scrapea el kubelet de cada nodo de forma centralizada).
      alloy-metrics = {
        presets = ["small", "clustered", "statefulset"]
      }
    }
  })]
}
