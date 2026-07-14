###############################################################################
# Azure Container Registry (private)
#
# - Premium SKU (required for private endpoints, geo-replication, content trust).
# - Admin user disabled: pulls use the kubelet managed identity (AcrPull).
# - Public network access disabled; reachable only via a private endpoint on
#   the spoke VNet.
###############################################################################

resource "azurerm_container_registry" "this" {
  name                          = local.acr_name
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false

  # Block anonymous pulls and reject data-plane operations that bypass the
  # private endpoint.
  anonymous_pull_enabled     = false
  network_rule_bypass_option = "AzureServices"

  # Retain untagged manifests for a limited window, then purge to reduce
  # attack surface and cost.
  retention_policy_in_days = 30

  trust_policy_enabled = true

  tags = local.common_tags
}

# ---------------------------------------------------------------------------
# Private DNS + private endpoint so nodes resolve the registry privately.
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "acr" {
  name                = "privatelink.azurecr.io"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "acr" {
  name                  = "acr-dns-link"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.acr.name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = local.common_tags
}

resource "azurerm_private_endpoint" "acr" {
  name                = "${local.name_prefix}-acr-pe"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "acr-psc"
    private_connection_resource_id = azurerm_container_registry.this.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "acr-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.acr.id]
  }
}
