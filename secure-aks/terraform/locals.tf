###############################################################################
# Locals: naming convention and common tags
###############################################################################

locals {
  # Deterministic, human-readable naming: <prefix>-<env>-<resource>
  name_prefix = "${var.prefix}-${var.environment}"

  # ACR names must be globally unique, alphanumeric, no hyphens. Append a
  # short random suffix to avoid collisions.
  acr_name = lower("${var.prefix}${var.environment}acr${random_string.suffix.result}")

  # Key Vault names must be globally unique, 3-24 chars, alphanumeric + hyphen.
  key_vault_name = substr("${var.prefix}-${var.environment}-kv-${random_string.suffix.result}", 0, 24)

  common_tags = merge(
    {
      environment = var.environment
      workload    = "secure-aks"
      managed_by  = "terraform"
      cost_center = "platform-engineering"
    },
    var.tags
  )
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}
