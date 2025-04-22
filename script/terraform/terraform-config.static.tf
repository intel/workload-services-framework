#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
variable "wl_name" {
  default = ""
}

variable "wl_namespace" {
  default = ""
}

variable "wl_registry_map" {
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
        # Note: Uncomment and specify your user name  
        # "user_name": "<user>",
        "public_ip": "127.0.0.1",
        "private_ip": "127.0.0.1",
        "ssh_port": 22,
        # Note: Support PDU for power measurement. Leave pdu_password empty.
        # "pdu_port": "0",
        # "pdu_group": "",
        # "pdu_ip": "127.0.1.1",
        # "pdu_user": "",
        # "pdu_password": "",
        # Note: Support BMC for power cycle SUT. Leave bmc_password empty.
        # "bmc_ip": "127.0.0.1",
        # "bmc_port": 623,
        # "bmc_user": "<user>",
        # "bmc_password": ""
        # Note: Support Windows WINRM. Leave the winrm_password empty.
        # "winrm_user": "<user>"
        # "winrm_password": ""
        # Specify passwords in script/csp/.static/config.json, support both global password or password by host ip
        # {
        #   "winrm_password": "", 
        #   "bmc_password": "",
        #   "pdu_password": "",
        #   "hosts": {
        #     "host_ip": {
        #       "pdu_password": "",
        #       "bmc_password": "",
        #       "winrm_password": ""
        #     }
        #   }
        # }
      },
    }
  }
}

variable "client_profile" {
  default = {
    vm_count = 1
    hosts = {
      "client-0": {
        # Note: Uncomment and specify your user name  
        # "user_name": "<user>",
        "public_ip": "127.0.0.1",
        "private_ip": "127.0.0.1",
        "ssh_port": 22,
        # Note: Support PDU for power measurement. Leave pdu_password empty.
        # "pdu_port": "0",
        # "pdu_group": "",
        # "pdu_ip": "127.0.1.1",
        # "pdu_user": "",
        # "pdu_password": "",
        # Note: Support BMC for power cycle SUT. Leave bmc_password empty.
        # "bmc_ip": "127.0.0.1",
        # "bmc_port": 623,
        # "bmc_user": "<user>",
        # "bmc_password": ""
        # Note: Support Windows WINRM. Leave the winrm_password empty.
        # "winrm_user": "<user>"
        # "winrm_password": ""
        # Specify passwords in script/csp/.static/config.json:
        # {
        #   "winrm_password": "",
        #   "bmc_password": "",
        #   "pdu_password": {
        #     "pdu_ip": {
        #       "pdu_user": ""
        #     }
        #   }
        # }
      },
    }
  }
}

variable "controller_profile" {
  default = {
    vm_count = 1
    hosts = {
      "controller-0": {
        # Note: Uncomment and specify your user name  
        # "user_name": "<user>",
        "public_ip": "127.0.0.1",
        "private_ip": "127.0.0.1",
        "ssh_port": 22,
      }
    }
  }
}

output "instances" {
  sensitive = true
  value = merge({
    for i in range(var.worker_profile.vm_count) : 
      "worker-${i}" => merge(var.worker_profile.hosts[var.worker_profile.hosts["worker-0"].public_ip=="127.0.0.1"?"worker-0":"worker-${i}"], var.worker_profile.hosts["worker-0"].public_ip=="127.0.0.1"?{
        ansible_connection = "local"
      }:{})
  }, {
    for i in range(var.client_profile.vm_count) :
      "client-${i}" => merge(var.client_profile.hosts[var.client_profile.hosts["client-0"].public_ip=="127.0.0.1"?"client-0":"client-${i}"], var.client_profile.hosts["client-0"].public_ip=="127.0.0.1"?{
        ansible_connection = "local"
      }:{})
  }, {
    for i in range(var.controller_profile.vm_count) :
      "controller-${i}" => merge(var.controller_profile.hosts["controller-${i}"], var.controller_profile.hosts["controller-0"].public_ip=="127.0.0.1"?{
        ansible_connection = "local"
      }:{})
  })
}

output "options" {
  value = { 
    wl_name : var.wl_name,
    wl_registry_map : var.wl_registry_map,
    wl_namespace : var.wl_namespace,
    intel_publisher_sut_machine_type: var.intel_publisher_sut_machine_type,
    intel_publisher_sut_metadata: var.intel_publisher_sut_metadata,

    # Enable k8s registry only in the DDCW use case. See doc/user-guide/preparing-infrastructure/setup-wsf.md
    k8s_enable_registry: false,
  }
}