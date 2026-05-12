---
task_id: 2026-05-11-007
agent: claude-code
status: complete
summary: Spec for new vault lesson — credential expiry is a recurring class problem at Trade Platform (5 incidents in 18 months); class-level remediation > per-incident firefighting. Ready to apply to llm-wiki/learnings/lessons/.
spec_target_path: $SECOND_BRAIN_PATH/llm-wiki/learnings/lessons/credential-expiry-is-a-class-problem-not-per-incident-firefight.md
spec_action: create
spec_zone: learnings/lessons
spec_status: ready_to_apply
---

# Spec — Lesson: Credential Expiry Is a Class Problem, Not a Per-Incident Firefight

## Target Path

`$SECOND_BRAIN_PATH/llm-wiki/learnings/lessons/credential-expiry-is-a-class-problem-not-per-incident-firefight.md`

## Frontmatter

```yaml
---
description: "Credential expiry is the dominant recurring operational pain class at Eneco Trade Platform — confirmed by 5 incidents in 18 months across multiple credential types (AAD SP secrets, KV client secrets, ADO PATs) and 1 additional latent (3 MC ArgoCD PATs scheduled 2026-06-01). Each incident is solved per-credential by the same person (Fabrizio) using the same oral procedure (now finally documented as how-to-rotate.md). Rotating one credential does NOT reduce the probability of the next class-recurrence. The structural fix is class-level: eliminate calendar-expiring credentials (Workload Identity Federation) OR automate rotation (KeyVault + ESO + scheduler). Per-incident firefighting at this recurrence rate is a leadership failure mode."
type: lesson
domain: work
status: active
source: agent
created: 2026-05-11
last_validated: 2026-05-11
severity: high
confidence: validated
scope: "Eneco Trade Platform credential lifecycle across all credential classes — AAD service principal secrets, Azure Key Vault stored secrets, Azure DevOps Personal Access Tokens, certificates (ESP), Snyk tokens, TF SP credentials. Specifically applies to FBE, ArgoCD, F4 AAD SP, PXQ, BTM."
evidence: "log/employer/eneco/02_on_call_shift/2026_05_11_rotating_expired_argocd_secrets/proposal-rotation-automation.md (505 lines, 3-option roadmap); incident recurrence table from same proposal"
tags: [eneco, trade-platform, credentials, rotation, class-level-thinking, workload-identity-federation, eso, keyvault, durable-meta-lesson]
---
```

## Body

> **Class scope**: AAD SP secrets, KV stored secrets, ADO PATs, certificates (ESP), Snyk tokens, TF SP credentials. Every credential at Trade Platform that has a calendar expiry.

## The Rule

When the SAME failure class (X expires → Y breaks → human firefights to rotate X → Z weeks later, X' expires) recurs ≥3 times in 18 months at the same team with the same firefighter, **rotating the next credential is the wrong question.** The right question is: **why does any operational thing have a calendar expiry that requires a human to remember to rotate?**

The structural answer is one of:

- **Eliminate** the calendar-expiring credential (Workload Identity Federation: OIDC tokens have no calendar expiry)
- **Automate** rotation end-to-end (KV + ESO + scheduled rotation function)
- **Decline neither and document the SLA + ownership + monitoring**

But **never** "rotate this one, then go back to the same broken process."

## Why (mechanism — the recurrence pattern at Eneco)

| When | Surface | Credential class | Resolution path | Lessons captured? |
|------|---------|-----------------|----------------|--------------------|
| 2024-11-19 (INC-75) | Multi-FBE | AAD SP secret | Fabrizio rotated per-FBE manually. Post-incident note: *"This manual process is error-prone and must be automated to prevent such issues in the future."* | ✅ noted, not actioned |
| 2025-12-29 (F4) | All active FBEs | Same AAD SP (`6db398ec-...`) again | Fabrizio rotated per-FBE manually over ~1h+ | ❌ same fix as INC-75 |
| 2026-05-07 (PXQ) | PXQ service | KV client secret | Same class; discussion in `#pxq` | ❌ another class instance |
| **2026-05-11 (today)** | Sandbox FBE | ArgoCD PAT | Manual rotation by Alex + Fabrizio guidance; `how-to-rotate.md` runbook finally authored | ⚠️ runbook = documentation, not structural fix |
| **2026-06-01 (latent)** | dev-MC / acc-MC / prd-MC | 3 ArgoCD PATs | TBD — Alex's commitment to handle 2026-05-12 | latent |

Fabrizio's quote (DM 2026-04-10): *"this is a shit job to be done and can cause outages."*

The recurrence rate is approximately **1 credential-expiry incident every ~2-3 months** at Trade Platform, all surfacing as silent failures with multi-hour time-to-detect.

## How to apply

### Immediate test (when the next credential-expiry incident lands)

Before drafting the next per-credential runbook, ask:

1. **Is this the Nth incident in the same class?** Check `[[eneco-credential-expiry-class-incident-history-2024-2026]]` (proposed context note).
2. **Did the prior incident's post-mortem note "must be automated" without scheduling the work?** If yes, the lesson was captured but lost.
3. **Is the proposed fix per-credential or class-level?** Per-credential = same loop. Class-level = invest in Workload Identity Federation OR ESO scheduled rotation.
4. **What's the cost of doing it per-incident, projected over 12 months?** Today's incident was ~22h silent + ~3h investigation + multi-hour rotation + 1 month of doc-authoring effort. At 6 instances/year = ~150h/year of platform-engineer toil, all on Fabrizio.

### Standing directive (proposed for `memory/`)

When authoring or reviewing any change that introduces a credential at Trade Platform:

1. Name the **rotation owner** in the same PR (not "the team" — a named person OR a named automation surface)
2. Name the **rotation verification path** (probe that confirms the new credential works END-TO-END)
3. Name the **alarm surface** (`argocd_appset_status{condition_type="ErrorOccurred"} > 0`, KV expiry alert, ADO PAT expiry monitor card)
4. If the credential has a calendar expiry, declare the **structural plan** (will it be migrated to OIDC / automated rotation / accept manual + monitoring) — DECLINING this declaration = HALT

### Class-level roadmap (per proposal-rotation-automation.md)

**Phase 1 (now → 30d) — unconditional, low cost, MTTD impact**

Option C: Status quo + SLA + Grafana alert + ownership
- Define SLA: rotate within 7d Warning / 24h Critical
- Add `argocd_appset_status{condition_type="ErrorOccurred"} > 0` Grafana alert
- Assign rotation ownership rotation (OoTW per Roel's read; needs confirmation)
- Estimated: 1-3 days engineering
- ROI: high (catches today's class instantly going forward; documents the work)

**Phase 2 (30 → 180d) — structural fix**

Choose Option A or B based on Fabrizio's gap-list answers in `how-to-rotate.md` §7:

- **Option A — Workload Identity Federation**: eliminate PATs entirely; 10-15d engineering; HIGH cutover risk, LOW steady-state risk; only helps ADO-target credentials (not F4 AAD SP / ESP cert / Snyk token)
- **Option B — KV + ESO + scheduled rotation**: 7-10d (but ESO must be installed first; not deployed at Eneco today); cross-class extensible

**Phase 3 (180d+) — extension**

Extend chosen option to F4 AAD SP, ESP cert, TF SP credentials, BTM, Snyk token classes.

## What to avoid

- **"We'll automate this next quarter"** — said after INC-75 (2024-11), said after F4 (2025-12), said after PXQ (2026-05-07). Repeated promises without scheduled work = the class will recur.
- **Adding a per-credential runbook as the "fix"** — today's `how-to-rotate.md` is a *consequence* of the structural defect, not a *remedy*. Documentation reduces MTTR for the next instance; it does NOT reduce the probability of the instance.
- **Treating each instance as a unique RCA** — they share a single root cause (calendar-expiring credentials with manual rotation in oral tradition). RCAing each as if it were novel misses the pattern.

## Cross-Links

- [[argocd-pat-expiry-silently-fails-applicationset-generation]] — today's specific gotcha (one instance of this class)
- [[eneco-credential-expiry-class-incident-history-2024-2026]] — chronicle of recurrence (proposed context note)
- [[2026-05-11-oncall-shift-trade-platform-quad-incident]] — episode of origin (Incident 4)
- [[oncall-rca-must-close-on-every-state-plane]] — adjacent operational discipline
- Source proposal: `log/employer/eneco/02_on_call_shift/2026_05_11_rotating_expired_argocd_secrets/proposal-rotation-automation.md` (505 lines, 3-option roadmap)
- Source runbook: same dir, `how-to-rotate.md` (1291 lines, mastery-grade procedure for current class instance)
