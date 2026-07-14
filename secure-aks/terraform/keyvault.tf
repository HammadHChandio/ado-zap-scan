###############################################################################
# Azure Key Vault (private)
#
# - RBAC authorization (no legacy access policies).
# - Purge protection + soft delete so secrets survive accidental deletion.
# - Public access disabled; reachable via private endpoint only.
# - Consumed from the cluster through the Key Vault Secrets Provider (CSI)
#   add-on using Workload Identity — no secrets are stored in the cluster.
###############################################################################

resource "azurerm_key_vault" "this" {
  name                = local.key_vault_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization  = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 90

  public_network_access_enabled = false

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  tags = local.common_tags
}

# Bootstrap access for the operator running Terraform (optional; off in CI).
resource "azurerm_role_assignment" "operator_kv_admin" {
  count                = var.grant_operator_keyvault_admin ? 1 : 0
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# The Key Vault Secrets Provider add-on gets its own managed identity; grant it
# read access to secrets/certs so mounted CSI volumes can be populated.
resource "azurerm_role_assignment" "csi_kv_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].object_id
}

# ---------------------------------------------------------------------------
# Private DNS + private endpoint for Key Vault.
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "kv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv" {
  name                  = "kv-dns-link"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.kv.name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_endpoint" "kv" {
  name                = "${local.name_prefix}-kv-pe"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "kv-psc"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv.id]
  }
}
