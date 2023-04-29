terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = ">= 4.32.0"
    }
  }
}

locals {
  region = var.region!=null?var.region:replace(var.zone,"/([a-z0-9]+-[a-z0-9]+)-.*/","$1")
  project_id = var.project_id != null? var.project_id: jsondecode(file("~/.config/gcloud/application_default_credentials.json"))["quota_project_id"]
}

provider "google" {
  region = local.region
  zone = var.zone
  project = local.project_id
}
