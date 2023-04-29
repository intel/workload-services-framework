variable "disk_spec_1" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_type = "gp2"
    disk_iops = null
    disk_throughput = null
  }
}

variable "disk_spec_2" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_type = "gp2"
    disk_iops = null
    disk_throughput = null
  }
}

variable "network_spec_1" {
  default = {
    network_count = 1
    network_type = null
  }
}

variable "region" {
  default = null
}

variable "zone" {
  default = "us-west-2a"
}

variable "owner" {
  default = ""
}

variable "spot_instance" {
  default = true
}

variable "custom_tags" {
  default = {}
}

variable "wl_name" {
  default = ""
}

variable "wl_category" {
   default = ""
}

variable "wl_namespace" {
  default = ""
}

variable "wl_docker_image" {
  default = ""
}

variable "wl_docker_options" {
  default = ""
}

variable "wl_job_filter" {
  default = ""
}

variable "wl_export_logs" {
  default = "/export-logs"
}

variable "wl_timeout" {
  default = "28800,300,3000"
}

variable "wl_registry_map" {
  default = ""
}

variable "wl_trace_mode" {
  default = ""
}

variable "worker_profile" {
  default = {
    name = "worker"
    instance_type = "t2.medium"
    threads_per_core = null
    cpu_core_count = null
    vm_count = 1

    image = null
    os_type = "ubuntu2204"
    os_disk_type = "gp2"
    os_disk_size = 200
    os_disk_iops = null
    os_disk_throughput = null

    data_disk_spec = null
    network_spec = null
  }
}

variable "client_profile" {
  default = {
    name = "client"
    instance_type = "t2.medium"
    threads_per_core = null
    cpu_core_count = null
    vm_count = 1

    image = null
    os_type = "ubuntu2204"
    os_disk_type = "gp2"
    os_disk_size = 200
    os_disk_iops = null
    os_disk_throughput = null

    data_disk_spec = null
    network_spec = null
  }
}

variable "controller_profile" {
  default = {
    name = "controller"
    instance_type = "t2.medium"
    threads_per_core = null
    cpu_core_count = null
    vm_count = 1

    image = null
    os_type = "ubuntu2204"
    os_disk_type = "gp2"
    os_disk_size = 200
    os_disk_iops = null
    os_disk_throughput = null

    data_disk_spec = null
    network_spec = null
  }
}

module "wsf" {
  source = "./template/terraform/aws/main"

  region = var.region
  zone = var.zone
  job_id = var.wl_namespace

  sg_whitelist_cidr_blocks = compact(split("\n",file("proxy-ip-list.txt")))
  ssh_pub_key = file("ssh_access.key.pub")

  common_tags = {
    for k,v in merge(var.custom_tags, {
      owner: var.owner,
      workload: var.wl_name,
    }) : k => substr(replace(lower(v), "/[^a-z0-9_-]/", ""), 0, 63)
  }

  instance_profiles = [
    merge(var.worker_profile, {
      data_disk_spec: null,
      network_spec: null,
    }),
    merge(var.client_profile, {
      data_disk_spec: null
      network_spec: null,
    }),
    merge(var.controller_profile, {
      data_disk_spec: null,
      network_spec: null,
    }),
  ]

  spot_instance = var.spot_instance
}

output "options" {
  value = {
    wl_name : var.wl_name,
    wl_category : var.wl_category,
    wl_docker_image : var.wl_docker_image,
    wl_docker_options : var.wl_docker_options,
    wl_job_filter : var.wl_job_filter,
    wl_export_logs: var.wl_export_logs,
    wl_timeout : var.wl_timeout,
    wl_registry_map : var.wl_registry_map,
    wl_namespace : var.wl_namespace,
    wl_trace_mode : var.wl_trace_mode,
    # k8s_registry_storage: "aws",
    # k8s_registry_aws_storage_bucket: "registry-content",
    # k8s_registry_aws_storage_region: var.region,
  }
}

output "instances" {
  sensitive = true
  value = {
    for k,v in module.wsf.instances : k => merge(v, {
      csp = "aws",
      zone = var.zone,
    })
  }
}

