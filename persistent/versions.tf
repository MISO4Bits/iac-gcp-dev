terraform {
  required_version = ">= 1.7.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.2"
    }
    # La app de Firebase (BITS-229) la declara el proveedor beta, como en la raíz.
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 8.2"
    }
  }
}
