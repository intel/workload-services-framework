
variable "public_ip" {
  type = string
}

variable "private_ip" {
  type = string
}

variable "user_name" {
  type = string
}

variable "ssh_port" {
  type = string
}

variable "ssh_pri_key_file" {
  type = string
  default = "~/.ssh/id_rsa"
}

variable "ssh_localhost_pub_key_file" {
  type = string
  default = "ssh_access.key.pub"
}

variable "ssh_localhost_pri_key_file" {
  type = string
  default = "ssh_access.key"
}

variable "ansible_playbook" {
  type = string
}

variable "image_name" {
  type = string
}

