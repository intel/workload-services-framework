
locals {
  operating_systems = {
    "ubuntu2004" = "Canonical Ubuntu"
    "ubuntu2204" = "Canonical Ubuntu"
    "ubuntu2404" = "Canonical Ubuntu"
  }
  operating_system_versions = {
    "ubuntu2004" = "20.04"
    "ubuntu2204" = "22.04"
    "ubuntu2404" = "24.04"
  }
  os_image_user = {
    "ubuntu2004": "ubuntu",
    "ubuntu2204": "ubuntu",
    "ubuntu2404": "ubuntu",
  }
}

