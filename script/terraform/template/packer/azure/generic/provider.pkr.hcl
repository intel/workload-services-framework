
packer {
  required_plugins {
    azure = {
      source  = "github.com/hashicorp/azure"
      version = "= 2.1.3"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "= 1.1.1"
    }
  }
}

