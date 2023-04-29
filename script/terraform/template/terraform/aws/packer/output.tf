output "packer" {
  value = {
    region: local.region
    zone: var.zone
    profile: var.profile
    vpc_id: aws_vpc.default.id
    subnet_id: aws_subnet.default.id
    security_group_id: aws_default_security_group.default.id
  }
}
