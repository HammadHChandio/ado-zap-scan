# Secure AKS — Architecture

This POC provisions a security-hardened Azure Kubernetes Service environment
following Microsoft's [AKS best practices](https://learn.microsoft.com/en-us/azure/aks/).

## High-level architecture

```mermaid
flowchart TB
    subgraph Identity["Microsoft Entra ID"]
        AAD["Entra ID groups<br/>(cluster admins)"]
        WI["Workload Identity<br/>federation (OIDC)"]
    end

    subgraph Ops["Operators / CI"]
        DEV["Platform engineer<br/>(az login)"]
        CI["CI pipeline<br/>(OIDC federated)"]
    end

    subgraph Azure["Azure Subscription — Resource Group"]
        direction TB

        subgraph VNet["Spoke Virtual Network (10.10.0.0/16)"]
            direction TB
            subgraph SnetAks["snet-aks-nodes (NSG)"]
                SYS["System node pool<br/>AzureLinux · zones 1-3<br/>CriticalAddonsOnly"]
                USR["User node pool<br/>AzureLinux · zones 1-3<br/>autoscaled"]
            end
            subgraph SnetPe["snet-private-endpoints"]
                PEACR["Private Endpoint<br/>ACR"]
                PEKV["Private Endpoint<br/>Key Vault"]
            end
        end

        subgraph CP["AKS Control Plane (PRIVATE API server)"]
            API["kube-apiserver<br/>Entra ID + Azure RBAC<br/>local accounts disabled"]
            POL["Azure Policy<br/>(Gatekeeper)"]
            DEF["Defender for<br/>Containers"]
        end

        ACR["Azure Container Registry<br/>Premium · admin off<br/>public access off"]
        KV["Azure Key Vault<br/>RBAC · purge protect<br/>public access off"]
        LAW["Log Analytics<br/>+ Container Insights"]
        UAI["User-assigned<br/>managed identity"]
    end

    DEV -->|Entra auth| API
    CI -->|Entra auth| API
    AAD -.cluster-admin.-> API
    UAI -.control plane.-> CP

    SYS --- API
    USR --- API
    SYS -->|AcrPull via<br/>kubelet MI| PEACR
    USR -->|CSI mount via<br/>Workload Identity| PEKV
    PEACR --- ACR
    PEKV --- KV
    WI -.federated.-> USR

    CP --> LAW
    SYS --> LAW
    USR --> LAW
    DEF --> LAW
    POL --- API

    classDef sec fill:#0b3d91,stroke:#7aa7ff,color:#fff;
    classDef net fill:#1f6f3f,stroke:#7ee0a4,color:#fff;
    classDef data fill:#5a3a86,stroke:#c9a7ff,color:#fff;
    class API,POL,DEF,UAI,WI,AAD sec;
    class SYS,USR,PEACR,PEKV,SnetAks,SnetPe net;
    class ACR,KV,LAW data;
```

## Security controls mapped to AKS best practices

| Area | Control implemented | Best practice reference |
|------|--------------------|------------------------|
| **Authentication** | Microsoft Entra ID integration; local Kubernetes accounts disabled | Cluster security |
| **Authorization** | Azure RBAC for Kubernetes; admin via Entra ID groups only | Cluster security |
| **Identity (control plane)** | User-assigned managed identity (no SP secrets) | Managed identities |
| **Identity (workloads)** | Workload Identity + OIDC issuer (no mounted SA tokens as cloud creds) | Workload Identity |
| **API server exposure** | Private cluster — no public control-plane endpoint | Private clusters |
| **Network dataplane** | Azure CNI Overlay + Cilium network policy (default-deny ready) | Network concepts |
| **Registry** | Premium ACR, admin disabled, public access off, private endpoint, AcrPull via MI | Container image management |
| **Secrets** | Key Vault (RBAC + purge protection) via CSI Secrets Provider with rotation | Secrets / Key Vault |
| **Governance** | Azure Policy add-on (Gatekeeper) for guardrails | Azure Policy for AKS |
| **Threat detection** | Microsoft Defender for Containers | Defender for Containers |
| **Monitoring / audit** | Container Insights + control-plane diagnostic logs (incl. kube-audit) | Monitoring |
| **Node hardening** | Azure Linux OS, host encryption, availability zones, system/user pool split | Node security & upgrades |
| **Patching** | Auto-upgrade channel (stable) + node-image auto-upgrade + maintenance windows | Cluster upgrades |
| **Image hygiene** | Image Cleaner (Eraser) removes vulnerable/unused images | Image cleaner |
| **State security** | Remote backend guidance; state never committed; secrets kept out of git | Operational best practices |

## Traffic & trust flow

1. **Admins/CI authenticate to Entra ID**, receive a token, and are authorized
   by **Azure RBAC**. There is no static admin kubeconfig — `local_account_disabled = true`.
2. The **API server is private**; reach it from a jumpbox in/peered to the VNet
   or via `az aks command invoke`.
3. **Nodes pull images** from ACR over a **private endpoint** using the kubelet
   managed identity's **AcrPull** role — no registry passwords in the cluster.
4. **Workloads read secrets** from Key Vault via the **CSI Secrets Provider**,
   federated through **Workload Identity** — no long-lived credentials.
5. **Defender for Containers**, **Azure Policy**, and **Container Insights**
   continuously assess, enforce, and observe the cluster, shipping to
   **Log Analytics**.

## Hardening beyond this POC (recommended next steps)

- Replace `outbound_type = loadBalancer` with **Azure Firewall + User Defined
  Routing** (or a NAT Gateway) for controlled, inspected egress.
- Add a **hub VNet** with the firewall and a **jumpbox/Bastion** for private
  API access.
- Enforce a **default-deny** `CiliumNetworkPolicy` per namespace.
- Apply **Pod Security Admission** (`restricted`) and specific Azure Policy
  initiatives (e.g. *Kubernetes cluster pod security baseline standards*).
- Enable **private link for Log Analytics** (AMPLS) and customer-managed keys
  (CMK) for ACR, Key Vault, and OS/data disks.
