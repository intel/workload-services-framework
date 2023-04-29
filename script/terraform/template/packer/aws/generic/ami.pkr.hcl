
locals {
  os_image_owner = {
    "ubuntu2004": "099720109477" # CANONICAL
    "ubuntu2204": "099720109477" # CANONICAL
    "debian11"  : "136693071363" # Debian
  }

  os_image_filter = {
    "ubuntu2004": "ubuntu/images/*/ubuntu-focal-20.04-*64-server-20*",
    "ubuntu2204": "ubuntu/images/*/ubuntu-jammy-22.04-*64-server-20*",
    "debian11"  : "debian-11-*64-20220911-1135",
  }

  os_image_user = {
    "ubuntu2004": "ubuntu",
    "ubuntu2204": "ubuntu",
    "debian11"  : "admin",
  }

  os_image_root_device = {
    "ubuntu2004": "/dev/sda1",
    "ubuntu2204": "/dev/sda1",
    "debian11"  : "/dev/xvda",
  }
}

