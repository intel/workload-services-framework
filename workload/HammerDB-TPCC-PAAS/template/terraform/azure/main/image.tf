#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  os_image_publisher = {
    "ubuntu2004": "Canonical",
    "ubuntu2204": "Canonical",
    "ubuntu2404": "Canonical",
    "debian11"  : "Debian",
    "debian12"  : "Debian",
    "rhel9"     : "RedHat",
    "windows2022" : "MicrosoftWindowsServer",
    "windows2019-sql2016" : "MicrosoftSQLServer",
  }
  os_image_offer = {
    "ubuntu2004": {
      "gen1": "0001-com-ubuntu-server-focal", 
      "gen2": "0001-com-ubuntu-server-focal", 
      "arm64": "0001-com-ubuntu-server-focal", 
      "cvm": "0001-com-ubuntu-confidential-vm-focal", 
    },
    "ubuntu2204": {
      "gen1": "0001-com-ubuntu-server-jammy", 
      "gen2": "0001-com-ubuntu-server-jammy", 
      "arm64": "0001-com-ubuntu-server-jammy", 
      "cvm": "0001-com-ubuntu-confidential-vm-jammy",
    },
    "ubuntu2404": {
      "gen1": "ubuntu-24_04-lts", 
      "gen2": "ubuntu-24_04-lts", 
      "arm64": "ubuntu-24_04-lts", 
      "cvm": "ubuntu-24_04-lts", 
    },
    "debian11": {
      "gen1": "debian-11",
      "gen2": "debian-11",
      "arm64": "debian-11",
      "cvm": "debian-11",
    },
    "debian12": {
      "gen1": "debian-12",
      "gen2": "debian-12",
      "arm64": "debian-12",
      "cvm": "debian-12",
    },
    "rhel9": {
      "gen1": "RHEL",
      "gen2": "RHEL",
      "arm64": "rhel-arm64",
      "cvm": "rhel-cvm",
    },
    "windows2022": {
      "gen2": "WindowsServer",
      "cvm": "windows-cvm",
    },
    "windows2019-sql2016": {
      "gen2": "SQL2016sp3-ws2019",
      "arm64": "sql2016sp3-ws2019",
    },
  }
  os_image_sku = {
    "ubuntu2004": {
      "gen1": "20_04-lts",
      "gen2": "20_04-lts-gen2",
      "arm64": "20_04-lts-arm64",
      "cvm": "20_04-lts-cvm",
    },
    "ubuntu2204": {
      "gen1": "22_04-lts",
      "gen2": "22_04-lts-gen2",
      "arm64": "22_04-lts-arm64",
      "cvm": "22_04-lts-cvm",
    },
    "ubuntu2404": {
      "gen1": "server-gen1",
      "gen2": "server",
      "arm64": "server-arm64",
      "cvm": "cvm"
    },
    "debian11": {
      "gen1": "11",
      "gen2": "11-gen2",
      "arm64": "11-arm64",
    },
    "debian12": {
      "gen1": "12",
      "gen2": "12-gen2",
      "arm64": "12-arm64",
    },
    "rhel9": {
      "gen1": "9-lvm",
      "gen2": "9-lvm-gen2",
      "arm64": "9_3-arm64",
      "cvm": "9_4_cvm",
    },
    "windows2022": {
      "gen2": "2022-datacenter-gen2",
      "cvm": "2022-datacenter-cvm",
    },
    "windows2019-sql2016": {
      "gen2": "enterprise",
      "arm64": "enterprise",
    },
  }
  os_image_user = {
    "ubuntu2004": "tfu",
    "ubuntu2204": "tfu",
    "ubuntu2404": "tfu",
    "debian11"  : "tfu",
    "debian12"  : "tfu",
    "rhel9"     : "tfu",
    "windows2022" : "tfu",
    "windows2019-sql2016" : "tfu",
  }
  special_instances = {
    "gen1": [ # gen1_instances: https://docs.microsoft.com/en-us/azure/virtual-machines/generation-2
      "Av2", "Amv2",
      "Dv2", "DSv2", 
      "Dv3", "Dsv3",
      "Dav4", "Dasv4",
      "Ev3", "Esv3", "Eisv3",
      "Ev4", "Esv4", "Eisv4",
      "H", "Hm", "Hr", "Hmr",
      "NC", "NCr", 
      "NV",
      "NPs",
    ],
    "arm64": [ # arm64 instances: https://docs.microsoft.com/en-us/azure/virtual-machines/sizes
      "Dpdsv5", "Dpldsv5", "Dpsv5", "Dplsv5",
      "Epdsv5", "Epsv5",
      "Dpdsv6", "Dpldsv6", "Dpsv6",
      "Epdsv6", "Epsv6",
    ],
    "cvm": [ # confidential instances: https://learn.microsoft.com/en-us/azure/confidential-computing/virtual-machine-options#sizes
      "DCasv5", "DCesv5", "DCadsv5", "DCedsv5", 
      "ECasv5", "ECesv5", "ECadsv5", "ECedsv5",
    ],
  }
}

locals {
  instance_type_abvs = {
    for k,v in local.vms : k => replace(v.instance_type, "/[A-Za-z]+_([A-Za-z]+)[0-9]*([A-Za-z]*)_?([a-zA-Z0-9]*)/", "$1$2$3")
  }

  os_image_sku_arch = {
    for k,v in local.instance_type_abvs : k => lookup({ for s,t in local.special_instances: k=>s if contains(t,v) }, k, "gen2")
  }
}

data "azurerm_resources" "image" {
  for_each = {
    for k,v in local.vms : k => v if (v.os_image!=null)
  }
  name = each.value.os_image
  type = "Microsoft.Compute/images"
}