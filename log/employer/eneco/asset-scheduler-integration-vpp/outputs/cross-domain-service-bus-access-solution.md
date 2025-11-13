# ADR-PLAT-001: Cross-Domain Service Bus Access

## 1. Status

Proposed (This document serves as the formal platform recommendation in response to the "Asset Scheduling" team's request).

## 2. Business Context

**The Request:** The "Asset Scheduling" (AS) team, in alignment with ADR-AS001 ("Complete Integration"), needs to consume messages from specific topics on the Service Bus (SB) owned by the "VPP" domain. The AS team has asked to access the VPP Key Vault (KV) to retrieve the Service Bus connection string.

**The Systemic Problem:** This request exposes a friction point between two systems.

*   **Business Goal (Reinforcing Loop):** The "Complete Integration" ADR mandates coupling between AS and VPP.
*   **Technical Risk (Balancing Loop):** Security and operational best practices mandate domain isolation. Granting cross-domain Key Vault access or using shared secrets (connection strings) creates a fragile, high-risk system with a large blast radius. The manual management of the SB data plane ("brittleness") compounds this risk.

**The Objective:** To provide a solution that enables the required integration (Business Goal) while enforcing Zero Trust security, domain isolation, and full automation (Technical Reality).

## 3. CAF/WAF Alignment

*   **Cloud Adoption Framework (CAF):** Aligns with the Manage (automation-first) and Secure (identity-based controls) design areas.
*   **Well-Architected Framework (WAF) - Security Pillar:** Implements the core principle of "Identity as the Security Perimeter." We will not use network boundaries or secrets as the primary control; we will use verifiable identity.
*   **WAF - Operational Excellence Pillar:** Directly addresses the identified "brittleness" by mandating an Infrastructure as Code (IaC) solution for the Service Bus data plane, creating a repeatable, auditable, and non-brittle system.

## 4. Recommended Architectural Solution

The platform-approved solution is to use Azure RBAC with Managed Identities. Connection strings (SAS keys) are not to be used, and the VPP Key Vault is not to be shared.

How It Works:

```
|   ASSET SCHEDULING (AS) DOMAIN   |      |        VPP DOMAIN               |
|--------------------------------|      |---------------------------------|
|                                |      |                                 |
|  +--------------------------+  |      |  +---------------------------+  |
|  | AS App (AKS/App Service) |  |      |  | VPP Service Bus             |  |
|  | [Has Managed Identity]   |  |      |  | (vpp-sb.servicebus....)   |  |
|  |                          |  |      |  +---------------------------+  |
|  | - Uses azure-identity    |  |      |               |                 |
|  | - Config: "vpp-sb..."    |  |      |  (4. RBAC Grant)                  |
|  +------------+-------------+  |      |  +-------------+              |
|               |                |      |  | Topic A     |              |
| (1. Auth w/ MI) |                |      |  | (Scope)     | <------------+
|               v                |      |  +-------------+              |
|  +--------------------------+  |      |                                 |
|  | Microsoft Entra ID (AAD) |  |      |  +---------------------------+  |
|  |                          |  |      |  | VPP KEY VAULT               |  |
|  | (2. Get Token)           |  |      |  | (VPP SECRETS - NO ACCESS)   |  |
|  +------------+-------------+  |      |  +---------------------------+  |
|               |                |      |                                 |
|               +---------------------> | (3. Present Token to SB)        |
|                                |      |                                 |
+--------------------------------+      +---------------------------------+
```

## 5. Key Decisions & Trade-Offs

| Decision                               | Rationale                                                                                                                                                           | Trade-off                                                                                                                                                                     |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **USE:** Managed Identity (RBAC) <br> **AVOID:** Connection Strings (SAS) | Eliminates secret management entirely. Access is auditable, revocable, and tied to a single identity. This is the WAF Security pillar's first principle. | Requires application teams (AS) to use the `azure-identity` library (which was confirmed in the chat).                                                                      |
| **USE:** Domain-Scoped IaC <br> **AVOID:** Shared Key Vault | A Key Vault is a critical security and domain boundary. Granting cross-domain access creates a massive blast radius and breaks domain-driven design. This is a Hard "No" from the platform. | The AS team cannot self-serve. This is by design. They must request access from the VPP team, who then grants it via code.                                                    |
| **USE:** Declarative IaC Data Plane <br> **AVOID:** Manual ("Brittle") Data Plane | The "brittleness" Roel identified is a key operational risk. By defining topics, subscriptions, and RBAC assignments in Terraform, the system becomes auditable, repeatable, and stable. | Up-front cost: The VPP team must refactor their Service Bus deployment to manage the data plane (topics, subscriptions) and access (RBAC) in Terraform. This is a non-negotiable requirement to mitigate operational risk. |

## 6. Recommended IaC (Terraform) Implementation

This design establishes a clean "contract" between the teams, managed via code.

**AS Team (Consumer) - main.tf:**

The AS team's code exports its identity.

```terraform
# data.azurerm_client_config "current" {}
# ... or lookup the specific managed identity
data "azurerm_kubernetes_cluster" "aks" {
  name                = "as-aks-cluster"
  resource_group_name = "as-rg"
}

# This is the identity the VPP team needs
output "asset_scheduling_app_principal_id" {
  value = data.azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  description = "The Principal ID to be granted access on the VPP Service Bus."
}
```

**VPP Team (Producer) - main.tf:**

The VPP team's code ingests the AS Principal ID as a variable and creates the specific, scoped role assignment.

```terraform
variable "asset_scheduling_app_principal_id" {
  type        = string
  description = "Principal ID of the AS application."
}

resource "azurerm_servicebus_namespace" "vpp" {
  name                = "vpp-sb"
  # ... other config
}

resource "azurerm_servicebus_topic" "schedules" {
  name                = "schedules"
  namespace_id        = azurerm_servicebus_namespace.vpp.id
}

# This is the specific subscription for AS
resource "azurerm_servicebus_subscription" "as_consumer" {
  name                = "asset-scheduling-consumer"
  topic_id            = azurerm_servicebus_topic.schedules.id
}

#
# THE CRITICAL RESOURCE: Granting scoped access
#
resource "azurerm_role_assignment" "as_consumer_role" {
  scope                = azurerm_servicebus_subscription.as_consumer.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = var.asset_scheduling_app_principal_id
}
```

## 7. Documentation & Verification

**Verification:**

*   `az role assignment list --scope {subscription_id}`
*   `az servicebus topic authorization-rule list ...` (To verify NO SAS keys are used)

**Documentation:**

*   [Authenticate with Managed Identity to Service Bus](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-managed-service-identity)
*   [Service Bus RBAC Roles](https://learn.microsoft.com/en-us/azure/service-bus-messaging/service-bus-managed-service-identity#role-based-access-control)
*   [Terraform azurerm_role_assignment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment)

## 8. Next Steps

*   **For Platform:** Adopt this ADR as the formal pattern for all cross-domain service-to-service communication.
*   **For VPP Team:** Prioritize the refactoring of the Service Bus deployment to manage topics, subscriptions, and RBAC via Terraform. This is a critical risk mitigation.
*   **For AS Team:** Update your application to use the `azure-identity` library and remove all logic related to Key Vault retrieval for this connection string. Your configuration will only require the SB namespace.