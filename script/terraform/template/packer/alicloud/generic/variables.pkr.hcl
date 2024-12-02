
variable "common_tags" {
  type = map(string)
  default = {}
}

variable "config_file" {
  type = string
  default = "/home/.aliyun/config.json"
}

variable "profile" {
  type = string
  default = "default"
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
  default = "ecs.g7.large"
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

variable "os_disk_size" {
  type = number
  default = 50
}

variable "os_disk_type" {
  type = string
  default = "gp2"
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

variable "resource_group_id" {
  type = string
  default = null
}

variable "image_version" {
  type = string
  default = "latest"
}

variable "spot_instance" {
  type = string
  default = null
}

variable "os_image_id" {
  type = string
  default = null
}

variable "vswitch_id" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "internet_bandwidth" {
  type = number
  default = 100
}

