
locals {
  os_image_owner = {
    "ubuntu2004": "099720109477" # CANONICAL
    "ubuntu2204": "099720109477" # CANONICAL
    "ubuntu2404": "099720109477" # CANONICAL
    "debian11"  : "136693071363" # Debian
    "debian12"  : "136693071363" # Debian
    "rhel9"     : "309956199498" # RHEL 9
  }

  os_image_filter = {
    "ubuntu2004": "ubuntu/images/*/ubuntu-focal-20.04-*64-server-20*",
    "ubuntu2204": "ubuntu/images/*/ubuntu-jammy-22.04-*64-server-20*",
    "ubuntu2404": "ubuntu/images/*/ubuntu-noble-24.04-*64-server-20*",
    "debian11"  : "debian-11-*64-20220911-1135",
    "debian12"  : "debian-12-*64-20230910-1499",
    "rhel9"     : "RHEL-9*_HVM-*",
  }

  os_image_user = {
    "ubuntu2004": "ubuntu",
    "ubuntu2204": "ubuntu",
    "ubuntu2404": "ubuntu",
    "debian11"  : "admin",
    "debian12"  : "admin",
    "rhel9"     : "ec2-user",
  }

  os_image_root_device = {
    "ubuntu2004": "/dev/sda1",
    "ubuntu2204": "/dev/sda1",
    "ubuntu2404": "/dev/sda1",
    "debian11"  : "/dev/xvda",
    "debian12"  : "/dev/xvda",
    "rhel9"     : "/dev/xvda",
  }
}

