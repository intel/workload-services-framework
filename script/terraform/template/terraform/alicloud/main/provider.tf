terraform {
  required_providers {
    alicloud = {
      source = "aliyun/alicloud"
    }
  }
}

provider "alicloud" {
  region = var.region!=null?var.region:(var.zone=="cn-hangzhou"?var.zone:length(regexall("^cn-",var.zone))>0?replace(var.zone,"/-[a-z0-9]*$/",""):replace(var.zone,"/.$/",""))
  profile = var.profile
}

