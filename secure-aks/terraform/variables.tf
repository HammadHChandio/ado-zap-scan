###############################################################################
# Input variables
###############################################################################

variable "subscription_id" {
  description = "Azure subscription ID to deploy into."
  type        = string
}

variable "prefix" {
  description = "Short lowercase prefix for resource names (2-10 alphanumeric chars)."
  type        = string
  default     = "secaks"

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.prefix))
    error_message = "prefix must be 2-10 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Environment name (e.g. dev, test, prod). Used in naming and tags."
  type        = string
  default     = "poc"

  validation {
    condition     = contains(["poc", "dev", "test", "stage", "prod"], var.environment)
    error_message = "environment must be one of: poc, dev, test, stage, prod."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "kubernetes_version" {
  description = "Kubernetes control plane version. Leave null to let AKS pick the default; the auto-upgrade channel keeps it patched afterwards."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "AKS control plane SKU. 'Standard' provides the uptime SLA and is recommended for anything beyond throwaway testing. Use 'Free' only for cheap experiments."
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard, or Premium."
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "Address space for the spoke virtual network."
  type        = list(string)
  default     = ["10.10.0.0/16"]
}

variable "aks_subnet_prefix" {
  description = "Address prefix for the AKS node subnet."
  type        = string
  default     = "10.10.1.0/24"
}

variable "endpoints_subnet_prefix" {
  description = "Address prefix for the private-endpoints subnet."
  type        = string
  default     = "10.10.2.0/24"
}

variable "pod_cidr" {
  description = "Overlay pod CIDR (Azure CNI Overlay). Must not overlap the VNet."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Kubernetes service CIDR. Must not overlap the VNet or pod CIDR."
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "Cluster DNS service IP. Must be inside service_cidr."
  type        = string
  default     = "172.16.0.10"
}

# ---------------------------------------------------------------------------
# Node pools
# ---------------------------------------------------------------------------

variable "system_node_vm_size" {
  description = "VM size for the system node pool (runs critical add-ons only)."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "system_node_min_count" {
  description = "Minimum nodes in the autoscaling system pool."
  type        = number
  default     = 2
}

variable "system_node_max_count" {
  description = "Maximum nodes in the autoscaling system pool."
  type        = number
  default     = 4
}

variable "user_node_vm_size" {
  description = "VM size for the user (workload) node pool."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "user_node_min_count" {
  description = "Minimum nodes in the autoscaling user pool."
  type        = number
  default     = 2
}

variable "user_node_max_count" {
  description = "Maximum nodes in the autoscaling user pool."
  type        = number
  default     = 6
}

variable "enable_host_encryption" {
  description = <<-EOT
    Enable encryption-at-host on node VMs (data on the VM host is encrypted at
    rest). This is a best practice but requires the EncryptionAtHost feature to
    be registered on the subscription first:
      az feature register --namespace Microsoft.Compute --name EncryptionAtHost
    Set to false if you have not registered the feature yet.
  EOT
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Identity / access
# ---------------------------------------------------------------------------

variable "admin_group_object_ids" {
  description = <<-EOT
    Microsoft Entra ID group object IDs that receive cluster-admin via Azure
    RBAC. Local Kubernetes accounts are disabled, so at least one valid group
    is required to administer the cluster. Add the object ID of a group you
    are a member of.
  EOT
  type        = list(string)
  default     = []
}

variable "grant_operator_keyvault_admin" {
  description = "Grant the identity running Terraform 'Key Vault Administrator' so it can bootstrap secrets. Set false in CI where the runner should not have standing access."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Additional tags merged onto every resource."
  type        = map(string)
  default     = {}
}
