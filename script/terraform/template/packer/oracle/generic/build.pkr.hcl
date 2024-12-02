
locals {
  image_name = replace(lower(var.image_name), "_", "-")
  os_image = var.os_image!=null?replace(lower(var.os_image), "_", "-"):null
}

source "oracle-oci" "default" {
  region = var.region
  compartment_ocid = var.compartment
  availability_domain = var.zone

  disk_size = var.os_disk_size
  subnet_ocid = var.subnet_id
  shape = var.instance_type

  use_private_ip = false
  ssh_username = local.os_image_user[var.os_type]
  ssh_proxy_host = var.ssh_proxy_host
  ssh_proxy_port = var.ssh_proxy_port

  image_name = local.image_name
  image_compartment_ocid = var.compartment

  instance_name = "wsf-${var.job_id}-builder"
  instance_tags = merge(var.common_tags, {
    owner = var.owner
    Name  = "wsf-${var.job_id}-builder"
  })

  create_vnic_details {
    assign_public_ip = "true"
    display_name = "wsf-${var.job_id}-vnic"
    subnet_id = var.subnet_id
    tags = merge(var.common_tags, {
      owner = var.owner
      Name = "wsf-${var.job_id}-vnic"
    })
  }

  shape_config {
    ocpus = var.cpu_core_count
    memory_in_gbs = var.memory_size
  }

  base_image_filter {
    compartment_id = var.compartment
    operating_system = local.os_image!=null?null:local.operating_systems[var.os_type]
    operating_system_version = local.os_image!=null?null:local.operating_system_versions[var.os_type]
    display_name = local.os_image!=null?local.os_image:null
    shape = local.os_image!=null?null:var.instance_type
  }

  tags = merge(var.common_tags, {
    owner = var.owner
    image_name = local.image_name
  })
}

build {
  name = "wsf-${var.job_id}-packer"
  sources = [
    "source.oracle-oci.default"
  ]

  provisioner "ansible" {
    playbook_file = var.ansible_playbook
    extra_arguments = ["-e", "csp=oracle", "-e", "image_name=${local.image_name}", "-vv"]
    ansible_env_vars = ["ANSIBLE_CONFIG=${dirname(abspath(var.ansible_playbook))}/ansible.cfg"]
    use_proxy = false
  }
}
