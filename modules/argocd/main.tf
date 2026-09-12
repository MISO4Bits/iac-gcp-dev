# Argo CD — un Argo CD por cluster, sin hub central (DI-007, 5.4).
#
# Bootstrap app-of-apps (5.5): este módulo solo instala Argo CD y crea el
# root Application que apunta a `deploy/argocd/`. El ApplicationSet que
# genera el resto de aplicaciones a partir de las carpetas de `deploy` vive
# como manifiesto DENTRO de ese repo (GitOps), no aquí — Argo CD lo aplica
# solo en cuanto sincroniza el root Application.
#
# Fuera de alcance por ahora: External Secrets Operator (5.8). Se agrega
# cuando exista un secreto real que sincronizar — hoy ningún servicio lo
# necesita (EXP-01/EXP-02 usan adaptadores locales, sin secretos externos).

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
}

resource "kubectl_manifest" "root_application" {
  yaml_body = yamlencode({
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "root"
      namespace = "argocd"
    }
    spec = {
      project = "default"

      source = {
        repoURL        = var.deploy_repo_url
        targetRevision = var.deploy_repo_revision
        path           = "argocd"
      }

      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "argocd"
      }

      # Dev: auto-sync con selfHeal + prune (5.6). Prod usa sync manual
      # (5.7) — decisión distinta, se escribe en iac-gcp-prod.
      syncPolicy = {
        automated = {
          selfHeal = true
          prune    = true
        }
      }
    }
  })

  depends_on = [helm_release.argocd]
}
