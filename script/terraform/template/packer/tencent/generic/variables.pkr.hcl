
variable "common_tags" {
  type = map(string)
  default = {}
}

variable "region" {
  type = string
}

variable "zone" {
  type = string
}

variable "owner" {
  type = string
}

variable "instance_type" {
  type = string
  default = "S4.MEDIUM4"
}

variable "architecture" {
  type = string
  default = "x86_64"
}

variable "ssh_proxy_host" {
  type = string
  default = ""
}

variable "ssh_proxy_port" {
  type = string
  default = "0"
}

variable "ansible_playbook" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "os_disk_size" {
  type = number
  default = 50
}

variable "os_disk_type" {
  type = string
  default = "CLOUD_SSD"
}

variable "os_type" {
  type = string
  default = "ubuntu2204"
}

variable "image_name" {
  type = string
  default = "default"
}

variable "job_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "os_image_id" {
  type = string
}

variable "secret_id" {
  type = string
  default = null
  sensitive = true
}

variable "secret_key" {
  type = string
  default = null
  sensitive = true
}
