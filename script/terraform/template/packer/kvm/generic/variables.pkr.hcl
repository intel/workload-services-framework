
variable "cpu_core_count" {
  type = number
  default = 2
}

variable "memory_size" {
  type = number
  default = 4
}

variable "architecture" {
  type = string
  default = "x86_64"
}

variable "ansible_playbook" {
  type = string
}

variable "os_disk_size" {
  type = number
  default = 50
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

variable "os_image" {
  type = string
  default = null
}

variable "pool_name" {
  type = string
}

variable "kvm_host_user" {
  type = string
}

variable "kvm_host" {
  type = string
}

variable "kvm_host_port" {
  type = string
  default = 22
}

variable "ssh_pri_key_file" {
  type = string
  default = "ssh_access.key"
}

variable "ssh_pub_key_file" {
  type = string
  default = "ssh_access.key.pub"
}

