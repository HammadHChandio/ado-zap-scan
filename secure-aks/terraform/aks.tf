###############################################################################
# Azure Kubernetes Service cluster
#
# Security posture (Microsoft AKS best practices):
#   Identity      : user-assigned managed identity + Workload Identity (OIDC)
#   Access        : Entra ID auth + Azure RBAC, local accounts DISABLED
#   API server    : PRIVATE cluster (no public control-plane endpoint)
#   Networking    : Azure CNI Overlay + Cilium data plane & network policy
#   Node OS       : Azure Linux (CBL-Mariner), host encryption, ephemeral-ready
#   Governance    : Azure Policy add-on (Gatekeeper) enabled
#   Threat detect : Microsoft Defender for Containers
#   Secrets       : Key Vault Secrets Provider (CSI) with rotation
#   Monitoring    : Container Insights via managed identity auth
#   Lifecycle     : auto-upgrade (stable) + node-image auto-upgrade, image cleaner
###############################################################################

resource "azurerm_kubernetes_cluster" "this" {
  name                = "${local.name_prefix}-aks"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  dns_prefix          = "${local.name_prefix}-aks"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier

  # -- Control-plane access ------------------------------------------------
  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false
  private_dns_zone_id                 = "System"
  local_account_disabled              = true

  # -- Identity ------------------------------------------------------------
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_control_plane.id]
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # -- Entra ID + Azure RBAC ----------------------------------------------
  azure_active_directory_role_based_access_control {
    tenant_id              = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  # -- Lifecycle / upgrades ------------------------------------------------
  automatic_upgrade_channel    = "stable"
  node_os_upgrade_channel      = "NodeImage"
  image_cleaner_enabled        = true
  image_cleaner_interval_hours = 48

  # -- System node pool (critical add-ons only) ----------------------------
  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    os_sku                       = "AzureLinux"
    orchestrator_version         = var.kubernetes_version
    vnet_subnet_id               = azurerm_subnet.aks.id
    zones                        = ["1", "2", "3"]
    auto_scaling_enabled         = true
    min_count                    = var.system_node_min_count
    max_count                    = var.system_node_max_count
    host_encryption_enabled      = var.enable_host_encryption
    only_critical_addons_enabled = true
    max_pods                     = 50
    temporary_name_for_rotation  = "systmp"

    upgrade_settings {
      max_surge = "33%"
    }

    node_labels = {
      "nodepool-type" = "system"
    }
  }

  # -- Networking: Azure CNI Overlay + Cilium ------------------------------
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
  }

  # -- Governance: Azure Policy (Gatekeeper) -------------------------------
  azure_policy_enabled = true

  # -- Threat detection: Microsoft Defender for Containers -----------------
  microsoft_defender {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  }

  # -- Monitoring: Container Insights (managed-identity auth) ---------------
  oms_agent {
    log_analytics_workspace_id      = azurerm_log_analytics_workspace.this.id
    msi_auth_for_monitoring_enabled = true
  }

  # -- Secrets: Key Vault CSI provider with rotation -----------------------
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  # -- Cluster autoscaler tuning -------------------------------------------
  auto_scaler_profile {
    balance_similar_node_groups      = true
    expander                         = "least-waste"
    scale_down_unneeded              = "10m"
    scale_down_utilization_threshold = "0.5"
  }

  # -- Maintenance windows -------------------------------------------------
  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Sunday"
    start_time  = "02:00"
    utc_offset  = "+00:00"
  }

  maintenance_window_node_os {
    frequency   = "Weekly"
    interval    = 1
    duration    = 4
    day_of_week = "Saturday"
    start_time  = "02:00"
    utc_offset  = "+00:00"
  }

  tags = local.common_tags

  lifecycle {
    # Node counts drift as the autoscaler works; ignore so Terraform does not
    # fight it on every plan.
    ignore_changes = [
      default_node_pool[0].node_count,
      kubernetes_version, # managed by the auto-upgrade channel
    ]
  }
}

# ---------------------------------------------------------------------------
# User (workload) node pool. Kept separate from the system pool so tenant
# workloads never share nodes with critical control-plane add-ons.
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  name                    = "user"
  kubernetes_cluster_id   = azurerm_kubernetes_cluster.this.id
  vm_size                 = var.user_node_vm_size
  os_sku                  = "AzureLinux"
  mode                    = "User"
  orchestrator_version    = var.kubernetes_version
  vnet_subnet_id          = azurerm_subnet.aks.id
  zones                   = ["1", "2", "3"]
  auto_scaling_enabled    = true
  min_count               = var.user_node_min_count
  max_count               = var.user_node_max_count
  host_encryption_enabled = var.enable_host_encryption
  max_pods                = 50

  upgrade_settings {
    max_surge = "33%"
  }

  node_labels = {
    "nodepool-type" = "user"
  }

  tags = local.common_tags

  lifecycle {
    ignore_changes = [
      node_count,
      orchestrator_version,
    ]
  }
}
