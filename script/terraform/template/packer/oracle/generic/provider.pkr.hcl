
packer {
  required_plugins {
    oracle = {
      source  = "github.com/hashicorp/oracle"
      version = "= 1.1.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "= 1.1.1"
    }
  }
}

