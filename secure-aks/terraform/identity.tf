###############################################################################
# Managed identities & role assignments
#
# - The AKS control plane uses a user-assigned managed identity (no service
#   principal secrets to rotate or leak).
# - The kubelet identity is created by AKS and granted AcrPull on the registry.
# - Network Contributor on the AKS subnet lets the control plane manage the
#   load balancer and node NICs (required with a BYO subnet + user-assigned
#   identity).
###############################################################################

resource "azurerm_user_assigned_identity" "aks_control_plane" {
  name                = "${local.name_prefix}-aks-identity"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.common_tags
}

# Allow the control-plane identity to manage networking within the node subnet.
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_subnet.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_control_plane.principal_id
}

# Grant the kubelet (node) identity pull access to the private registry so
# nodes can pull images without any registry credentials in the cluster.
resource "azurerm_role_assignment" "kubelet_acr_pull" {
  scope                            = azurerm_container_registry.this.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}
