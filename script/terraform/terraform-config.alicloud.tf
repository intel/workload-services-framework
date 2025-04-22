#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

variable "disk_spec_1" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_type = "cloud_essd"
    disk_performance = null
  }
}

variable "disk_spec_2" {
  default = {
    disk_count = 1
    disk_size = 200
    disk_format = "ext4"
    disk_type = "cloud_essd"
    disk_performance = null
  }
}

variable "region" {
  default = null
}

variable "zone" {
  default = "cn-beijing-l"
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

variable "wl_registry_map" {
  default = ""
}

variable "wl_namespace" {
  default = ""
}

variable "worker_profile" {
  default = {
    name = "worker"
    instance_type = "ecs.g6.large"
    cpu_model_regex = null
    vm_count = 1
    accelerators = null

    os_image = null
    os_type = "ubuntu2204"
    os_disk_type = "cloud_essd"
    os_disk_size = 200
    os_disk_performance = null

    data_disk_spec = null
  }
}

variable "client_profile" {
  default = {
    name = "client"
    instance_type = "ecs.g6.large"
    cpu_model_regex = null
    vm_count = 1
    accelerators = null

    os_image = null
    os_type = "ubuntu2204"
    os_disk_type = "cloud_essd"
    os_disk_size = 200
    os_disk_performance = null

    data_disk_spec = null
  }
}

variable "controller_profile" {
  default = {
    name = "controller"
    instance_type = "ecs.g6.large"
    cpu_model_regex = null
    vm_count = 1
    accelerators = null

    os_image = null
    os_type = "ubuntu2204"
    os_disk_type = "cloud_essd"
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
    wl_registry_map : var.wl_registry_map,
    wl_namespace : var.wl_namespace,

    docker_dist_repo: "https://mirrors.aliyun.com/docker-ce",
    containerd_pause_registry: "registry.aliyuncs.com/google_containers",

    k8s_version: "1.28.2",
    k8s_repo_key_url: {
      "debian": "http://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg",
      "centos": ["http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg","https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg"],
    },
    k8s_repo_url: {
      "debian": "http://mirrors.aliyun.com/kubernetes/apt kubernetes-xenial main",
      "centos": "http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-$basearch",
    },
    k8s_kubeadm_options: {
      "ClusterConfiguration": {
        "imageRepository": "registry.aliyuncs.com/google_containers",
      },
    },
    k8s_registry_image: "public.ecr.aws/docker/library/registry:2",
    k8s_calico_cni_repo: "public.ecr.aws/metakube/calico",
    k8s_cni: "calico",
    k8s_enable_nfd: false,
    k8s_qat_push_images: true,
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

output "terraform_replace" {
  value = lookup(module.wsf, "terraform_replace", null)==null?null:{
    command = replace(module.wsf.terraform_replace.command, "=", "=module.wsf.")
    cpu_model = module.wsf.terraform_replace.cpu_model
  }
}
