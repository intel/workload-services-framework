
locals {
  os_image_user = {
    "ubuntu2004": "tfu",
    "ubuntu2204": "tfu",
    "debian11"  : "tfu",
  }

  os_image_family = {
    "ubuntu2204": "ubuntu-2204-lts",
    "ubuntu2004": "ubuntu-2004-lts",
    "debian11"  : "debian-11",
  }
}

