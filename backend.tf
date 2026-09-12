# Estado remoto en Google Cloud Storage (DI-003). El bucket se crea a mano,
# una sola vez, antes del primer `terraform init` — ver Confluence 4BITS,
# "Crear los buckets de estado de Terraform".
terraform {
  backend "gcs" {
    bucket = "solventa-dev-tfstate"
    prefix = "infra"
  }
}
