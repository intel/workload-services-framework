
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
  default = "VM.Standard3.Flex"
}

variable "cpu_core_count" {
  type = number
  default = 1
}

variable "memory_size" {
  type = number
  default = 1
}

variable "subnet_id" {
  type = string
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

variable "vpc_cidr_block" {
  type = string
  default = "10.0.0.0/16"
}

variable "os_disk_size" {
  type = number
  default = 50
}

variable "os_disk_type" {
  type = string
  default = null
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
  default = null
}

variable "spot_instance" {
  type = bool
  default = true
}

variable "spot_price" {
  type = number
  default = null
}

variable "compartment" {
  type = string
}

variable "os_image" {
  type = string
  default = null
}

