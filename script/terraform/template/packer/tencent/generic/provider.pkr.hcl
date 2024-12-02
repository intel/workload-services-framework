
packer {
  required_plugins {
    tencentcloud = {
      source  = "github.com/hashicorp/tencentcloud"
      version = "= 1.2.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "= 1.1.1"
    }
  }
}

