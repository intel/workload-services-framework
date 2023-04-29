
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

variable "common_tags" {
  type    = map(string)
  default = {}
}

variable "owner" {
  type = string
  nullable = false
}

variable "create_resource" {
  type = bool
  nullable = false
}

