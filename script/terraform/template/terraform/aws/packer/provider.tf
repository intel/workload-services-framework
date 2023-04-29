terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 4.16.0"
    }
  }
}

locals {
  region = var.region!=null?var.region:replace(var.zone,"/(.*)[a-z]$/","$1")
}

provider "aws" {
  region = local.region
  profile = var.profile

  default_tags {
    tags = merge(var.common_tags, {
      owner: var.owner
    })
  }
}
