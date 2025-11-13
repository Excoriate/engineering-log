# ADR-PLAT-002: Interim Cross-Domain Service Bus Access (Stopgap)

## 1. Status

Proposed (This document serves as a tactical, temporary addendum to ADR-PLAT-001).

## 2. Business Context

**The Problem:** The "Asset Scheduling" (AS) team is currently blocked. To proceed with their integration work (ADR-AS001), they require access to the VPP Service Bus. The strategic solution, ADR-PLAT-001 (Managed Identity + RBAC), requires a significant, non-trivial refactoring effort from the "VPP" team to automate their "brittle" data plane via IaC. This creates a deadlock where the AS team's progress is coupled to the VPP team's refactoring timeline.

**The Objective:** To provide a temporary, middle-line solution that unblocks the AS team immediately. This solution must be:

*   Fast to implement (hours, not weeks).
*   Safer than the initial request (sharing the VPP Key Vault).
*   Explicitly time-boxed to create a forcing function that ensures migration to the strategic solution (ADR-PLAT-001).

This ADR is the creation of sanctioned technical debt. We are taking out a "loan" on speed, and this document defines the terms and the mandatory repayment plan.

## 3. CAF/WAF Alignment

This is a tactical compromise, but it is still guided by WAF principles.

*   **WAF Security Pillar:** We are applying the Principle of Least Privilege. While we are using a connection string (a secret), we will not use the namespace-level "god mode" key. We will create a new, dedicated, and a tightly-scoped key. We also enforce domain isolation by not sharing Key Vaults.
*   **WAF Operational Excellence:** This solution manages the risk of the "brittle" data plane (identified in adr-plat-001-sb-access.md) by acknowledging it and creating a governance-based balancing loop (i.e., a 90-day deprecation) to force its resolution.

## 4. Recommended Architectural Solution (The Stopgap)

The platform will deny the request for cross-domain Key Vault access. Instead, the approved temporary solution is the creation of a new, topic-scoped connection string that is securely stored in the AS team's own Key Vault.

```
|   ASSET SCHEDULING (AS) DOMAIN   |      |        VPP DOMAIN                        |
|--------------------------------|      |------------------------------------------|
|                                |      |                                          |
|  +--------------------------+  |      |  +------------------------------------+  |
|  | AS App (AKS/App Service) |  |      |  | VPP Service Bus Namespace          |  |
|  |                          |  |      |  |                                    |  |
|  |  (3. Reads from own KV)  |  |      |  |  +------------------------------+  |  |
|  +------------+-------------+  |      |  |  | Topic: 'schedules'           |  |  |
|               ^                |      |  |  |                              |  |  |
|               |                |      |  |  | (1. Create Topic-Scoped      |  |  |
|  +------------+-------------+  |      |  |  |     SAS Policy w/ 'Listen'   |  |  |
|  | AS KEY VAULT             |  |      |  |  +------------------------------+  |  |
|  |                          |  |      |  +------------------------------------+  |
|  | (2. Store Secret Here)   |  |      |               ^                        |
|  +--------------------------+  |      |               | (MANUAL STEP)          |
|               ^                |      |  +------------+-------------+         |
|               |                |      |  | VPP KEY VAULT              |         |
|               +----------------------+  |  | (VPP SECRETS - NO ACCESS)  |         |
|                 (Secure Transfer)       |  +----------------------------+         |
|                                |      |                                          |
+--------------------------------+      +------------------------------------------+
```

## 5. Key Decisions & Trade-Offs

| Decision                               | Rationale                                                                                                                                                           | Trade-off                                                                                                                                                                     |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **USE:** New, Topic-Scoped SAS <br> **AVOID:** Namespace-Scoped SAS | Least Privilege. A namespace-scoped key is a "god key" that can Manage, Send, and Listen to all topics. A Listen-only, topic-scoped key reduces the blast radius by >99%. If leaked, the attacker can only listen to one topic. | The VPP team must perform a manual creation step. This is an acceptable, one-time cost to mitigate a major security risk.                                                    |
| **USE:** AS Team's Own Key Vault <br> **AVOID:** Shared VPP Key Vault | Domain Isolation. Key Vaults are security and domain boundaries. The AS team is responsible for the secrets it consumes. The VPP team is not responsible for managing access for other domains to its vault. | The connection string secret is now stored in two places (VPP's SAS policies, AS's KV). This is a known, acceptable risk for a temporary solution. |

## 6. Recommended IaC Snippets (The Stopgap)

These snippets illustrate the resources involved in this temporary solution.

### 6.1. VPP Team (Producer) - vpp_servicebus.tf

This is the Terraform code that should be in place to manage the Service Bus data plane. The creation of this resource is the "manual step" required of the VPP team, as their system is currently brittle. The output of this resource is the connection string to be transferred.

```terraform
resource "azurerm_servicebus_topic" "schedules" {
  name         = "schedules"
  namespace_id = azurerm_servicebus_namespace.vpp.id # Assumes namespace exists
}

#
# THE CRITICAL RESOURCE: The "Least-Privilege Secret"
# This policy is scoped to the 'schedules' topic ONLY.
#
resource "azurerm_servicebus_topic_authorization_rule" "as_consumer_sas" {
  name     = "as-consumer-listen-only"
  topic_id = azurerm_servicebus_topic.schedules.id

  # Enforce LEAST PRIVILEGE: Only 'Listen' is required.
  listen = true
  send   = false
  manage = false
}

# This is the connection string to be securely transferred to the AS team.
output "asset_scheduling_connection_string" {
  value     = azurerm_servicebus_topic_authorization_rule.as_consumer_sas.primary_connection_string
  sensitive = true
}
```

### 6.2. AS Team (Consumer) - as_keyvault.tf

The AS team takes the connection string (provided "out-of-band") and stores it in their own Key Vault using their own IaC pipeline.

```terraform
variable "vpp_schedules_topic_connection_string" {
  type        = string
  description = "The topic-scoped SAS connection string provided by the VPP team."
  sensitive   = true
}

resource "azurerm_key_vault" "as_vault" {
  name                = "kv-as-prod"
  resource_group_name = "rg-as-prod"
  location            = "WestEurope"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Use RBAC for vault access
  enable_rbac_authorization = true
}

# Store the provided connection string in the AS Key Vault
resource "azurerm_key_vault_secret" "vpp_sb_connection" {
  name         = "vpp-schedules-topic-connection-string"
  key_vault_id = azurerm_key_vault.as_vault.id
  value        = var.vpp_schedules_topic_connection_string
}

# Grant the AS Application's Managed Identity access to its OWN vault
resource "azurerm_role_assignment" "as_app_kv_access" {
  scope                = azurerm_key_vault.as_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azurerm_kubernetes_cluster.as_aks.kubelet_identity[0].object_id # Example identity
}
```

## 7. The Forcing Function: This Is Temporary

This solution (ADR-PLAT-002) is approved under the following non-negotiable conditions:

*   **Time-boxed:** This solution is valid for a maximum of 90 days.
*   **Backlog Commitment:** The VPP team must create and prioritize the backlog items to implement the ADR-PLAT-001 IaC refactor within this 90-day window.
*   **Platform Review:** A platform review will be automatically scheduled 90 days from the approval of this ADR to ensure the permanent solution is in place and to deprecate this temporary access policy.

This conditional approval creates the necessary balancing feedback loop. It unblocks the AS team (satisfying the business) while creating a hard deadline that forces the VPP team to resolve the underlying systemic risk (the "brittle" data plane).

## 8. Next Steps

**For VPP Team (Immediate):**

*   Manually create the new, Listen-only SAS policy on the `schedules` topic (per snippet 6.1).
*   Securely transfer the resulting connection string to the AS team lead.

**For AS Team (Immediate):**

*   Add this secret to your `as-keyvault` via your standard IaC process (per snippet 6.2).
*   Update your application configuration to consume this new secret.

**For VPP Team (This Sprint):**

*   Create the P1/P0 backlog items to refactor the Service Bus deployment to use Terraform for topics, subscriptions, and RBAC, as defined in ADR-PLAT-001.

**For Platform (This Sprint):**

*   Schedule a follow-up review in 90 days to deprecate this ADR.