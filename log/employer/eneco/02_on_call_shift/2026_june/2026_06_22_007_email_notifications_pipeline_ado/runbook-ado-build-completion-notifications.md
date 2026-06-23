---
title: "Runbook — Enable email notifications on an Azure DevOps pipeline (build completes)"
description: Platform-team runbook for the recurring request "grant me rights to set up build-completion email notifications". Triage personal-vs-shared, apply the least-privilege resolution, verify by the received email.
type: runbook
domain: work
status: review
source: agent
created: 2026-06-22
tags: [eneco, how-to, azure-devops, notifications, access-management, least-privilege]
aliases: [ado-build-email-notifications, enable-build-notifications]
related: [eneco-howto-add-user-ado-entitlement, eneco-howto-rbac-slack-workflow-aad-request]
---

# Runbook — Enable email notifications on an Azure DevOps pipeline

**When this fires:** a developer files a request like *"I want email notifications when pipeline X completes; I tried Project Settings → Notifications but I lack edit rights — please grant me."*

**The trap to avoid:** the request *names* a project-admin grant, but the underlying need is usually self-serve. Granting Project Administrators to deliver a personal email is over-privilege. **Decide the audience first; the grant is a consequence.**

Companion teaching doc (full mechanism + commands): `how-to-enable-ado-build-email-notifications.md`.

## 60-second triage (one question that routes everything)

> **Ask the filer: "Who needs to receive the email — just you, or a whole team/shared list?"**

| Answer | Resolution | Permission to grant | Who acts |
|---|---|---|---|
| **Just me** | Personal subscription | **None** | The **filer**, self-serve |
| **My team** (shared inbox/DL) | Team subscription | **Team Administrator** of their team | Admin grants role → filer or admin creates sub |
| **Project-wide** (everyone) | Project subscription | **Project Administrators** (last resort) | Project admin creates the sub |

If the answer is "just me" — which is the common case — there is **nothing to grant**. Reply with the self-serve steps and close.

## Decision tree

```text
Request: "enable build-completion emails for pipeline X"
        │
        ▼
Q: Who receives it?
        ├── just me ─────────────► PERSONAL  → no grant; filer self-serves (Path A)        ► CLOSE
        ├── a team / shared DL ──► TEAM      → grant Team Administrator (least privilege)   ► then Path B
        └── whole project ───────► PROJECT   → Project Administrators (justify; last resort) ► then Path B
```

## Resolution A — Personal (no grant; reply-and-close)

Tell the filer (or do it with them):

1. **User settings (gear, top-right) → Notifications → New subscription.**
2. **Build → "A build completes."**
3. Scope to the **project**; filter **Build pipeline = <their pipeline>** (optionally only *failed*).
4. Save. Emails arrive in their inbox; **no admin action required.**

This resolves ~most of these tickets with zero permission change.

## Resolution B — Team (least-privilege grant)

Only when a *shared address* needs it.

1. Confirm the filer's team. Grant them **Team Administrator** of that team (Project Settings → Teams → <team> → add administrator) — **not** Project Administrators.
   - Cross-ref: `eneco-howto-add-user-ado-entitlement` for the ADO access-management pattern.
2. Filer (now Team Admin) or you: **Project Settings → Notifications → New subscription → Build → "A build completes."**
3. Scope project; filter the pipeline; **Deliver to = the team distribution list address** (set custom address).
4. Save.

## Resolution C — Project-wide (last resort, justify)

Only if delivery must reach people who can't self-serve and there's no team boundary. Requires **Project Administrators** membership. Prefer C only after rejecting A and B; record why in the ticket.

## CLI / REST equivalent (repeatable / scripted)

No native `az devops notification` command exists — use `az rest` against the Notifications API. Full commands + the verified event id and audience GUID are in the companion how-to (Path C). One-line shape:

```bash
az rest --method post \
  --uri "https://dev.azure.com/enecomanagedcloud/_apis/notification/subscriptions?api-version=7.1" \
  --resource 499b84ac-1321-427f-aa17-267ca6975798 \
  --headers "Content-Type=application/json" --body @body.json
```

Event type: `ms.vss-build.build-completed-event` (avoid the `…-legacy-event` variants — they reject custom subs). Resolve `scope.id` with `az rest --method get --uri "$ORG/_apis/projects/Myriad%20-%20VPP?api-version=7.1" --resource 499b84ac-… --query id -o tsv` (uses the `az login` token — no azure-devops extension/PAT). If any call returns a version error, append `-preview.1`. To filter by a single pipeline in code, create it once in the portal and `GET` the subscription back to copy the exact `criteria.clauses` (the clause shape is undocumented — never guess it).

## Verify — close on the EFFECT, not the save

A green portal save / HTTP `201` proves the **rule exists**, not that **email is delivered**.

```text
sub created ─► trigger/await a completion of pipeline X ─► email lands in target inbox?
                                                              ├─ yes ─► DONE (close on the email)
                                                              └─ no  ─► scope wrong? filter too narrow?
                                                                        custom address unset? junk-filtered?
```

## Escalate / out of scope

- Filer needs a permission you can't grant → route via the AAD/ADO access workflow (`eneco-howto-rbac-slack-workflow-aad-request`).
- Non-email channels (Teams/Slack webhooks, service hooks) → different mechanism, not this runbook.
- Org-wide default notification changes → Project Collection Administrators only.

## Reply template (paste into the Slack filing)

> Good news — for emails **just to you**, you don't need any extra rights. Go to **User settings (gear, top-right) → Notifications → New subscription → Build → "A build completes"**, scope it to **Myriad - VPP**, and filter on your pipeline. That delivers to your inbox with no grant needed.
> If instead you want it sent to a **whole team / shared list**, tell me the team + address and we'll set up a shared subscription (we'd add you as *Team Administrator*, which is the minimal right for that — not full project admin). Full steps + CLI: `how-to-enable-ado-build-email-notifications`.

## Durable principles

1. **Audience decides the grant** — personal = none, team = Team Admin, project = Project Admin.
2. **Least privilege**: never grant Project Administrators to deliver a personal email.
3. **Close on the received email**, never the save/`201`.
4. **Never guess the undocumented pipeline-filter clause** — capture it from a portal-created subscription.
