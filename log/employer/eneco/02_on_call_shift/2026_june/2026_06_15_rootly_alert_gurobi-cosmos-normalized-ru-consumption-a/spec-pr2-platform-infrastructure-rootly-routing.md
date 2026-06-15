---
title: "PR Spec 2 — platform-infrastructure: Rootly routing / escalation verification for the Sev3 demotion"
description: "Self-contained, agent-implementable spec ensuring the gurobi-cosmos NormalizedRU Sev3 demotion is actually non-paging. The severity->urgency translation already exists; the work is verifying (and deciding) the low-urgency escalation behaviour."
timestamp: 2026-06-15T19:15:00Z
status: complete
category: pr-spec
authors: ["Alex Torres Ruiz (with Claude Code)"]
task_id: 2026-06-15-001
agent: coordinator
summary: >-
  Self-contained companion to PR Spec 1. The Azure-severity -> Rootly-urgency mapping ALREADY exists in
  platform-infrastructure (Sev2->medium, Sev3->low), verified at modules/rootly-alert-routing/main.tf,
  so Spec 1's Sev2->Sev3 demotion auto-translates with NO Terraform change. The genuine work is to
  VERIFY the team's non-production escalation policy treats "low" urgency as non-paging and "medium"+
  as paging; if not, that is a team-wide decision (the policy is shared and is consumed as a read-only
  rootly_escalation_policy data source — Rootly-UI-managed). Provider pinned rootlyhq/rootly 5.8.0.
  Honest gap: the Terraform MCP could not resolve this provider, so the optional "bring the policy into
  IaC" path must be confirmed against the 5.8.0 provider docs before attempting.
---

# PR Spec 2 — `platform-infrastructure`: Rootly routing / escalation verification

> **Target repo:** Azure DevOps `enecomanagedcloud / Myriad - VPP / platform-infrastructure`. **Base branch:** `main`. Relevant tree: `terraform/infrastructure/` (this is a multi-worktree checkout; use the `main` worktree). Providers pinned in `terraform/infrastructure/providers.tf`: **`rootlyhq/rootly` 5.8.0**, `hashicorp/azurerm` 4.41.0.
> **Companion:** PR Spec 1 (`gurobi-infrastructure`) makes the alert-definition change. This spec exists **only because** of PR Spec 1's `Sev2→Sev3` demotion; read it standalone otherwise.
> **Honesty note:** the substantive change here is mostly **verification**, not new Terraform. Do not add a redundant severity→urgency mapping — it already exists (proven below). I deliberately do not invent a Terraform change the evidence does not justify.

---

## 1. Why this change is needed (complete rationale)

PR Spec 1 changes the Gurobi Cosmos utilization-gauge alert (`gurobi-cosmos-normalized-ru-consumption`) from **severity 2 to severity 3**, so it becomes a non-paging warning instead of paging on-call for tolerated micro-bursts. (The full reasoning: on 2026-06-15 that alert paged Sev2 even though real client impact was only 2.82% HTTP-429 — inside Microsoft's "healthy" band — because it watches a *utilization gauge*, not actual client impact. PR Spec 1 adds a real client-impact page and demotes the gauge.)

For that demotion to actually change behaviour, **two things must hold in the alerting pipeline**, which runs: *Azure Monitor alert → the team's Azure action group → a webhook into Rootly → Rootly's Azure alert source assigns an "urgency" → Rootly's escalation policy decides whether that urgency pages a human.*

1. **Azure severity must translate to a Rootly urgency.** This is **already implemented** in this repo and needs no change (proven in §2): the Rootly Azure alert source maps `Sev2 → "medium"` and `Sev3 → "low"`. So Spec 1's demotion automatically moves this alert from `medium` urgency to `low` urgency.

2. **The escalation policy must treat the resulting urgency as non-paging.** Whether **`low` urgency actually pages** is decided **inside the Rootly escalation policy**, which this repo *reads* (a `data "rootly_escalation_policy"` source) but does **not** create — it is managed in the Rootly UI. **If `low` urgency still pages the on-call rotation, then Spec 1's Sev3 demotion is cosmetic and on-call keeps getting paged on healthy-band bursts.**

So the genuine, necessary work of this PR is: **verify that `low` urgency is non-paging (and `medium`+ pages) in the team's escalation policy**, and only if it is not, make a deliberate, team-approved change. This is small, but it is the difference between Spec 1 *working* and Spec 1 *looking like it works*.

---

## 2. What is already true (verified in the repo — do NOT recreate)

These are facts read directly from `platform-infrastructure/main/terraform/infrastructure/`:

**(a) Severity → urgency mapping already exists and is complete.** In `modules/rootly-alert-routing/main.tf`, the Rootly **Azure** alert source (`resource "rootly_alerts_source" "azure"`) contains urgency rules keyed on the alert payload field `$.data.essentials.severity`:

| Azure severity | Rootly urgency assigned |
|---|---|
| `Sev0` | `critical` |
| `Sev1` | `high` |
| `Sev2` | `medium` |
| `Sev3` | `low` |

(Urgency names/IDs are defined in `terraform/infrastructure/locals.tf` as `critical/high/medium/low`.) **Consequence:** Spec 1's change of the Cosmos alert from `severity = 2` to `severity = 3` automatically routes it from `medium` to `low` urgency — **no edit to this mapping is needed or wanted.**

**(b) The escalation policy is environment-based and read-only (UI-managed).** In `modules/rootly-alert-routing/locals.tf`, the policy is selected by environment:

```hcl
escalation_policy_name = var.environment_suffix == "p" ? "${var.team_name}-production" : "${var.team_name}-non-production"
```

and it is consumed as a **data source** — `data "rootly_escalation_policy" "this" { name = local.escalation_policy_name }` — in all three routing modules (`rootly-alert-routing`, `rootly-heartbeat`, `rootly-live-call-routing`). The acceptance environment (`environment_suffix = "a"`) therefore routes to **`trade-platform-non-production`**. Because it is a *data* source, **what each urgency does (page vs notify-only) is defined in the Rootly UI, not in this repository.**

---

## 3. What to do (verify → decide → act)

### Step 1 — VERIFY (read-only; this is the load-bearing check)

In the Rootly UI, open the escalation policy **`trade-platform-non-production`** (and **`trade-platform-production`** for the prod sibling) and read its per-urgency notification rules. Answer two questions and record them:

- Does **`low`** urgency notify the on-call rotation through a **paging** channel (phone call / push / SMS), or a **non-paging** channel (email / Slack digest), or not at all?
- Does **`medium`** urgency (where Spec 1's new Sev2 HTTP-429 page lands) **page**?

### Step 2 — DECIDE (branch on what Step 1 found)

- **If `low` is already non-paging and `medium` pages →** Spec 1's demotion works as intended with no change here. This PR becomes a **verification record**: document the confirmed behaviour (in the PR description and/or a short note in this repo) and close it. (Optionally proceed to Step 4.)
- **If `low` currently PAGES →** Spec 1's demotion would be cosmetic. **Do not unilaterally flip it.** Because the escalation policy is **shared by the whole team** (see §4), changing what `low` does affects every team alert that resolves to `low` urgency. Raise it with the team (owner **Nuno**, fallback **#team-platform**); if the team agrees that `low` should be non-paging, apply Step 3.

### Step 3 — ACT (only if Step 2 concludes `low` must become non-paging, with team sign-off)

Two implementation paths; pick with the team:

- **(3a) Rootly UI change (smallest, matches current ownership).** Edit `trade-platform-non-production` so `low`-urgency notifications are non-paging (email/Slack digest), leaving `medium`+ paging. No change to this repository. Document the change in the PR description and the repo runbook.
- **(3b) Bring the escalation policy into Terraform (optional governance upgrade).** Replace the read-only `data "rootly_escalation_policy" "this"` with a **managed** `resource "rootly_escalation_policy"` defining explicit per-urgency notification levels, so paging behaviour is reviewable in code. **Two cautions, both mandatory:** (i) this is a **team-wide, shared** object — converting it to a managed resource changes ownership of escalation for the whole team and must be a team decision, not a side effect of this PR; (ii) **I could not confirm via the Terraform MCP that the `rootlyhq/rootly` 5.8.0 provider exposes a `rootly_escalation_policy` *resource* (as opposed to only the *data* source this repo uses)** — the MCP did not resolve this provider. **Before attempting 3b, verify in the rootlyhq/rootly 5.8.0 provider documentation that a manageable `rootly_escalation_policy` resource exists and supports per-urgency notification configuration.** If it does not, 3a (UI) is the only path.

### Step 4 — (optional) carry the runbook link into Rootly

The Azure alert source maps `title/description/source_link/environment` but **not** a `runbook` field (the *alertmanager* source in the same module does map one). Optionally add a `runbook` field mapping to the Azure source so the Gurobi alerts surface the RCA/runbook link directly in Rootly. Nice-to-have; not required for the demotion.

---

## 4. Blast radius (read before any change)

- The escalation policy `trade-platform-non-production` is **shared across the whole team and all its products**, and the severity→urgency mapping is **global to the Azure alert source** (it is not per-alert-rule). Therefore **you cannot make only the Gurobi RU alert non-paging from this repository** — any change to what `low` urgency does affects **every** Sev3/`low` alert for trade-platform non-production. That is exactly why a "`low` pages today" situation is escalated to a team decision in Step 2 rather than flipped unilaterally; silencing `low` could suppress another team member's legitimate low-urgency notification.
- The production policy (`trade-platform-production`) is a **separate** object — verify it independently and never assume prod and non-prod behave the same.

---

## 5. Acceptance criteria

1. **Verification recorded:** a written answer to "does `low` page / does `medium` page?" for both `trade-platform-non-production` and `trade-platform-production`.
2. **If no change is needed:** a note (PR description or repo runbook) capturing the confirmed `Sev3 → low → non-paging` behaviour, so the next engineer knows the demotion is effective. PR closes as verification.
3. **If a change was made (3a or 3b, team-approved):** a **test alert at Sev3** (`low`) does **not** notify the on-call rotation via a paging channel, and a **test alert at Sev2** (`medium`) **does** (use a synthetic Azure alert or Rootly's test-alert feature). For 3b, `terraform validate` + `terraform plan` are clean against the pinned `rootlyhq/rootly` 5.8.0.
4. **No regression** to other teams' / other products' `low`-urgency routing (explicitly confirmed, given §4).

## 6. Rollback

- **3a (UI):** revert the `low`-urgency notification level in the Rootly escalation policy.
- **3b (IaC):** `git revert` and re-introduce the `data` source. Note that converting a `data` source to a managed `resource` (and back) is state-sensitive for a *shared* object — plan carefully and coordinate with the team.
- **Verification-only outcome:** nothing to roll back.

## 7. Sequencing with PR Spec 1

PR Spec 1 is independently shippable. Recommended order: **(1)** ship Spec 1's new Sev2 HTTP-429 page and confirm it works; **(2)** run this spec's Step 1 verification; **(3)** demote the RU gauge to Sev3 (the last change in Spec 1) only once Step 1 confirms `low` is non-paging — so on-call is never left without a page in the gap.

## 8. Existing repo facts this spec relies on (verified in `platform-infrastructure/main`)

- Provider pins (`terraform/infrastructure/providers.tf`): `rootlyhq/rootly` **5.8.0**, `hashicorp/azurerm` **4.41.0**.
- Severity→urgency rules on `$.data.essentials.severity` (Sev0→critical, Sev1→high, Sev2→medium, Sev3→low): `modules/rootly-alert-routing/main.tf` (the `rootly_alerts_source.azure` resource's `alert_source_urgency_rules_attributes` blocks).
- Urgency names/IDs (`critical/high/medium/low`): `terraform/infrastructure/locals.tf`.
- Environment-based escalation policy name + read-only data source: `modules/rootly-alert-routing/locals.tf` and `modules/rootly-alert-routing/data.tf` (`data "rootly_escalation_policy" "this"`), mirrored in the `rootly-heartbeat` and `rootly-live-call-routing` modules.

## 9. Validation provenance

- **Repo facts** (severity→urgency mapping, data-source escalation policy, provider pins) were read directly from `platform-infrastructure/main/terraform/infrastructure/` at the file:line locations named in §2 and §8.
- **Provider** `rootlyhq/rootly` `5.8.0` is the version pinned in the repo's `providers.tf`. **Limitation, stated plainly:** the Terraform MCP server could not resolve this provider (it returned 404 for `rootlyhq/rootly`), so the existence/schema of a manageable `rootly_escalation_policy` **resource** (needed only for the optional path 3b) is **not confirmed in this spec** and must be verified against the 5.8.0 provider documentation before 3b is attempted. The **core** of this spec (Steps 1–2 and path 3a) does not depend on any unverified Terraform.
