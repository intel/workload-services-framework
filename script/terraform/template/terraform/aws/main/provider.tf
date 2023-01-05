terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 4.16.0"
    }
  }
}

provider "aws" {
  region = var.region!=null?var.region:replace(var.zone,"/(.*)[a-z]$/","$1")
  profile = var.profile
}
