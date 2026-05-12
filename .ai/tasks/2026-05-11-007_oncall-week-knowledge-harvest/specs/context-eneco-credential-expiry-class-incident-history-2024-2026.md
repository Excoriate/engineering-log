---
task_id: 2026-05-11-007
agent: claude-code
status: complete
summary: Spec for new vault context note — chronicle of Eneco Trade Platform credential-expiry-class incidents from 2024-11 through 2026-06 (latent). Five instances, same firefighter, recurring class. Ready to apply to llm-wiki/context/repos/.
spec_target_path: $SECOND_BRAIN_PATH/llm-wiki/context/repos/eneco-credential-expiry-class-incident-history-2024-2026.md
spec_action: create
spec_zone: context/repos
spec_status: ready_to_apply
---

# Spec — Context: Eneco Credential Expiry Class — Incident History 2024-2026

## Frontmatter (apply verbatim)

```yaml
---
description: "Chronicle of credential-expiry-class incidents at Eneco Trade Platform from 2024-11 through 2026-06 (latent). Five instances in 18 months, all silent failures, all firefought by the same person (Fabrizio Zavalloni). Surfaces across multiple credential types: AAD service principal secrets (FBE), KeyVault client secrets (PXQ), Azure DevOps Personal Access Tokens (ArgoCD). Each post-incident note flagged 'must be automated'; no class-level remediation has shipped. Reference table for ANY engineer at Trade Platform considering a new credential — the rotation owner / verification path / alarm surface MUST be declared in the same PR per [[credential-expiry-is-a-class-problem-not-per-incident-firefight]]."
type: context
domain: work
status: active
source: agent
created: 2026-05-11
last_validated: 2026-05-11
severity: high
confidence: validated
tags: [eneco, trade-platform, credentials, rotation, incident-history, class-problem, fabrizio-zavalloni, aad-sp, keyvault, azure-devops-pat, durable-context]
---
```

## The Pattern

| Date | Incident ID | Surface | Credential class | Resolution path | Outcome note |
|------|------------|---------|-----------------|----------------|--------------|
| 2024-11-19 | INC-75 | Multi-FBE | AAD SP secret expired | Fabrizio rotated per-FBE manually | *"This manual process is error-prone and must be automated to prevent such issues in the future."* (post-incident note) |
| 2025-12-29 | F4 | All active FBEs | Same AAD SP `6db398ec-...` expired again | Fabrizio rotated per-FBE manually over ~1h+ | No class-level remediation shipped between INC-75 and F4 |
| 2026-05-07 | PXQ | PXQ service | KV client secret expired | Same class — discussion in `#pxq` | Same firefighter pattern; different credential class |
| **2026-05-11** | (today) | Sandbox FBE | `argo-cd-sandbox` PAT expired 2026-05-10 (Critical) | Manual rotation by Alex + Fabrizio guidance at 15:35 CEST; `how-to-rotate.md` runbook authored (1291 lines) + `proposal-rotation-automation.md` (3 options) | First written runbook; runbook ≠ structural fix |
| **2026-06-01** | (latent) | dev-MC / acc-MC / prd-MC | 3 ArgoCD PATs `argo-cd-{devmc,accmc,prdmc}-cmc-goldilocks-repository` | Alex committed (2026-05-11 15:35 #team-platform) to handle 2026-05-12 | Proactive — must rotate BEFORE 06-01 |

## Quantification

- **Recurrence rate**: ~1 credential-expiry incident every 2-3 months at Trade Platform
- **Firefighter**: Fabrizio Zavalloni in all five (oral procedure transferred per-incident; documented for the first time on 2026-05-11)
- **Average time-to-surface**: silent failure; 22h for today's incident (auth break 2026-05-10T12:40Z → Fabrizio's question 2026-05-11T12:32Z)
- **Cumulative cost projection** (per `proposal-rotation-automation.md` Quantification):
  - Per incident: 60-90 min rotation × N environments + 22h silent failure cost + investigation effort
  - At 6/year: ~150h/year platform-engineer toil, all on Fabrizio

## Fabrizio's Quotes

- DM 2026-04-10: *"this is a shit job to be done and can cause outages."*
- #team-platform 2026-05-11 12:32 CEST: *"Has anybody renewed the Pat Token used by the Argocd in Sandbox?"* (the incident-discovery moment)
- #team-platform 2026-05-11 12:47 CEST: *"Nope. There is no documentation for this. It is a good opportunity to create one. You can give me a call and I explain you the process."* (the runbook genesis)

## Roel's Position

- #team-platform 2026-05-11 12:37 CEST: *"Not me, this list is part of ops-of-the-week"* (assigns rotation ownership to OoTW role; UNCONFIRMED as team policy)

## Per-Class Detail

### AAD Service Principal Secrets (INC-75, F4)

- Owner: `app-registration-fbe` (per FBE slot) → expiration auto-renews via... unclear; previously rotated manually
- Specific SP: `6db398ec-...` recurring in INC-75 + F4
- Vault path for credentials: `vpp-appsec-d` (per `how-to-rotate.md` references)

### KeyVault Client Secrets (PXQ 2026-05-07)

- Owner: PXQ service team
- Discussion: `#pxq` (cross-team; not on Trade Platform's primary channels)

### Azure DevOps Personal Access Tokens (today, latent)

- Service account: `sa_platform_vpp@eneco.com` (shared, in Trade Platform Team vault)
- 4 PATs in scope (sandbox + 3 MC); all minted under same SA identity
- ADO ceiling: 12 months lifetime
- Monitor: ADO pipeline 2735 (`myriad-vpp/devops/azure-pipelines.yml`); posts to `#myriad-alerts-devops` daily ~13:01 CEST

### Other Latent Classes (per `proposal-rotation-automation.md` Phase 3)

- F4 AAD SP (recurring credential)
- ESP cert (PFX rotation — `vppal-cert-rotation-runbook.md`)
- TF SP credentials (Terraform service principal for IaC pipelines)
- BTM credentials
- Snyk token

## When to use this context

Read this note when:

1. Authoring a new credential at Trade Platform (use as the registry to check against)
2. RCA'ing a "credential expired" incident (this is the Nth instance, NOT the first)
3. Reviewing a credential-rotation runbook PR (compare to the others; ensure structural-fix is named)
4. Planning the next quarter's SRE-platform work (the latent 2026-06-01 must rotate; the structural remediation must start)
5. Onboarding a new Trade Platform engineer (this is the operational pain class to understand)

## Cross-Links

- [[credential-expiry-is-a-class-problem-not-per-incident-firefight]] — the durable lesson distilled from this history
- [[argocd-pat-expiry-silently-fails-applicationset-generation]] — today's specific gotcha (instance #4)
- [[2026-05-11-oncall-shift-trade-platform-quad-incident]] — today's episode (Incident 4)
- Source runbook: `log/employer/eneco/02_on_call_shift/2026_05_11_rotating_expired_argocd_secrets/how-to-rotate.md` (1291 lines)
- Source proposal: same dir, `proposal-rotation-automation.md` (505 lines, 3-option roadmap)
- Source intake: `log/employer/eneco/02_on_call_shift/2026_05_11_rotating_expired_argocd_secrets/slack-intake.txt`
