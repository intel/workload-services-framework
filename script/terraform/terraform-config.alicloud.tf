
variable "disk_spec_1" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_type = "cloud_ssd"
    disk_performance = null
  }
}

variable "disk_spec_2" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_type = "cloud_ssd"
    disk_performance = null
  }
}

variable "region" {
  default = null
}

variable "zone" {
  default = "cn-shanghai-m"
}

variable "resource_group_id" {
  default = "rg-aekzpvcftlcma5a"
}

variable "owner" {
  default = ""
}

variable "custom_tags" {
  default = {}
}

variable "spot_instance" {
  default = true
}

variable "wl_name" {
  default = ""
}

variable "wl_category" {
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

variable "wl_namespace" {
  default = ""
}

variable "wl_trace_mode" {
  default = ""
}

variable "worker_profile" {
  default = {
    name = "worker"
    instance_type = "ecs.g7.large"
    vm_count = 1

    image = null
    os_type = "ubuntu2204"
    os_disk_type = "cloud_auto"
    os_disk_size = 200
    os_disk_performance = null

    data_disk_spec = null
  }
}

variable "client_profile" {
  default = {
    name = "client"
    instance_type = "ecs.g7.large"
    vm_count = 1

    image = null
    os_type = "ubuntu2204"
    os_disk_type = "cloud_auto"
    os_disk_size = 200
    os_disk_performance = null

    data_disk_spec = null
  }
}

variable "controller_profile" {
  default = {
    name = "controller"
    instance_type = "ecs.g7.large"
    vm_count = 1

    image = null
    os_type = "ubuntu2204"
    os_disk_type = "cloud_auto"
    os_disk_size = 200
    os_disk_performance = null

    data_disk_spec = null
  }
}

module "wsf" {
  source = "./template/terraform/alicloud/main"

  region = var.region
  zone = var.zone
  resource_group_id = var.resource_group_id
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
    }),
    merge(var.client_profile, {
      data_disk_spec: null,
    }),
    merge(var.controller_profile, {
      data_disk_spec: null,
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

    docker_dist_repo: "https://mirrors.aliyun.com/docker-ce",
    docker_registry_mirrors: [
      "https://registry.cn-hangzhou.aliyuncs.com",
    ],
    k8s_repo_key_url: {
      "ubuntu": "http://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg",
      "centos": ["http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg","https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg"]
    },
    k8s_repo_url: {
      "ubuntu": "http://mirrors.aliyun.com/kubernetes/apt",
      "centos": "http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-$basearch",
    },
    k8s_kubeadm_options: {
      "ClusterConfiguration": {
        "imageRepository": "registry.aliyuncs.com/google_containers",
      },
    },
    containerd_pause_registry: "registry.aliyuncs.com/google_containers",
    k8s_nfd_registry: "docker.io/raspbernetes",
  }
}

output "instances" {
  value = {
    for k,v in module.wsf.instances : k => merge(v, {
      csp = "alicloud",
      zone = var.zone,
    })
  }
}

