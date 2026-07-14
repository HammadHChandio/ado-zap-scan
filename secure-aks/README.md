# Secure AKS — Terraform POC

A production-grade, **security-hardened Azure Kubernetes Service (AKS)**
environment as Infrastructure-as-Code, built to Microsoft's
[AKS best practices](https://learn.microsoft.com/en-us/azure/aks/).

> **Status:** Proof of concept. Everything here is opinionated toward security
> by default. See [`docs/architecture.md`](docs/architecture.md) for the design
> diagram and the full controls-to-best-practices mapping.

## What you get

A single `terraform apply` provisions:

- **Private AKS cluster** — no public API server endpoint.
- **Microsoft Entra ID + Azure RBAC** for cluster access; **local accounts
  disabled** (no static admin kubeconfig).
- **User-assigned managed identity** for the control plane and **Workload
  Identity (OIDC)** for pods — zero long-lived credentials.
- **Azure CNI Overlay + Cilium** network policy dataplane.
- **System / user node pool split**, autoscaled across **availability zones**,
  on **Azure Linux** with **host encryption**.
- **Premium Azure Container Registry** — admin disabled, public access off,
  reached via **private endpoint**; nodes pull with **AcrPull** managed identity.
- **Azure Key Vault** — RBAC + purge protection, public access off, private
  endpoint, surfaced to pods via the **CSI Secrets Provider** with rotation.
- **Microsoft Defender for Containers**, **Azure Policy (Gatekeeper)**, and
  **Container Insights** wired to a **Log Analytics** workspace, plus
  control-plane **audit logs**.
- **Auto-upgrade** (stable channel) + **node-image auto-upgrade** with
  maintenance windows, and the **Image Cleaner**.

## Repository layout

```
secure-aks/
├── README.md
├── .gitignore
├── docs/
│   └── architecture.md          # Mermaid diagram + controls mapping
└── terraform/
    ├── versions.tf              # provider pins (azurerm ~> 4.0) + backend stub
    ├── providers.tf             # provider config
    ├── variables.tf             # all inputs (validated)
    ├── locals.tf                # naming + tags
    ├── network.tf               # RG, VNet, subnets, NSG
    ├── identity.tf              # managed identities + role assignments
    ├── log_analytics.tf         # workspace, Container Insights, diagnostics
    ├── acr.tf                   # private container registry
    ├── keyvault.tf              # private key vault
    ├── aks.tf                   # the AKS cluster + user node pool
    ├── outputs.tf
    └── terraform.tfvars.example
```

## Prerequisites

- Terraform **>= 1.6**
- Azure CLI, logged in: `az login`
- An Azure subscription with **Owner** or **User Access Administrator** rights
  (the config creates role assignments).
- The **EncryptionAtHost** feature registered (for `enable_host_encryption = true`):
  ```bash
  az feature register --namespace Microsoft.Compute --name EncryptionAtHost
  az provider register --namespace Microsoft.Compute   # after it shows "Registered"
  ```
  Set `enable_host_encryption = false` to skip this.
- At least one **Entra ID group object ID** for cluster admins (local accounts
  are disabled). Get one you belong to:
  ```bash
  az ad group list --filter "displayName eq 'my-aks-admins'" --query "[].id" -o tsv
  ```

## Usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: subscription_id, admin_group_object_ids, sizing...

terraform init
terraform plan
terraform apply
```

### Connecting to the (private) cluster

Because the API server is private, run kubectl from a host with network
line-of-sight to it — a jumpbox/Bastion in the VNet, a peered network, or:

```bash
# Fetch credentials (Entra ID login; you must be in an admin group)
az aks get-credentials -g <rg> -n <cluster> --overwrite-existing

# Run commands without direct network access to the API server:
az aks command invoke -g <rg> -n <cluster> --command "kubectl get nodes"
```

## Notes on security choices

- **No secrets in git.** `terraform.tfvars`, state files, and `.terraform/`
  are git-ignored. Use a **remote backend** (stub in `versions.tf`) so state —
  which can contain sensitive values — is encrypted and access-controlled.
- **Least privilege.** Role assignments are scoped as tightly as practical
  (AcrPull on the registry, Key Vault Secrets User on the vault, Network
  Contributor on the node subnet only).
- **Defense in depth.** Private endpoints + private cluster + network policy +
  Azure Policy + Defender combine so no single misconfiguration is fatal.

See [`docs/architecture.md`](docs/architecture.md) for recommended hardening
that goes beyond this POC (egress firewall, Bastion, default-deny network
policies, Pod Security Admission, CMK, AMPLS).

## Cost & teardown

This provisions billable resources (AKS Standard tier, Premium ACR, node VMs,
Log Analytics, Defender). Tear down when finished:

```bash
terraform destroy
```

> Key Vault has **purge protection** enabled, so a destroyed vault remains
> soft-deleted (recoverable) until its retention window elapses — by design.
