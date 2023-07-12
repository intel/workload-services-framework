#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

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

variable "intel_publisher_sut_machine_type" {
  default = "static"
}

variable "intel_publisher_sut_metadata" {
  default = ""
}

variable "worker_profile" {
  default = {
    vm_count = 1
    hosts = {
      "worker-0": {
        "user_name": "root",
        "public_ip": "127.0.0.1",
        "private_ip": "127.0.0.1",
        "ssh_port": 22,
      },
    }
  }
}

variable "client_profile" {
  default = {
    vm_count = 1
    hosts = {
      "client-0": {
        "user_name": "root",
        "public_ip": "127.0.0.1",
        "private_ip": "127.0.0.1",
        "ssh_port": 22,
      },
    }
  }
}

variable "controller_profile" {
  default = {
    vm_count = 1
    hosts = {
      "controller-0": {
        "user_name": "root",
        "public_ip": "127.0.0.1",
        "private_ip": "127.0.0.1",
        "ssh_port": 22,
      }
    }
  }
}

output "instances" {
  value = merge({
    for i in range(var.worker_profile.vm_count) : 
      "worker-${i}" => var.worker_profile.hosts["worker-${i}"]
  }, {
    for i in range(var.client_profile.vm_count) :
      "client-${i}" => var.client_profile.hosts["client-${i}"]
  }, {
    for i in range(var.controller_profile.vm_count) :
      "controller-${i}" => var.controller_profile.hosts["controller-${i}"]
  })
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
    intel_publisher_sut_machine_type: var.intel_publisher_sut_machine_type,
    intel_publisher_sut_metadata: var.intel_publisher_sut_metadata,

    # Enable k8s registry only in the DDCW use case. See doc/user-guide/preparing-infrastructure/setup-wsf.md
    k8s_enable_registry: false,
  }
}

