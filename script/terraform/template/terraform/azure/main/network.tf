#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
resource "azurerm_virtual_network" "default" {
  count = var.virtual_network_name!=null?0:1

  name                = "wsf-${var.job_id}-net"
  address_space       = [var.vpc_cidr_block]
  location            = local.location
  resource_group_name = local.resource_group_name
}

resource "azurerm_subnet" "default" {
  count = var.subnet_name!=null?0:1

  name                 = "wsf-${var.job_id}-subnet"
  resource_group_name  = local.resource_group_name
  virtual_network_name = local.virtual_network_name
  address_prefixes     = [local.subnet_cidr_block]
}

resource "azurerm_network_security_group" "default" {
  count = var.subnet_name!=null?0:1

  name                = "wsf-${var.job_id}-nsg"
  location            = local.location
  resource_group_name = local.resource_group_name
  
  security_rule {
    name                       = "PING"
    description                = "PING"
    priority                   = 160
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefixes    = var.sg_whitelist_cidr_blocks
    destination_address_prefix = local.subnet_cidr_block
  }

  security_rule {
    name                       = "SSH"
    description                = "SSH"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.sg_whitelist_cidr_blocks
    destination_address_prefix = local.subnet_cidr_block
  }

  security_rule {
    name                       = "WINRM"
    description                = "WINRM"
    priority                   = 155
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "${var.winrm_port}"
    source_address_prefixes    = var.sg_whitelist_cidr_blocks
    destination_address_prefix = local.subnet_cidr_block
  }

  security_rule {
    name                       = "local_network_traffic"
    description                = "Allow local traffic"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*" 
    destination_port_range     = "*"
    source_address_prefixes    = [ local.subnet_cidr_block ]
    destination_address_prefix = local.subnet_cidr_block
  }
}

data "azurerm_subnet" "default" {
  count = var.subnet_name!=null?1:0

  name = var.subnet_name
  virtual_network_name = local.virtual_network_name
  resource_group_name = local.resource_group_name
}

resource "azurerm_subnet_network_security_group_association" "default" {
  count = var.subnet_name!=null?0:1

  subnet_id                 = local.subnet_id
  network_security_group_id = azurerm_network_security_group.default.0.id
}

resource "azurerm_public_ip" "default" {
  for_each = {
    for k,v in local.vms : k => v
      if var.allocate_public_ip
  }

  depends_on = [azurerm_resource_group.default]
  name                = "wsf-${var.job_id}-pub-ip-${each.key}"
  location            = local.location
  resource_group_name = local.resource_group_name
  allocation_method   = "Static"
  sku                 = each.value.data_disk_spec!=null?each.value.data_disk_spec.disk_type=="UltraSSD_LRS"?"Standard":null:null
  zones               = each.value.data_disk_spec!=null?each.value.data_disk_spec.disk_type=="UltraSSD_LRS"?[local.availability_zone]:null:null
}

resource "azurerm_network_interface" "default" {
  for_each = local.vms

  name                = "wsf-${var.job_id}-nic-${each.key}"
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = var.allocate_public_ip?azurerm_public_ip.default[each.key].id:null
  }
}

resource "azurerm_network_interface" "secondary" {
  for_each = local.networks

  name                = "wsf-${var.job_id}-nic-${each.key}"
  location            = local.location
  resource_group_name = local.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = local.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

