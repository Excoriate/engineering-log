---
title: "Spec — project notification subscription (Anastasia / gp_teamAgg)"
description: Verified spec for project-level ADO build-completion email to gp_teamAgg@eneco.com on pipeline 8951 — portal + REST validated 2026-06-24.
type: spec
domain: work
status: implemented-dl-unverified
source: agent
created: 2026-06-23
updated: 2026-06-24
tags: [eneco, azure-devops, notifications, myriad-vpp, gp-teamagg]
related:
  - how-to-enable-ado-build-email-notifications.md
  - runbook-ado-build-completion-notifications.md
  - spec-project-subscription-gp-teamagg-socrates.md
  - diagnosis-personal-vs-dl-email.md
---

# Spec — project-level build notification (gp_teamAgg)

## Confirmed requirements

| Field | Value |
|---|---|
| Filer | Anastasia Zenchik (team DL, not personal) |
| Org | `enecomanagedcloud` |
| Project | `Myriad - VPP` (`a7ef9a24-213c-4c4c-85f4-c20a7db60c43`) |
| Pipeline | `definitionId=8951` → **`B2B Behind The Meter - E2E tests`** |
| Event | `ms.vss-build.build-completed-event` |
| Deliver to | **`gp_teamAgg@eneco.com`** ✅ |
| Grant to filer | **None** |

## Verdict — doable (portal + API)

| Path | Status | Evidence (2026-06-24) |
|---|---|---|
| **Portal** | ✅ Supported | MS Learn: Definition name filter at project scope; Filter criteria + Custom email address |
| **REST** | ✅ **Created & verified** | `POST …/subscriptions` → **200**; `GET …/subscriptions/842522` → `enabled` + clause + DL channel |
| **Filter by definitionId 8951** | ❌ Not supported | Event metadata has **Definition name** only (`tb1:Definition/@FullPath`) |
| **Filter by pipeline name only** | ⚠️ Use dropdown / full path | API stores **full path** value (see below) |

**Socrates review:** [spec-project-subscription-gp-teamagg-socrates.md](./spec-project-subscription-gp-teamagg-socrates.md) — ACCEPTABLE; close on received email, not HTTP 200.

**Docs research:** `.ai/unspecified/librarian/01-ado-notification-subscriptions-ms-docs.md`

---

## Why the UI felt broken

Pipeline filter **is supported**, but not by numeric id.

1. Field is **Definition name** — add via **Filter criteria → + Add new clause**.
2. Pick pipeline from the **dropdown** (sets `@FullPath`); do not type `8951`.
3. Stored filter value (live GET):

   `\Myriad - VPP\B2B Behind The Meter - E2E tests`

4. Short name alone may not match; **Contains** `Behind The Meter - E2E` works if dropdown fails (verify no other pipelines match).

---

## Execute (portal)

1. [Project Settings → Notifications](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_settings/notifications) (Project Administrator).
2. **New subscription** → **Build** → **A build completes**.
3. **Description:** `Build completes — B2B BTM E2E (8951) → gp_teamAgg`.
4. **Deliver to:** **Custom email address** → `gp_teamAgg@eneco.com`.
5. **Filter criteria → + Add new clause:**
   - **Definition name** **=** select **`B2B Behind The Meter - E2E tests`** from dropdown.
6. **Finish**.

---

## Execute (REST — verified body)

**Prerequisites**

```bash
az login --tenant eca36054-49a9-4731-a42f-8400670fc022 \
  --scope "499b84ac-1321-427f-aa17-267ca6975798/.default"

ORG="https://dev.azure.com/enecomanagedcloud"
RESOURCE="499b84ac-1321-427f-aa17-267ca6975798"
PROJECT_ID="a7ef9a24-213c-4c4c-85f4-c20a7db60c43"
```

**Create** (clause value = verified full path from GET read-back):

```bash
cat > body.json <<'JSON'
{
  "description": "Build completes — B2B BTM E2E (8951) → gp_teamAgg",
  "filter": {
    "eventType": "ms.vss-build.build-completed-event",
    "type": "Expression",
    "criteria": {
      "clauses": [{
        "logicalOperator": "",
        "fieldName": "Definition name",
        "operator": "=",
        "value": "\\Myriad - VPP\\B2B Behind The Meter - E2E tests",
        "index": 1
      }],
      "groups": [],
      "maxGroupLevel": 0
    }
  },
  "channel": {
    "type": "EmailHtml",
    "address": "gp_teamAgg@eneco.com",
    "useCustomAddress": true
  },
  "scope": {
    "id": "a7ef9a24-213c-4c4c-85f4-c20a7db60c43",
    "type": "project"
  }
}
JSON

az rest --method post \
  --uri "${ORG}/_apis/notification/subscriptions?api-version=7.1" \
  --resource "$RESOURCE" \
  --headers "Content-Type=application/json" \
  --body @body.json
```

**Read-back** (always verify clauses — list endpoint may omit them):

```bash
SUB_ID=842522   # live subscription created 2026-06-24
az rest --method get \
  --uri "${ORG}/_apis/notification/subscriptions/${SUB_ID}?api-version=7.1" \
  --resource "$RESOURCE"
```

**Query project subscriptions** (correct endpoint — singular `subscriptionquery`):

```bash
az rest --method post \
  --uri "${ORG}/_apis/notification/subscriptionquery?api-version=7.1" \
  --resource "$RESOURCE" \
  --headers "Content-Type=application/json" \
  --body '{"conditions":[{"scope":"a7ef9a24-213c-4c4c-85f4-c20a7db60c43"}],"queryFlags":"includeFilterDetails"}'
```

**Event filter metadata:**

```bash
az rest --method get \
  --uri "${ORG}/_apis/notification/eventtypes/ms.vss-build.build-completed-event?api-version=7.1" \
  --resource "$RESOURCE"
```

---

## Live implementation record

| Item | Value |
|---|---|
| Subscription ID | **842522** |
| Status | `enabled` |
| Channel | `EmailHtml` → `gp_teamAgg@eneco.com`, `useCustomAddress: true` |
| Filter clause | `Definition name` `=` `\Myriad - VPP\B2B Behind The Meter - E2E tests` |
| Created by | Alex.Torres@eneco.com (REST POST 2026-06-24) |
| Edit URL | [Notifications admin](https://dev.azure.com/enecomanagedcloud/_notifications?subscriptionId=842522&publisherId=ms.vss-build.build-event-publisher&action=view) |

**Note:** `subscriber` defaults to creator; delivery goes to DL because `useCustomAddress: true`.

---

## Diagnosis — "only works for Anastasia" (2026-06-24)

**Not our subscription failing — wrong email cited as proof.**

| Evidence | Implication |
|---|---|
| Screenshot email **To:** `Zenchik, A (Anastasia)` | Delivered to **personal inbox**, not `gp_teamAgg@eneco.com` |
| Body **Requested for: Zenchik** | Matches default OOB **Build completed** (role: Requested for) |
| Sub **842522** edit UI: Deliver to **Other email** → `gp_teamAgg@eneco.com` | Team sub is separate path; config looks correct |
| Colleagues did not receive | **Expected** for OOB personal rule — they were not Requested for |

Two paths fire on the same build; Anastasia proved **path A only**:

```text
Build 8951 completes
  ├─ A) Default OOB "Build completed" → Requested for inbox  ← Anastasia's email (To: her)
  └─ B) Sub 842522 → gp_teamAgg@eneco.com                    ← still unverified
```

Full dossier: [diagnosis-personal-vs-dl-email.md](./diagnosis-personal-vs-dl-email.md)

**Answer her:** Yes — "build completes" fires on **succeeded and failed** (unless you add a Status filter). Her mail is the **personal** default, not the team DL.

**Discriminate DL path:** search `gp_teamAgg@eneco.com` for build #20260624.1; or re-run pipeline 8951 and confirm mail lands in DL (To: gp_teamAgg), not personal inboxes.

---

## Verify (remaining gate)

1. ✅ Subscription exists with pipeline clause (GET 842522).
2. ⏳ Pipeline **8951** completes → email at **`gp_teamAgg@eneco.com`** (check DL mailbox, not Anastasia To:).
3. ⏳ Another pipeline completes → **no** email to DL (negative test).

Close ticket only on step 2 (and ideally 3).

---

## Slack close (after email verify)

> Build-completion notification for **B2B Behind The Meter - E2E tests** (8951) is live — emails go to **gp_teamAgg@eneco.com**. Filter uses **Definition name** (full pipeline path), not definition id.
