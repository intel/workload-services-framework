
locals {
  os_image_publisher = {
    "ubuntu2004": "Canonical",
    "ubuntu2204": "Canonical",
    "debian11"  : "Debian",
  }
  os_image_offer = {
    "ubuntu2004": "0001-com-ubuntu-server-focal",
    "ubuntu2204": "0001-com-ubuntu-server-jammy",
    "debian11"  : "debian-11",
  }
  os_image_sku = {
    "ubuntu2004": "20_04-lts",
    "ubuntu2204": "22_04-lts",
    "debian11"  : "11",
  }
  os_image_user = {
    "ubuntu2004": "tfu",
    "ubuntu2204": "tfu",
    "debian11"  : "tfu",
  }
}

