#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#
resource "azurerm_virtual_network" "default" {
  name                = "wsf-${var.job_id}-net"
  address_space       = [var.vpc_cidr_block]
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
}

resource "azurerm_subnet" "default" {
  name                 = "wsf-${var.job_id}-subnet"
  resource_group_name  = azurerm_resource_group.default.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = [local.subnet_cidr_block]
}

resource "azurerm_network_security_group" "default" {
  name                = "wsf-${var.job_id}-nsg"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  
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

resource "azurerm_subnet_network_security_group_association" "default" {
  subnet_id                 = azurerm_subnet.default.id
  network_security_group_id = azurerm_network_security_group.default.id
}

resource "azurerm_public_ip" "default" {
  for_each = local.vms

  depends_on = [azurerm_resource_group.default]
  name                = "wsf-${var.job_id}-pub-ip-${each.key}"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  allocation_method   = "Static"
  sku                 = each.value.data_disk_spec!=null?each.value.data_disk_spec.disk_type=="UltraSSD_LRS"?"Standard":null:null
  zones               = each.value.data_disk_spec!=null?each.value.data_disk_spec.disk_type=="UltraSSD_LRS"?[local.availability_zone]:null:null
}

resource "azurerm_network_interface" "default" {
  for_each = local.vms

  name                = "wsf-${var.job_id}-nic-${each.key}"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.default.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.default[each.key].id
  }
}

resource "azurerm_network_interface" "secondary" {
  for_each = local.networks

  name                = "wsf-${var.job_id}-nic-${each.key}"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.default.id
    private_ip_address_allocation = "Dynamic"
  }
}

