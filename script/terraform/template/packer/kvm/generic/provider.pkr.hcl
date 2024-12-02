
packer {
  required_plugins {
    libvirt = {
      source  = "github.com/thomasklein94/libvirt"
      version = "= 0.5.0"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = "= 1.1.1"
    }
    external = {
      source = "github.com/joomcode/external"
      version = "= 0.0.2"
    }
  }
}
