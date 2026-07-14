###############################################################################
# Observability: Log Analytics workspace
#
# Central workspace backing Container Insights (oms_agent) and Microsoft
# Defender for Containers. Diagnostic settings ship control-plane logs here.
###############################################################################

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${local.name_prefix}-law"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = local.common_tags
}

# Container Insights solution for rich AKS monitoring dashboards.
resource "azurerm_log_analytics_solution" "container_insights" {
  solution_name         = "ContainerInsights"
  location              = azurerm_resource_group.this.location
  resource_group_name   = azurerm_resource_group.this.name
  workspace_resource_id = azurerm_log_analytics_workspace.this.id
  workspace_name        = azurerm_log_analytics_workspace.this.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  tags = local.common_tags
}

# Route AKS control-plane logs (API server, audit, scheduler, etc.) to the
# workspace for auditing and threat detection.
resource "azurerm_monitor_diagnostic_setting" "aks" {
  name                       = "aks-diagnostics"
  target_resource_id         = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  enabled_log { category = "kube-apiserver" }
  enabled_log { category = "kube-audit-admin" }
  enabled_log { category = "kube-controller-manager" }
  enabled_log { category = "kube-scheduler" }
  enabled_log { category = "cluster-autoscaler" }
  enabled_log { category = "guard" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
