
locals {
  os_image_publisher = {
    "ubuntu2004": "Canonical",
    "ubuntu2204": "Canonical",
    "ubuntu2404": "Canonical",
    "debian11"  : "Debian",
    "debian12"  : "Debian",
    "rhel8"     : "RedHat",
    "rhel9"     : "RedHat",
  }
  os_image_offer = {
    "ubuntu2004": "0001-com-ubuntu-server-focal",
    "ubuntu2204": "0001-com-ubuntu-server-jammy",
    "ubuntu2404": "0001-com-ubuntu-server-noble",
    "debian11"  : "debian-11",
    "debian12"  : "debian-12",
    "rhel8"     : "RHEL",
    "rhel9"     : "RHEL",
  }
  os_image_sku = {
    "ubuntu2004": "20_04-lts",
    "ubuntu2204": "22_04-lts",
    "ubuntu2404": "24_04-lts",
    "debian11"  : "11",
    "debian12"  : "12",
    "rhel8"     : "8-lvm-gen2",
    "rhel9"     : "9-lvm-gen2",
  }
  os_image_user = {
    "ubuntu2004": "tfu",
    "ubuntu2204": "tfu",
    "ubuntu2404": "tfu",
    "debian11"  : "tfu",
    "debian12"  : "tfu",
    "rhel8"     : "tfu",
    "rhel9"     : "tfu",
  }
}

