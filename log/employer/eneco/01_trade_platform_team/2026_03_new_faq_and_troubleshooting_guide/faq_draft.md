# Myriad Platform — FAQ

> **Maintained by:** Trade Platform Team (Trade IT)
> **Last updated:** March 2026
> **Companion document:** [Troubleshooting Guide](./troubleshooting_guide.md)
>
> This FAQ covers **"How do I…"** procedural questions. For **"Something is broken"** diagnostic issues, see the [Troubleshooting Guide](./troubleshooting_guide.md).
>
> Every answer is derived from a verified Slack conversation. Links to the original threads are provided.

---

## Onboarding & Access

### How do I onboard a new team member to VPP?

Follow the **onboarding checklist** in the Myriad VPP wiki. Your team's buddy should walk the new joiner through the list step by step.

**Example checklist:** [Onboarding checklist — Anastasia Zenchik](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki/61771/Onboarding-checklist-Anastasia-Zenchik)

The checklist covers: ADO access and license level, repo permissions, ArgoCD access, Azure resource groups, Axual/ESP, Grafana dashboards, Gurobi portal, and OpenShift UI.

**What typically goes wrong:** The biggest pitfall is the ADO license level. If a new joiner can see the wiki but gets a 403 on repos, they're on a Stakeholder license instead of Basic (see next question).

> 📎 **Slack thread:** [Erik Lumbela onboarding — Feb 3, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1770117326150619) (56 replies)
> Roel: *"Are you guys following the onboarding guide for Erik? … Most of this stuff is covered in there already. Your team/buddy should do this with you."*

---

### How do I fix a "403 on repos" error for a new ADO user?

The user's Azure DevOps license is set to **Stakeholder** instead of **Basic**. Stakeholder users can view wikis and boards but cannot access Git repositories.

**Fix:** Request a Basic license via this ServiceNow form:
→ [ADO License Change Form](https://eneco.service-now.com/esc?id=sc_cat_item&sys_id=5a21cbb7dba75810b6570149f49619fe)

**How to verify the current license level** (if you have a PAT):
```bash
curl -s -u ":$AZURE_DEVOPS_PAT" \
  'https://vsaex.dev.azure.com/enecomanagedcloud/_apis/userentitlements?$filter=name%20eq%20%27User.Name%40eneco.com%27&api-version=7.1'
```
Look for `accountLicenseType` in the response. If it says `stakeholder`, that's the problem.

> 📎 **Slack thread:** [Erik Lumbela onboarding — Feb 3, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1770117326150619)
> Fabrizio: *"Use this form to change the ADO license to basic."*
> Alex Torres confirmed root cause via ADO API: `"accountLicenseType": "stakeholder"`.

---

### How do I add someone to an Azure AD group (e.g., Grafana access, BTM business users)?

**Self-service via PR:** Raise a PR in [`Eneco.Infrastructure`](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Infrastructure), modifying the relevant Terraform file.

**Example for BTM business users:**
File: `terraform/platform/aad/groups-btm.tf`

Add the new member's email to the group, keeping names **sorted alphabetically**. Link a work item from your own board to the PR.

> 📎 **Slack thread:** [Johnson adding BTM users — Jan 28, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769614171208009) (15 replies)
> Fabrizio: *"Just raise a PR."* — linking directly to `Eneco.Infrastructure`.
> Roel: *"You can link a board item from your own board."*

---

### How do I get ArgoCD repository connections for a new service (e.g., Asset Scheduling gitops)?

Request it in #myriad-platform. The Platform team creates the repository connection in ArgoCD for each environment (DEV, ACC, PROD) and manages PAT renewal transparently.

**You do not need:** ServiceNow tickets, special approvals, or access to the gitops-vpp repo yourself.

**Example:** When Asset Scheduling needed ArgoCD repo connections for ACC and PROD, Roel created them directly and confirmed PAT lifecycle is the platform team's responsibility.

> 📎 **Slack thread:** [ArgoCD for Asset Scheduling — Jan 8, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1767869449760609) (6 replies)
> Roel: *"The repositories have been created in acc and prod ArgoCD. PAT renewal is our responsibility and will be handled transparently."*

---

### How do I get ArgoCD sync permissions on ACC or PROD?

Request elevation in #myriad-platform. The Platform team grants sync permissions per environment.

> 📎 **Slack thread:** [Martijn requesting ACC sync — Jan 27, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769512160798059) (11 replies, resolved)

---

### How do I get a SonarCloud project created for a new service?

Request it in #myriad-platform with the service name and the repo it lives in. The Platform team will:
1. Create the SonarCloud project.
2. Post the `sonarCloudProjectKey` in your PR.
3. Provision CI and CD pipelines in Azure DevOps.

**Note:** Automation for SonarCloud provisioning is under development. Until then, the platform team handles it manually.

**Example:** When Core needed a SonarCloud project for Watchtower, Roel created it, posted the key, and provisioned both pipelines.

> 📎 **Slack thread:** [SonarCloud for Watchtower — Jan 23, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769151397502779) (10 replies)
> Roel: *"We're working on an account so we can automate it. I'll make it for you this time."* And: *"I've also provisioned the CI and CD pipelines in Azure DevOps."*

---

### How do I get Entra ID access to the PostgreSQL databases (e.g., assetsched)?

The PostgreSQL databases are **VNet-integrated with no public access**. You must connect from **AVD** (Azure Virtual Desktop), not from your local machine at home.

**Login method:**
- **Username:** `AAD-Administrator`
- **Token:** Generate via Azure CLI:
  ```bash
  az account get-access-token \
    --resource https://ossrdbms-aad.database.windows.net \
    --query accessToken \
    --output tsv
  ```

**Common pitfall:** If `nslookup <db-host>.postgres.database.azure.com` from AVD returns a public IP (e.g., `4.180.x.x`) instead of a private IP (`10.7.x.x`), the DNS zone is not configured for your network. Escalate to the platform team.

> 📎 **Slack thread:** [Postgres access for Asset Scheduling — Jan 15, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1768485429303609) (10 replies)
> Martijn: *"If you want to login, you use the AAD-Administrator as username, then provide a token with the az account get-access-token command."*
> Roel on DNS: *"I see a weird DNS result from AVD. An nslookup returns [public IP]. The private endpoints IP is 10.7.224.38."*

---

### How do I get access to the Gurobi portal (ACC/PROD)?

**Self-service via PR:** Raise a PR in [`Eneco.Infrastructure`](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Infrastructure) adding yourself to the Gurobi portal AD groups for ACC and/or PROD.

> 📎 **Slack thread:** [Chantal adding herself to Gurobi — Jan 9, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1767961455061079)

---

### How do I get CCoE repo permissions (e.g., terraform-azure-keyvault)?

Request permissions through the Platform team in #myriad-platform. They can also help create new version tags after your PR is merged.

> 📎 **Slack thread:** [Manu requesting CCoE access — Jan 5, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1767619595677909) (2 replies)

---

### How do I get Grafana data source access?

**Self-service via PR:** Raise a PR in [`Eneco.Infrastructure`](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/Eneco.Infrastructure) adding your email to the relevant AD group for the data source.

> 📎 **Slack thread:** [Satyabrat requesting Grafana data sources — Jan 30, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769767603180789) (19 replies)

---

## CI/CD & Pipelines

### How do I subscribe to an Azure Service Bus topic?

Use the **Service Bus Subscriptions Manager** — a self-service, declarative tool. No Terraform or Terragrunt knowledge needed.

**Steps:**
1. Create a YAML contract file following the [schema](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/servicebus-subscriptions-manager?path=/contracts/schema.yaml).
2. Submit a PR to [`servicebus-subscriptions-manager`](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/servicebus-subscriptions-manager).
3. The **producer team** reviews and approves (e.g., for VPP Core topics, the VPP Backend team approves under `/contracts/producers/vpp_core/*`).
4. On merge: CD auto-deploys to sandbox; manual deploy to `mc_dev`, `mc_acc`, `mc_prod`.

**What you get:** Service Bus subscription + RBAC permissions, automatically provisioned across environments.

📖 [Quick Start Guide](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/servicebus-subscriptions-manager?path=/docs/guides) | 📚 [Full Docs](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/servicebus-subscriptions-manager?path=/docs)

> 📎 **Slack thread:** [Service Bus Subscriptions Manager announcement — Jan 9, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1767946999261089) (Alex Torres)

---

### How do I automate E2E tests in a pipeline without maintaining client secrets?

Use **Workload Identity Federation** with an Azure DevOps Service Connection. This eliminates the need for client secrets entirely.

**How it works for .NET tests:**
1. Create a Service Connection in Azure DevOps with Workload Identity Federation.
2. Use the Azure DevOps `DotNetCoreCLI` task, passing the service connection via `connectedService`.
3. Use `AzurePipelinesCredential` in your code (not `DefaultAzureCredential`) — it requires `clientId`, `tenantId`, `serviceConnectionId`, and `systemAccessToken`. Expose `SYSTEM_ACCESSTOKEN` via the pipeline's `env` block.

**Note:** If your tests also interact with **Kafka** (e.g., BTM E2E tests), you'll need self-hosted runners for network access, but the workload identity approach still works.

> 📎 **Slack thread:** [BTM E2E test automation — Jan 23, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769166716434969) (24 replies)
> Roel: *"A serviceconnection setup with workload identity federation would solve the clientsecret issue. And then — assuming you're doing dotnet test, you can use the Azure DevOps Dotnet tasks, which allow you to pass a serviceconnection."*

---

### My pipeline needs permission to access variable groups. Who grants it?

Post the **pipeline link** (with the permissions prompt visible) in #myriad-platform. The Platform team approves variable group access.

> 📎 **Slack thread:** [BTM variable group permissions — Jan 27, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769524890841279) (2 replies, resolved)

---

### How do I add or change a feature flag?

Create PRs to [`VPP-Configuration`](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/VPP-Configuration) — **one PR per environment** (dev-mc, acc, prod). The Platform team reviews and approves.

> 📎 **Slack thread:** [Feature flag tenantEliaEnabled — Feb 2, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1770020236344699)

---

### Can we change PR approval requirements (e.g., reduce reviewer count, stop QA spam)?

Yes. The Platform team can create **per-team tester groups** and update branch policies to target the correct group per repo.

**Trade-off to consider:** A single-person reviewer group blocks PRs when that person is sick or on leave.

**Example:** Anastasia (QA) was getting spammed with PRs from repos her team doesn't contribute to. Roel proposed per-team tester groups and offered to adjust branch policies.

> 📎 **Slack thread:** [QA reviewer spam — Jan 30, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769777403411839) (25 replies)
> Roel: *"I agree. We could use a tester group per team and fix the branch policies."* Also: *"If we make a group with 1 tester in it: you. And then you get sick, PR's will be blocked."*

---

### Who approves infrastructure pipeline runs?

The **Platform team** approves infrastructure pipeline runs for sandbox sync, ACC, and PROD. Post the pipeline link in #myriad-platform.

**Important:** **Release configuration changes** should go to the **release managers group**, not the platform team.

> 📎 **Slack thread:** [Release approval responsibility — Feb 4, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1770196287968209)
> Roel: *"I will click approve but I also am going to change the approval to the release managers group because we should not be in this process."*

---

## Infrastructure

### How do I safely rename/move a Terraform resource without destroying it?

Use a **`moved` block** in a temporary `moved.tf` file. This tells Terraform the resource was renamed, not deleted.

**Example:** When the `manage_indexes` flag was moved from one collection map to another, Terraform planned to destroy and recreate the CosmosDB collection (data loss). The fix:

```hcl
# moved.tf — temporary file, remove after deploying to PROD
moved {
  from = module.cosmosdbmongo_account_clientgateway.azurerm_cosmosdb_mongo_collection.mongodb_collection_managed_indexes["Monitor.Monitor_Schedules"]
  to   = module.cosmosdbmongo_account_clientgateway.azurerm_cosmosdb_mongo_collection.mongodb_collection["Monitor.Monitor_Schedules"]
}
```

**Lifecycle:**
1. Create `moved.tf` with the correct `from` → `to` mapping.
2. Run `terraform plan` to verify the destroy is gone.
3. Deploy through all environments (DEV → ACC → PROD).
4. **Remove `moved.tf`** after PROD deployment to keep the codebase clean.

> 📎 **Slack thread:** [Terraform scary plan — Jan 22, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769073434784389) (14 replies)
> Fabrizio provided the exact `moved` block syntax. *"We just need to remove it after the terraform apply, just to keep the code base clean."*
> Also: [CosmosDB unexpected replace during release — Jan 29, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769687072104589) (9 replies, same pattern)

---

## DNS & Maintenance

### Do I need a CMC ticket for DNS entries on new private endpoints?

**No — not anymore.** Since January 2026, private DNS zones are managed automatically via **Azure Policy**. New private endpoints get DNS entries created automatically across all subscriptions (DEV, ACC, PROD).

DNS TTLs are set to **10 seconds** (Microsoft's recommended value, down from the previous 10 minutes).

> 📎 **Slack threads:**
> [DNS automation PROD — Jan 27, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769503252951559) (Fabrizio: *"This change will completely remove the need to raise tickets to CMC."*)
> [DNS migration DEV — Jan 9, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1767950186622969) (Roel: migration from manual to Azure Policy-managed DNS)

---

### When are ESP certificates renewed?

The Platform team handles renewal and communicates the schedule in advance via `@here` in #myriad-platform. Rollout order: **DEV → ACC → PROD**, typically over one week.

> 📎 **Slack thread:** [ESP cert renewal DEV — Jan 2, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1767341799301659) (Fabrizio: DEV updated, ACC and PRD scheduled for next week)

---

## Platform Team Communication

### Where can I find what the Platform team is working on?

The team publishes a living document in the style of [The Radiating Programmer](https://dev.37signals.com/the-radiating-programmer/):

📄 **[Platform Team Radiating Document](https://eneco-my.sharepoint.com/:w:/p/thomas_obrien/IQC1pgpeaOPnSKxgWLQRu9KQAWUtW4CF6TMmbQtFZVxDDWo?e=G06zI1)**

Covers: what the team is doing, how, problems encountered, and decisions made. Also pinned in #myriad-platform.

> 📎 **Slack thread:** [Radiating Programmer announcement — Jan 12, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1768205659009009) (Thomas)

---

## How to Request Help

As of March 2026, #myriad-platform uses a **structured Slack Lists workflow**. Requests are automatically categorized and acknowledged:

| Request Type | What it covers |
|---|---|
| **Review PR** | Infrastructure PR reviews (auto-detected) |
| **General Request** | Catch-all for ad-hoc needs |
| **ADO Access** | Adding users to Azure DevOps |
| **CICD Request** | Pipeline-related issues |

When posting, include: what you're trying to do, what you've tried, a pipeline/PR link, and the environment (sandbox / dev-mc / acc / prod).

---

*Every answer in this FAQ is derived from verified Slack thread content from #myriad-platform, January 2025–March 2026.*
