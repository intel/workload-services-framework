
packer {
  required_plugins {
    alicloud = {
      source  = "github.com/hashicorp/alicloud"
      version = "= 1.1.1"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "= 1.1.1"
    }
  }
}

