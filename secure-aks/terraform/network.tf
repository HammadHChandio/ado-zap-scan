###############################################################################
# Networking
#
# - Dedicated spoke VNet with separate subnets for AKS nodes and private
#   endpoints (least-privilege network segmentation).
# - NSG associated to the AKS subnet.
# - Azure CNI Overlay is used at the cluster level, so the node subnet only
#   hosts node NICs; pods use the overlay pod_cidr.
###############################################################################

resource "azurerm_resource_group" "this" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.common_tags
}

resource "azurerm_virtual_network" "this" {
  name                = "${local.name_prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = var.vnet_address_space
  tags                = local.common_tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks-nodes"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.aks_subnet_prefix]
}

resource "azurerm_subnet" "endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [var.endpoints_subnet_prefix]
}

# ---------------------------------------------------------------------------
# Network Security Group for the AKS node subnet.
# Azure applies sensible platform defaults (allow intra-VNet, deny inbound
# internet, allow Azure Load Balancer). We attach an NSG so the subnet is
# explicitly governed and ready for tightening; add custom rules as needed.
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "aks" {
  name                = "${local.name_prefix}-aks-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}
