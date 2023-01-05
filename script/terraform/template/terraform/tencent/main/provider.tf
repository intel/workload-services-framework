terraform {
  required_providers {
    tencentcloud = {
      source = "tencentcloudstack/tencentcloud"
    }
  }
}

locals {
  credentials = jsondecode(file("~/.tccli/default.credential"))
}

provider "tencentcloud" {
  secret_id = var.secret_id != null?var.secret_id:local.credentials["secretId"]
  secret_key = var.secret_key != null?var.secret_key:local.credentials["secretKey"]
  region = var.region!=null?var.region:replace(var.zone,"/([a-z][a-z]-[a-z]+)-[0-9]?$/","$1")
}

