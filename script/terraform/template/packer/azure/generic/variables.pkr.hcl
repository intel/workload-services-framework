
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
  default = "e2.small"
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
  default = "../../../ansible/install.yaml"
}

variable "os_disk_size" {
  type = number
  default = 50
}

variable "os_disk_type" {
  type = string
  default = "pd-standard"
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

variable "spot_instance" {
  type = bool
  default = true
}

variable "spot_price" {
  type = number
  default = null
}

variable "common_tags" {
  type = map(string)
  default = {}
}

variable "network_name" {
  type = string
}

variable "subnet_name" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "availability_zone" {
  type = number
}

variable "managed_resource_group_name" {
  type = string
}

