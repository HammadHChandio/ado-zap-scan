###############################################################################
# Provider & Terraform version constraints
#
# Pinned to azurerm v4.x, which introduces the renamed arguments used across
# this configuration (e.g. auto_scaling_enabled, host_encryption_enabled,
# automatic_upgrade_channel). Do not downgrade to 3.x without adjusting names.
###############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Recommended: use a remote backend so state (which contains secrets) is
  # stored encrypted and access-controlled, never on a laptop. Configure via
  # `terraform init -backend-config=...` and uncomment below.
  #
  # backend "azurerm" {
  #   resource_group_name  = "rg-tfstate"
  #   storage_account_name = "sttfstateXXXXXX"
  #   container_name       = "tfstate"
  #   key                  = "secure-aks.tfstate"
  #   use_azuread_auth     = true
  # }
}
