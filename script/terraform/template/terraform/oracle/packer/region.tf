#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

locals {
  # https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm
  ad_to_region = {
    "SYD": "ap-sydney-1"
    "MEL": "ap-melbourne-1"
    "GRU": "sa-saopaulo-1"
    "VCP": "sa-vinhedo-1"
    "YUL": "ca-montreal-1"
    "YYZ": "ca-toronto-1"
    "SCL": "sa-santiago-1"
    "CDG": "eu-paris-1"
    "MRS": "eu-marseille-1"
    "FRA": "eu-frankfurt-1"
    "HYD": "ap-hyderabad-1"
    "BOM": "ap-mumbai-1"
    "MTZ": "il-jerusalem-1"
    "LIN": "eu-milan-1"
    "KIX": "ap-osaka-1"
    "NRT": "ap-tokyo-1"
    "QRO": "mx-queretaro-1"
    "AMS": "eu-amsterdam-1"
    "JED": "me-jeddah-1"
    "SIN": "ap-singapore-1"
    "JNB": "af-johannesburg-1"
    "ICN": "ap-seoul-1"
    "YNY": "ap-chuncheon-1"
    "MAD": "eu-madrid-1"
    "ARN": "eu-stockholm-1"
    "ZRH": "eu-zurich-1"
    "AUH": "me-abudhabi-1"
    "UAE": "me-dubai-1"
    "LHR": "uk-london-1"
    "CWL": "uk-cardiff-1"
    "IAD": "us-ashburn-1"
    "ORD": "us-chicago-1"
    "PHX": "us-phoenix-1"
    "SJC": "us-sanjose-1"
  }

  region = var.region!=null?var.region:local.ad_to_region[replace(var.zone,"/.*:([A-Z]*).*/","$1")]
}

