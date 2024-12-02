
locals {
  os_users = {
    "ubuntu2204": "ubuntu",
    "ubuntu2404": "ubuntu",
  }
  os_images = {
    "ubuntu2204": "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img",
    "ubuntu2404": "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img",
  }
}

