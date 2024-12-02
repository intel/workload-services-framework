
locals {
  os_image_user = {
    "ubuntu2004": "tfu",
    "ubuntu2204": "tfu",
    "ubuntu2404": "tfu",
    "debian11"  : "tfu",
    "debian12"  : "tfu",
    "rhel9"     : "tfu",
  }

  os_image_family = {
    "ubuntu2404": "ubuntu-2404-lts",
    "ubuntu2204": "ubuntu-2204-lts",
    "ubuntu2004": "ubuntu-2004-lts",
    "debian11"  : "debian-11",
    "debian12"  : "debian-12",
    "rhel9"     : "rhel-9",
  }
}

