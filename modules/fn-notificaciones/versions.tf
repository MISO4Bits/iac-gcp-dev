terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.2"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 8.2"
    }
  }
}
