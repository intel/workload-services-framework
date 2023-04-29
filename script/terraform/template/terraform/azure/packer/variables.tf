
variable "region" {
  type = string
  default = null
}

variable "zone" {
  type = string
  nullable = false
}

variable "subscription_id" {
  type = string
  default = null
}

variable "vpc_cidr_block" {
  type = string
  default = "10.0.0.0/16"
}

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "proxy_ip_list" {
  type = string
  nullable = false
}

variable "owner" {
  type = string
  nullable = false
}

variable "job_id" {
  type = string
  default = null
}
