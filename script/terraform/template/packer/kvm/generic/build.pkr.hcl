
locals {
  image_name = replace(lower(var.image_name), "_", "-")
  os_image = var.os_image!=null?replace(lower(var.os_image), "_", "-"):null
  default_os_image = regex_replace(local.os_images[var.os_type], ".*/", "")
  default_os_image_exists = contains(split(" ",data.external.envs.result.vol_list),local.default_os_image)
}

source "libvirt" "default" {
  libvirt_uri = "qemu+ssh://${var.kvm_host_user}@${var.kvm_host}:${var.kvm_host_port}/system?keyfile=${data.external.ssh_keyfile.result.keyfile}&no_verify=1"

  domain_name = "wsf-${var.job_id}-builder"
  vcpu = var.cpu_core_count
  memory = var.memory_size*1024
  cpu_mode = "host-model"
  arch = var.architecture
  network_address_source = "lease"
  shutdown_mode = "acpi"

  network_interface {
    type = "managed"
    alias = "communicator"
    network = "default"
  }

  communicator {
    communicator = "ssh"
    ssh_username = local.os_users[var.os_type]
    ssh_private_key_file = "${path.root}/${var.ssh_pri_key_file}"
    ssh_bastion_host = var.kvm_host
    ssh_bastion_username = var.kvm_host_user
    ssh_bastion_port = var.kvm_host_port
    ssh_bastion_private_key_file = data.external.ssh_keyfile.result.keyfile
  }
  
  volume {
    alias = "artifact"
    pool = var.pool_name
    name = local.image_name
    capacity = format("%dG", var.os_disk_size)
    format = "qcow2"
    bus = "sata"

    source {
      type = (local.os_image!=null || local.default_os_image_exists)?"backing-store":"external"
      urls = (local.os_image!=null || local.default_os_image_exists)?null:[
        local.os_images[var.os_type]
      ]
      volume = local.os_image!=null?local.os_image:(local.default_os_image_exists?local.default_os_image:null)
      pool = var.pool_name
    }
  }

  volume {
    pool = var.pool_name
    capacity = "1M"
    bus = "sata"

    source {
      type = "cloud-init"

      network_config = templatefile("${path.root}/templates/network-init.cfg.tpl", {})

      user_data = templatefile("${path.root}/templates/cloud-init.cfg.tpl", {
        user = local.os_users[var.os_type]
        authorized_keys = file("${path.root}/${var.ssh_pub_key_file}")
        http_proxy = data.external.envs.result.http_proxy
        https_proxy = data.external.envs.result.https_proxy
        no_proxy = data.external.envs.result.no_proxy
        date_time = data.external.envs.result.date_time
        time_zone = data.external.envs.result.time_zone
      })
    }
  }
}

build {
  name = "wsf-${var.job_id}-packer"
  sources = [
    "sources.libvirt.default"
  ]

  provisioner "ansible" {
    playbook_file = "${abspath(path.root)}/templates/prep_env.yaml"
    extra_arguments = [
      "-e", "template_path=${abspath(path.root)}/templates", 
      "-e", "kvm_host=${var.kvm_host}", 
      "-e", "kvm_host_port=${var.kvm_host_port}", 
      "-e", "kvm_host_user=${var.kvm_host_user}", 
    ]
    use_proxy = false
  }

  provisioner "ansible" {
    playbook_file = var.ansible_playbook
    extra_arguments = [
      "-e", "csp=kvm", 
      "-e", "image_name=${local.image_name}", 
      "-vv", 
    ]
    ansible_env_vars = ["ANSIBLE_CONFIG=${dirname(abspath(var.ansible_playbook))}/ansible.cfg"]
    use_proxy = false
  }

  provisioner "shell" {
    inline = ["sudo cloud-init clean"]
  }
}
