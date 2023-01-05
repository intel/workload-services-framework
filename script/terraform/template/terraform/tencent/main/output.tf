output "instances" {
  value = {
    for i, instance in tencentcloud_instance.default : i => {
        public_ip: instance.public_ip,
        private_ip: instance.private_ip,
        user_name: local.os_user_name[local.instances[i].os_type]
        instance_type: instance.instance_type,
    }
  }
}
