# Mismo bucket que la raíz del repo, prefijo distinto — un estado
# completamente separado, para que un `terraform destroy` en la raíz jamás
# pueda tocar esto por accidente (son dos estados distintos, no una carpeta
# con recursos "protegidos" dentro del mismo).
terraform {
  backend "gcs" {
    bucket = "solventa-dev-tfstate"
    prefix = "persistent"
  }
}
