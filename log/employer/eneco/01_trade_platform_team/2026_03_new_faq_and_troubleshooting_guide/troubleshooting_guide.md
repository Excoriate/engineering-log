# Myriad Platform — Troubleshooting Guide

> **Maintained by:** Trade Platform Team (Trade IT)
> **Last updated:** March 2026
> **Companion document:** [FAQ](./faq_draft.md)
>
> This guide covers **"Something is broken"** diagnostic issues. For **"How do I…"** procedural questions, see the [FAQ](./faq_draft.md).
>
> Every resolution is derived from a verified Slack conversation. Links to the original threads are provided.

---

## Feature Branch Environments (FBE)

### FBE creation pipeline failed

**Symptoms:** The FBE creation pipeline shows a red status. Common errors include `PartiallySucceeded`, `Internal Server Error` on ADX cluster creation, or Terraform failures.

**Triage steps:**

1. **Check the pipeline logs** — look for the specific error message in the failed step.
2. **Retry the pipeline** — transient Azure API errors are the most common cause and usually resolve on a second attempt. This is the single most effective fix.
3. **Check your branch** — make sure you've merged the latest from `main` before retrying. Stale infrastructure templates cause drift failures.
4. **If the error says "resource already exists"** — a previous FBE on the same slot was not cleaned up. You cannot self-fix this. Post the pipeline link in #myriad-platform.

**When to escalate:** If the error persists after one retry, or if the error involves resource conflicts.

**Example:** In January 2026, at least 5 different developers hit FBE creation failures in the same week. Most resolved on retry. The "resource already exists" cases required platform team intervention to clean orphaned Azure resources.

> 📎 **Slack threads:**
> [Artem — FBE creation failed, Jan 23, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769168718309749) (4 replies)
> [Srinath — FBE creation failing, Jan 27, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769506533924119) (4 replies)
> [Alexandre — FBE pipeline failing, Jan 14, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1768378085358579) (1 reply, resolved)
> [Artem — FBE stuck for 2 hours, Jan 13, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1768313804912409) (9 replies)

---

### FBE delete/destroy pipeline failed

**Symptoms:** The FBE deletion pipeline shows red. Terraform destroy failed partway through.

**Impact:** Orphaned Azure resources (ADX clusters, CosmosDB accounts, resource groups) remain in the subscription. This **blocks future FBE creations** on the same environment slot, because the next creation will see "resource already exists."

**What to do:** Post the failed pipeline link in #myriad-platform. The platform team will clean up orphaned state — this requires manual intervention (e.g., `terraform state rm`, Azure resource deletion).

**Prevention:** Always verify your FBE deletion completed before abandoning the environment. If it failed, report it immediately rather than waiting.

> 📎 **Slack threads:**
> [Tiago — FBE destroy failed, Jan 19, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1768824216175139) (7 replies): *"My FBE failed to be destroyed, can someone have a look? So we can prevent other people having issues when creating."*
> [Hein — FBE delete pipeline failed, Jan 17, 2025](https://eneco-online.slack.com/archives/C063SNM8PK5/p1737119147283369) (10 replies)

---

### FBE creation is green but tests fail / frontend is not accessible

**Symptoms:** The pipeline shows green, but post-creation smoke tests fail or the FBE's frontend URL returns errors.

**Possible causes:**
- Configuration drift between the FBE template and the current application code.
- DNS not yet propagated for the FBE's ingress.
- A service failed to start silently (check pod logs in ArgoCD).

**What to do:** Check the **test results tab** in the Azure DevOps build. If the frontend is unreachable, check ArgoCD for the FBE namespace — look for pods in `CrashLoopBackOff` or `Error` state.

> 📎 **Slack thread:** [Dmytro — FBE green but frontend not accessible, Jan 19, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1768836671226129) (4 replies)

---

### All FBEs are in use — none available

**Symptoms:** You need an FBE for testing but all slots are occupied.

**What to do:** Ask in #myriad-platform if anyone has an FBE they're not actively using and can clean up. The pool is limited.

> 📎 **Slack thread:** [Hein — all FBEs in use, Jan 17, 2025](https://eneco-online.slack.com/archives/C063SNM8PK5/p1737117508050759) (8 replies)

---

### Kafka Application ID changed — FBE configuration is broken

**Symptoms:** After changing the Kafka Application ID for your service (e.g., from `com-eneco-eet-vpp-streamcopy-dev{N}` to `com-eneco-eet-vpp-assetplanning`), FBEs stop receiving Kafka messages.

**Root cause:** FBE infrastructure scripts configure Axual/Kafka with the old Application ID pattern. The new ID needs to be propagated into the FBE templates.

**What to do:** Work with the Platform team to update the FBE infrastructure scripts and Axual configuration.

> 📎 **Slack thread:** [Alexandre — Kafka App ID in FBE, Jan 19, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1768823818151139) (7 replies)

---

## Connectivity & Azure Portal

### Azure Portal returns 401 / network errors on App Configuration

**Symptoms:** When navigating to `vpp-applicationconfig-*` resources in the Azure Portal, you see a 401 Unauthorized or network connectivity error. This happens even from AVD.

**Root cause (verified):** A browser-specific issue. Edge has known problems rendering private endpoint resources in the Azure Portal.

**Fix:**
1. **Try Firefox** (or Chrome) instead of Edge. This resolves the issue in most cases.
2. Make sure you're on **AVD** — these resources are VNet-integrated with no public access.
3. If still failing, **restart AVD** (clear session state).

**What NOT to do:** Don't add entries to your hosts file as a first step — the access is usually already in place, it's the browser that's failing.

> 📎 **Slack thread:** [Jove — App Config 401, Jan 23, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769166220255159) (31 replies)
> Roel: *"Can you try another browser just to rule this out. It's happened before."*
> Jove: *"it works on FF even fleetoptimizer-p"*
> Roel: *"We've seen weird behavior with browsers lately. Especially things not working on Edge, but working on Chrome."*

---

### Cannot query ADX data on Production (works on ACC)

**Symptoms:** ADX queries work on Acceptance but fail on Production with an access error.

**Root cause:** Likely a permissions gap — your account may not be assigned the correct role on the Production ADX cluster.

**What to do:** Post in #myriad-platform with the ADX cluster name and the error message. The platform team will check and grant the necessary roles.

> 📎 **Slack thread:** [Artem — ADX prod query failure, Feb 3, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1770116955106169) (9 replies, resolved)

---

### VPN is not connecting from home

**Symptoms:** Cannot establish VPN connection. AVD unreachable.

**What to do:**
1. Check if colleagues are experiencing the same issue (post in the channel).
2. Restart the VPN client and your machine.
3. If widespread, it's likely a network-level issue requiring CMC / SRE.

> 📎 **Slack thread:** [Niels — VPN connectivity, Jan 2, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1767347684888539) (15 replies)

---

## Gurobi

### Solver returns "Connection aborted" / RemoteDisconnected

**Symptoms:** Optimization fails with: `('Connection aborted.', RemoteDisconnected('Remote end closed connection without response'))` in Application Insights.

**Triage steps:**
1. **Check the Gurobi Cluster Manager logs** — look for pod restarts, resource exhaustion, or error entries.
2. **Check Application Insights** for the solver pod in the relevant environment.
3. **Determine scope:** Is this isolated (single run) or recurring?

**If isolated:** Monitor and re-run. Transient network hiccups between the solver and Gurobi server do occur.

**If recurring:** Escalate. Past incidents required application-side reconfiguration (e.g., connection timeout settings, Gurobi license configuration). Gurobi support can be engaged for deep diagnostics.

**Important:** Verify which solver (STD vs FO) is affected — they're separate deployments and the investigation path differs.

> 📎 **Slack thread:** [Nykyta — Gurobi connection aborted, Jan 8, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1767886148269889) (19 replies)
> Roel: *"Did you guys also check the Gurobi logs in the cluster manager?"* and *"I think we've seen this once before. We had some calls with Gurobi about something similar and then we reconfigured some things on the application side."*
> Quinten: *"Let's monitor it. If it happens again I want a full research."*

---

## Terraform & Infrastructure

### Terraform plan shows "must be replaced" on a database or CosmosDB container

**Symptoms:** Running `terraform plan` after an infrastructure change shows a CosmosDB container or database marked as `must be replaced`. This means Terraform will **destroy and recreate** the resource — causing **data loss**.

**Root cause:** Common when moving resources between Terraform maps, changing `manage_indexes` levels, or renaming module keys. Terraform sees the key change as "delete old + create new" rather than "rename."

**Fix:** Use a `moved` block. See the [FAQ entry on Terraform moved blocks](./faq_draft.md#how-do-i-safely-renamemove-a-terraform-resource-without-destroying-it) for the full procedure and example.

**Critical:** Never apply a plan that shows `must be replaced` on a database resource without platform team review.

> 📎 **Slack threads:**
> [Hein — Terraform scary plan, Jan 22, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769073434784389) (14 replies, Fabrizio provided `moved` block solution)
> [Ihar — unexpected CosmosDB replace during release, Jan 29, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769687072104589) (9 replies: *"It wants to recreate the container which is a dataloss. We did not update any configuration for this container."*)

---

### TFLint failing on resources I didn't change

**Symptoms:** PR validation fails on TFLint for a resource you didn't modify (e.g., `cosmosdb_account` when you only changed AD groups).

**Root cause:** Pre-existing linting violations in the shared codebase. TFLint scans all files, not just your diff.

**What to do:** Note it in your PR description. The platform team is aware. They will review and approve if your changes are clean.

> 📎 **Slack thread:** [Andrew — TFLint cosmosdb_account, Feb 4, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1770193157871099) (8 replies: *"TFLint is complaining about something to do with cosmosdb_account which I don't think I have changed with my PR."*)

---

## OpenShift & Kubernetes

### Pods are restarting or stuck in ContainerCreating

**Symptoms:** Multiple pods in a namespace are restarting repeatedly or stuck in `ContainerCreating` status.

**First check:** Is there a **cluster upgrade or node maintenance** in progress? The Platform team announces these in #myriad-platform with `@here`. During OpenShift LCM (Lifecycle Management) upgrades, worker nodes are updated one by one, causing pods to be rescheduled — this is expected.

**If no maintenance is announced:**
- Check the OpenShift console / ArgoCD for the specific namespace.
- Look at pod events: `oc describe pod <pod-name> -n <namespace>`.
- `ContainerCreating` can indicate: image pull failures, storage mount issues, or node resource exhaustion.

**When to escalate:** If pods don't recover within 15 minutes after a known maintenance window, or if no maintenance is in progress.

> 📎 **Slack threads:**
> [Alexandre — Ishtar pods restarting, Feb 5, 2025](https://eneco-online.slack.com/archives/C063SNM8PK5/p1738748167604869) (7 replies)
> [Hein — containers stuck in ContainerCreating on FBE, Jan 10, 2025](https://eneco-online.slack.com/archives/C063SNM8PK5/p1736514434903019) (16 replies)

---

### ArgoCD is constantly syncing / Grafana dashboard keeps reloading

**Symptoms:** ArgoCD shows continuous sync operations on an application. Grafana dashboards reload every few seconds, making them unusable.

**Root cause:** ArgoCD detects configuration drift on every reconciliation cycle and attempts to correct it, creating a sync loop. This can cascade to Grafana if dashboard ConfigMaps are part of the sync.

**What to do:** Report the affected application name and environment in #myriad-platform. The platform team will investigate the sync loop source.

> 📎 **Slack thread:** [Wesley — Data Prep dashboard reloading in PROD, Jan 7, 2025](https://eneco-online.slack.com/archives/C063SNM8PK5/p1736247278593579) (17 replies): *"ArgoCD is constantly pushing updates. We use these dashboards pretty extensively to identify production issues."*

---

### ArgoCD application shows "unknown" status

**Symptoms:** All or many applications in ArgoCD show "Unknown" health status.

**Likely cause:** The Platform team is refreshing the ArgoCD repository connectivity secret. This is a brief operation (~30 seconds) with **no impact on running workloads**. The status will recover automatically.

> 📎 **Slack thread:** [Roel — refreshing ArgoCD secret in PROD, Jan 23, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1769175663465509): *"I'm refreshing the secret for repository connectivity in production argocd. If you see applications with 'unknown' status, that's me."*

---

### ArgoCD sync failing on a specific application after a release

**Symptoms:** After deploying a release, one application in ArgoCD shows sync failure on DEV-MC (or another environment). Other apps are fine.

**What to do:** Post the ArgoCD application link and the error in #myriad-platform. The platform team will check if it's a configuration issue or a transient sync failure.

> 📎 **Slack thread:** [Alexandre — dataprep failing sync on DEV-MC, Jan 7, 2026](https://eneco-online.slack.com/archives/C063SNM8PK5/p1767780456429379) (8 replies)

---

## Blob Storage & Data Connections

### "Name does not resolve" for blob storage on FBE

**Symptoms:** A service on an FBE fails with `Name does not resolve (mcvppstoraged.blob.core.windows.net:443)`.

**Root cause:** DNS resolution failure for the storage account's private endpoint from within the FBE namespace.

**What to do:** Post in #myriad-platform with the FBE name and storage account. The platform team will check DNS zone configuration for the FBE subscription.

> 📎 **Slack thread:** [Hein — blob name does not resolve, Jan 15, 2025](https://eneco-online.slack.com/archives/C063SNM8PK5/p1736946928386999) (46 replies)

---

## Still stuck?

If your issue isn't covered here, post in [#myriad-platform](https://eneco-online.slack.com/archives/C063SNM8PK5) with:

1. **What happened** — the error message, screenshot, or symptoms.
2. **What you've already tried** — retries, browser changes, etc.
3. **A link** — to the failing pipeline, PR, ArgoCD app, or Azure resource.
4. **The environment** — sandbox, dev-mc, acc, or prod.

The Platform team aims to respond promptly during CET business hours.

---

*Every resolution in this guide is derived from verified Slack thread content from #myriad-platform, January 2025–March 2026.*
