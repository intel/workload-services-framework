output "instances" {
  value = {
    for i, instance in var.spot_instance?aws_spot_instance_request.default:aws_instance.default : i => {
        public_ip: instance.public_ip,
        private_ip: instance.private_ip,
        user_name: local.os_image_user[local.instances[i].os_type]
        instance_type: instance.instance_type,
    }
  }
}
