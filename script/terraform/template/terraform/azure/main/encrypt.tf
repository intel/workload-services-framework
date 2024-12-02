#
# Apache v2 license
# Copyright (C) 2023 Intel Corporation
# SPDX-License-Identifier: Apache-2.0
#

data "azurerm_client_config" "current" {
  count = (var.encrypt_disk && var.disk_encryption_set_name==null)?1:0
}

data "azurerm_disk_encryption_set" "default" {
  count = (var.encrypt_disk && var.disk_encryption_set_name!=null)?1:0

  name                = var.disk_encryption_set_name
  resource_group_name = local.resource_group_name
}

resource "azurerm_key_vault" "default" {
  count = (var.encrypt_disk && var.disk_encryption_set_name==null)?1:0

  name = substr("wsf-${var.job_id}-key-vault",0,24)
  location = local.location
  resource_group_name = local.resource_group_name
  tenant_id = data.azurerm_client_config.current.0.tenant_id
  sku_name = "premium"
  enabled_for_disk_encryption = true
  purge_protection_enabled = true

  tags = var.common_tags
}

resource "azurerm_key_vault_key" "default" {
  count = (var.encrypt_disk && var.disk_encryption_set_name==null)?1:0

  name = "wsf-${var.job_id}-key-vault-key"
  key_vault_id = azurerm_key_vault.default.0.id
  key_type = "RSA"
  key_size = var.encrypt_key_size

  depends_on = [
    azurerm_key_vault_access_policy.user
  ]

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  tags = var.common_tags
}

resource "azurerm_disk_encryption_set" "default" {
  count = (var.encrypt_disk && var.disk_encryption_set_name==null)?1:0

  name = "wsf-${var.job_id}-encryption-set"
  resource_group_name = local.resource_group_name
  location = local.location
  key_vault_key_id = azurerm_key_vault_key.default.0.id

  identity {
    type = "SystemAssigned"
  }

  tags = var.common_tags
}

resource "azurerm_key_vault_access_policy" "disk" {
  count = (var.encrypt_disk && var.disk_encryption_set_name==null)?1:0

  key_vault_id = azurerm_key_vault.default.0.id
  tenant_id = azurerm_disk_encryption_set.default.0.identity.0.tenant_id
  object_id = azurerm_disk_encryption_set.default.0.identity.0.principal_id

  key_permissions = [
    "Create",
    "Delete",
    "Get",
    "Purge",
    "Recover",
    "Update",
    "List",
    "Decrypt",
    "Sign",
    "UnwrapKey",
    "WrapKey",
  ]
}

resource "azurerm_key_vault_access_policy" "user" {
  count = (var.encrypt_disk && var.disk_encryption_set_name==null)?1:0

  key_vault_id = azurerm_key_vault.default.0.id
  tenant_id = data.azurerm_client_config.current.0.tenant_id
  object_id = data.azurerm_client_config.current.0.object_id

  key_permissions = [
    "Create",
    "Delete",
    "Get",
    "Purge",
    "Recover",
    "Update",
    "List",
    "Decrypt",
    "Sign",
    "UnwrapKey",
    "WrapKey",
    "GetRotationPolicy",
  ]
}

resource "azurerm_role_assignment" "example-disk" {
  count = (var.encrypt_disk && var.disk_encryption_set_name==null)?1:0

  scope                = azurerm_key_vault.default.0.id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_disk_encryption_set.default.0.identity.0.principal_id
}

