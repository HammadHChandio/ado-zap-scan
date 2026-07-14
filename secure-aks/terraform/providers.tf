###############################################################################
# Provider configuration
###############################################################################

provider "azurerm" {
  # azurerm v4 requires an explicit subscription. Prefer authenticating with
  # Azure CLI (`az login`), a managed identity, or an OIDC federated workload
  # in CI — never a hardcoded client secret.
  subscription_id = var.subscription_id

  features {
    key_vault {
      # Keep soft-deleted vaults recoverable; never purge on destroy so a
      # mistaken `terraform destroy` cannot permanently erase secrets.
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }

    resource_group {
      # Fail loudly if a resource group still contains resources at destroy
      # time instead of silently deleting them.
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "azuread" {}

# Current identity running Terraform (used for tenant_id and to grant the
# operator bootstrap access to Key Vault).
data "azurerm_client_config" "current" {}
