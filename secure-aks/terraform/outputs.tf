###############################################################################
# Outputs
###############################################################################

output "resource_group_name" {
  description = "Resource group containing all POC resources."
  value       = azurerm_resource_group.this.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL used to federate Workload Identity credentials."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "acr_login_server" {
  description = "Login server for the private container registry."
  value       = azurerm_container_registry.this.login_server
}

output "key_vault_uri" {
  description = "URI of the Key Vault backing the CSI secrets provider."
  value       = azurerm_key_vault.this.vault_uri
}

output "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = azurerm_log_analytics_workspace.this.id
}

output "get_credentials_command" {
  description = "Command to fetch kubeconfig. Because the cluster is private, run it from a host with network line-of-sight to the API server (e.g. a jumpbox in the VNet, a peered network, or via `az aks command invoke`)."
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.this.name} --name ${azurerm_kubernetes_cluster.this.name} --overwrite-existing"
}

output "kube_admin_config_note" {
  description = "Reminder that local admin kubeconfig is unavailable by design."
  value       = "local_account_disabled = true; authenticate with your Entra ID identity (member of an admin group). There is no static admin kubeconfig."
}
