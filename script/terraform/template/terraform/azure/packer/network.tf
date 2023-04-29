
locals {
  subnet_cidr_block = cidrsubnet(var.vpc_cidr_block, 8, 1)
  availability_zone = length(regexall("-[0-9]$",var.zone))>0?parseint(replace(var.zone,"/.*-/",""),10):1
  sg_whitelist_cidr_blocks = compact(split("\n", file(var.proxy_ip_list)))
}

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
    source_address_prefixes    = local.sg_whitelist_cidr_blocks
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
    source_address_prefixes    = local.sg_whitelist_cidr_blocks
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
  depends_on = [azurerm_resource_group.default]
  name                = "wsf-${var.job_id}-pub-ip"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [local.availability_zone]
}

resource "azurerm_network_interface" "default" {
  name                = "wsf-${var.job_id}-nic"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.default.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.default.id
  }
}
