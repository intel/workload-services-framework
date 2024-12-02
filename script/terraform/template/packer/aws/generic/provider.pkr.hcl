
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "= 1.3.2"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "= 1.1.1"
    }
  }
}

