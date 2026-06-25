---
task_id: adversarial-review
agent: socrates-contrarian
timestamp: 2026-06-24T00:00:00Z
status: complete

summary: |
  Adversarial review of the gp_teamAgg project-level ADO build notification spec.
  Portal path for Definition-name filtering and custom email is doc-supported and likely viable.
  REST path is directionally correct but the sketch has a clauses schema error and omits subscriber semantics.
  Empty-clauses anti-pattern and no-definitionId filter claims survive scrutiny. Live org probe still blocked.
---

# Contrarian report — spec-project-subscription-gp-teamagg

## Steelman

The spec solves a real intake mismatch: filer linked `definitionId=8951` but ADO notification filters expose **Definition name** (string), not numeric id. Project-level scope with **Custom email address** is the correct container when delivery must go to a shared DL without granting Anastasia project admin. The portal-first + GET-read-back REST workflow avoids guessing undocumented `criteria.clauses` — consistent with the companion how-to. Closing on received email (not HTTP 201) is the right verification bar.

## Verdict

| Grade | **ACCEPTABLE — revise before REST-only execution** |
| --- | --- |
| Evidence basis | SOURCE-TRACED (Microsoft Learn, MSFT Stack Overflow); live org probe UNVERIFIED (MFA blocked per spec) |
| Recommendation | **Approve portal execute path.** Fix REST sketch; do not treat REST body as copy-paste-ready until GET read-back from portal-created sub. |

---

## Claim-by-claim attack matrix

### Claim 1 — Project Settings can filter pipeline 8951 via Definition name = `B2B Behind The Meter - E2E tests`

| Field | Value |
| --- | --- |
| **Attack** | Filter is **name-bound**, not id-bound. Rename, trailing space, or duplicate substring match breaks or widens delivery silently. Dropdown UX may fail on long names even when field exists. |
| **Mechanism** | Event matcher compares `criteria.clauses` against build-completed payload **definition.name** (string). If clause value ≠ runtime name → zero matches → subscription enabled but no emails. If `contains Behind The Meter - E2E` matches >1 definition → noise to DL. |
| **Evidence** | [oob-supported-event-types — Build Completed fields include Definition name, not id](https://learn.microsoft.com/en-us/azure/devops/organizations/notifications/oob-supported-event-types#build-events); [MSFT SO #78552202 — Definition name dropdown at project subscription](https://stackoverflow.com/questions/78552202); event type `ms.vss-build.build-completed-event` lists `supportedScopes: ["project","collection"]` (REST event-types list). |
| **Falsifier** | After portal create: `GET …/_apis/notification/subscriptions/{id}?api-version=7.1` → clause `fieldName` + `value` equals exact live name; trigger build 8951 → email at gp_teamAgg; trigger different pipeline → **no** email. |
| **Route flip if fails** | Portal cannot add clause → **Service hook** `build.complete` with `publisherInputs.definitionName` + webhook/email bridge; or **personal subs** for each recipient (cheaper than broken project sub). Do **not** ship empty-clause project sub. |
| **Severity** | IMPORTANT (portal likely works; operational fragility on rename) |

---

### Claim 2 — Deliver to `gp_teamAgg@eneco.com` with `useCustomAddress` at project scope

| Field | Value |
| --- | --- |
| **Attack (portal)** | Low — MS docs describe **Custom email address** on Project Settings → Notifications. |
| **Attack (REST sketch)** | **Spec omits `subscriber`.** MS Create API: subscriber defaults to **calling user**. `useCustomAddress` + `address` is documented for **team** subscriptions with explicit `subscriber.id`; project-portal semantics ≠ guaranteed REST equivalence without read-back. |
| **Mechanism (delivery failure)** | `useCustomAddress: false` (default) → mail goes to caller preferred address, not DL. External DL may reject/filter ADO sender. Subscription stores successfully (`200/201`) while DL never receives. |
| **Evidence** | [Manage team/project notifications — Custom email address delivery option](https://learn.microsoft.com/en-us/azure/devops/organizations/notifications/manage-team-group-global-organization-notifications); [Subscriptions Create — team example with useCustomAddress](https://learn.microsoft.com/en-us/rest/api/azure/devops/notification/subscriptions/create); [Email recipients concepts — Custom email address](https://learn.microsoft.com/en-us/azure/devops/organizations/notifications/concepts-email-recipients). |
| **Falsifier** | Portal: subscription shows Deliver to = custom address `gp_teamAgg@eneco.com`. After build 8951 completes, message arrives in DL inbox (not creator's preferred address). REST: GET read-back shows `"useCustomAddress": true` and `"address": "gp_teamAgg@eneco.com"`. |
| **Route flip if fails** | If REST delivers to creator only → add portal create or set `subscriber` to mail-enabled AAD group backing the DL (if one exists). If DL never receives → mail-flow allowlist for ADO notification sender; verify DL accepts external senders. |
| **Severity** | IMPORTANT for REST path; portal path ACCEPTABLE |

---

### Claim 3 — REST POST `/_apis/notification/subscriptions` viable once clauses captured from portal

| Field | Value |
| --- | --- |
| **Attack** | Workflow (portal → GET → copy clauses) is sound; **sketch body is not.** |
| **Defects in spec JSON** | (a) `"clauses": ["<COPY…>"]` — **wrong type**; must be array of **objects** `{ fieldName, operator, value, index, logicalOperator }`. (b) No `subscriber` — ownership/delivery ambiguity. (c) `scope.type: "project"` — API responses often return `scope.type: "none"` with project uuid; unverified this POST shape alone marks it project-managed. |
| **Mechanism (silent failure)** | Wrong clause → subscription status `disabledInvalidPathClause` (documented enum) or enabled but never matches — still returns success on create. |
| **Evidence** | [Subscriptions Create REST](https://learn.microsoft.com/en-us/rest/api/azure/devops/notification/subscriptions/create); `SubscriptionStatus.disabledInvalidPathClause`; companion how-to claim #9 UNVERIFIED clause shape. |
| **Falsifier** | `az rest POST` with body from GET read-back → `200/201` + GET shows `status: "enabled"` + non-empty clauses + build 8951 triggers DL email. Negative: deliberately wrong `fieldName` → status `disabledInvalidPathClause` or no email on 8951. |
| **Route flip if fails** | Treat portal as source of truth; abandon scripted POST until read-back validated. Required scope: `vso.notification_write`. |
| **Severity** | CRITICAL for copy-paste REST; workflow itself ACCEPTABLE |

---

### Claim 4 — Empty `criteria.clauses` = all builds (anti-pattern)

| Field | Value |
| --- | --- |
| **Attack** | None material — claim is **correct**. |
| **Mechanism** | Empty expression criteria match all events of `eventType` within `scope` (project uuid). Every build completion in Myriad-VPP notifies DL. |
| **Evidence** | MS Create example personal subscription uses `"clauses": []` for all work items in project; spec §What is not acceptable aligns. |
| **Falsifier** | Create sub with empty clauses → any non-8951 build completion also sends email to DL. |
| **Route flip if fails** | N/A — if this falsifier fails, ADO semantics changed; escalate to MS docs drift. |
| **Severity** | ROBUST |

---

### Claim 5 — `definitionId` 8951 cannot be used as filter field

| Field | Value |
| --- | --- |
| **Attack** | Claim holds for **UI and documented notification filters**. Service hooks filter by `definitionName`, not numeric id. No "Definition id" in Build Completed filter field table. |
| **Counter-hypothesis** | Internal REST `fieldName` might differ from UI label (e.g. canonical token) — still almost certainly **name/value**, not `8951`. Guessing `8951` as value under a wrong field → invalid clause or zero matches. |
| **Evidence** | [oob-supported-event-types — Definition name only](https://learn.microsoft.com/en-us/azure/devops/organizations/notifications/oob-supported-event-types#build-events); [Service hook build.complete — definitionName filter](https://learn.microsoft.com/en-us/azure/devops/service-hooks/events#build.complete). |
| **Falsifier** | `GET …/notification/eventtypes?publisherId=ms.vss-build.build-event-publisher` + inputfilters for build-completed → no filterable field accepting numeric definition id; OR portal Filter criteria dropdown has no Definition id. |
| **Route flip if fails** | If inputfilters exposes id field (unlikely) → update spec to use copied clause from GET; still use 8951 only if API confirms. |
| **Severity** | ROBUST |

---

## Superweapon deployment

| SW | Finding |
| --- | --- |
| **Temporal decay** | Pipeline rename decouples filter from id 8951 without warning. Re-verify name via `GET …/build/definitions/8951` before each scripted recreate. |
| **Boundary failure** | ADO → Exchange DL boundary: external sender, spam, group receive restrictions. 201 from ADO ≠ accepted by mail system. |
| **Compound fragility** | Project scope + empty/missing clause + default user OOB "Build completes" = DL noise from all pipelines **plus** personal noise (SO #78552202 warns). |
| **Silence audit** | Spec lacks: failed-only filter option, DL mail-flow verification, duplicate-pipeline check for `contains` fallback, subscriber identity for REST. |
| **Uncomfortable truth** | Intake asked for project admin grant; spec correctly chose project sub for team DL — but **companion how-to already says personal sub is zero-cost for "just me."** Confirm gp_teamAgg is truly shared requirement, not over-scoped project admin path. |

---

## Dot-connection — emergent risks

1. **Spec REST sketch + how-to Path C** both show empty clauses in examples — easy to copy wrong example and ship all-builds sub despite warnings.
2. **Live probe blocked** (spec line 139) — all clause-shape and DL-delivery claims remain **UNVERIFIED** in `enecomanagedcloud`.
3. **Intake symptom "can't filter pipeline"** may be **missing + Add clause** UX, not missing capability — but only portal attempt falsifies.

---

## Residual risks (post-fix)

| Risk | Mitigation |
| --- | --- |
| Pipeline renamed | Periodic `GET definitions/8951`; alert on name drift vs clause value |
| `contains` over-match | Prefer `=`; audit project definitions for substring collision |
| REST body schema error | Fix sketch; never POST until GET read-back from portal sub |
| DL mail rejection | Verify received email; check Exchange/allowlist |
| OOB personal build noise | Document for filer; unrelated to project sub but affects satisfaction |
| MFA/auth drift | `az login --scope 499b84ac-1321-427f-aa17-267ca6975798/.default` before probe |

---

## Meta-falsifier

This review could be wrong if: (1) Eneco org disabled project custom-email delivery via policy; (2) pipeline 8951 was deleted/renamed since 2026-06-23 probe; (3) notification inputfilters exposes an undocumented id-based field. **Disprove via live portal create + GET read-back + dual-pipeline email test.**

---

## Recommendation summary

| Action | Priority |
| --- | --- |
| Execute **portal path** as written | P0 |
| Fix REST sketch `clauses` to object array; document subscriber semantics | P1 |
| Run falsifiers after MFA re-auth | P0 |
| Do not close ticket on save/201 alone | P0 |
