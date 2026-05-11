---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: complete
summary: Pre-sidecar draft of the 3 automation options + tradeoffs + ROI sketch
phase: 4
---

# Proposal options — pre-sidecar draft

> Built from vault evidence + general industry patterns. Will be refined after sidecars deliver concrete IaC/Slack/wiki state. Each option below names: mechanism, ROI, blast-radius, mitigation, ownership, verifiability, rollback.

## Option A — Federated Workload Identity (replace PATs with OIDC)

### Mechanism

Replace `sa_platform_vpp@eneco.com`-based PAT authentication with Azure DevOps **Workload Identity Federation** — ArgoCD repo-server pod uses an AAD Workload Identity → federated credential trusts the AKS OIDC issuer → ADO accepts the OIDC token (no PAT). Recently added to ADO (2024-2025 timeframe; needs verification of GA status in Eneco's tenant).

### Cited basis

- Microsoft Learn: "Use service connections to securely connect Azure DevOps with other services" (Workload Identity Federation pattern, GA 2024)
- ArgoCD: Repository credentials support OAuth (since v2.10ish); workload identity emerges as a pattern in ArgoCD v2.12+
- Vault `recipe-rotate-argocd-sandbox-pat.md:245` line: "If ArgoCD switches from PAT-based authentication to OIDC/managed-identity (the modern approach), Step 3-5 are obsolete; the rotation becomes 'rotate the federated credential' rather than a manual PAT mint."

### ROI (qualitative)

- **Eliminates** PAT expiry as a failure class entirely (federated creds don't expire on a calendar; they're per-token at issuance)
- **Eliminates** SA-impersonation friction (no SA password / no PAT mint authority bottleneck)
- **Reduces** secret-rotation TCO across the platform (also applies to F4 AAD SP class if migrated)

### Blast radius

- HIGH on rollout (changes auth mechanism for all 4 PATs simultaneously OR per-cluster phased)
- LOW post-rollout (no credentials to leak)

### Mitigations

- Phased rollout: 1 cluster at a time (sandbox first, then dev-MC, acc-MC, prd-MC last)
- Keep PAT path live during rollout (dual auth allowed in ArgoCD repo config)
- Test with a non-critical repo first before VPP.GitOps / cmc-goldilocks

### Ownership

- Trade Platform team (owns ArgoCD installs)
- Coordinate with: CCoE/IT (federation trust config), Identity team (AAD app registrations for workload identity)

### Verifiability

- ArgoCD logs show OAuth bearer token usage instead of basic auth
- ADO audit logs show federated identity assertions
- No PAT-expiry alerts firing post-cutover

### Rollback

- Revert ArgoCD repo Secret to PAT auth (keep PAT minted as a break-glass)
- Reset ApplicationSet refresh

### Drawbacks

- Requires Workload Identity GA support across ADO + AKS + OpenShift (MC clusters may lag if on older OpenShift)
- Requires AAD app registration + federated credential PER cluster (3-4 new identities)
- One-time engineering cost: ~2-5 days for design + 1 day per cluster cutover
- Doesn't help with non-ADO credentials (F4 AAD SP, ESP/Axual cert)

## Option B — KeyVault + External Secrets Operator + Scheduled Rotation

### Mechanism

1. **Source of truth**: Azure KeyVault. Each PAT is a KV secret.
2. **Sync**: ExternalSecrets Operator (ESO) reads KV, writes Kubernetes Secret. SecretStore points at KV via Workload Identity (no SP needed for the sync layer if option A's identity work is also applied here).
3. **Rotation**: An Azure Function or Logic App, scheduled monthly (or 30d before expiry), mints a new PAT via ADO REST API, writes it to KV, and updates the PAT-expiry watchlist. ESO syncs to cluster within minutes. ArgoCD picks up on next reconcile.

### Cited basis

- Vault `eneco-vpp-keyvault-secrets.md:28-29` confirms KV already has ArgoCD PAT entries for ACC and DEVMC — implies a sync mechanism is at least partially adopted
- VPPAL cert rotation runbook (`vppal-cert-rotation-runbook.md:34-36`) shows the team is comfortable with the GitOps-managed-secret-in-KV pattern
- ESO is a CNCF graduated project (stable, widely adopted)

### ROI

- **Reduces** rotation execution from 9 manual steps to 1 trigger (the schedule)
- **Aligns** all 4 PATs to a single source of truth
- **Enables** observability — KV access logs + ESO sync events are auditable

### Blast radius

- MEDIUM on rollout (ESO must be deployed in all 4 clusters; existing repo Secrets must be migrated)
- LOW post-rollout (sync runs in-band)

### Mitigations

- Phased ESO deployment (sandbox first to validate end-to-end)
- Keep manual rotation as fallback in vault
- Rotate the AUTOMATION SP / federated credential before turning automation on (the auto-rotator's own credential becomes the new SPOF — must be itself federated)

### Ownership

- Trade Platform team (owns ArgoCD + sync layer)
- CCoE/IT (KV access policy)
- Whoever owns the existing PAT-expiry alert generator (extends it with rotation trigger)

### Verifiability

- KV access logs show automation activity
- ESO sync events in cluster (`kubectl get externalsecret -n argocd -o yaml`)
- ArgoCD condition flips to `ErrorOccurred=False` within minutes of KV update
- PAT-expiry alert never reports `Critical`

### Rollback

- Disable Azure Function schedule
- Manual rotation per vault recipe still works (ESO doesn't prevent kubectl patch; next ESO sync would overwrite, so disable ESO for the affected secret)

### Drawbacks

- Doesn't eliminate PAT as a credential class (still bearer tokens; still leakable)
- Adds ESO complexity (CRDs, sync intervals, secret-mapping config)
- Rotation Function needs its own auth to ADO (recurses into Option A territory)
- 12-month PAT max in ADO — rotation must happen at least annually

## Option C — Status-quo + SLA + ownership + observability (minimal change)

### Mechanism

No new auth layer. Existing PAT-expiry alert stays. ADD:

1. **Written SLA** (Trade Platform decision):
   - `Warning` status → rotate within 7 calendar days
   - `Critical` status → rotate within 24 hours
2. **Designated owner**: on-call engineer auto-claims via Slack workflow (or PR check in `#myriad-platform`)
3. **Grafana alert**: `argocd_appset_status{condition_type="ErrorOccurred"} > 0` against each cluster's metrics endpoint, page on-call
4. **Vault runbook is canonical** — link from `#myriad-alerts-devops` PAT report bot

### Cited basis

- Vault `pattern-argocd-pat-expiry-blocks-new-fbe-apps.md:194` line: "The right alarm is missing. The ApplicationSet condition (`type: ErrorOccurred, status: True`) is a metric that argocd-metrics exposes. A Grafana alert on `argocd_appset_info{health_status!="Healthy"}` or `argocd_appset_status{condition_type="ErrorOccurred"} > 0` would have surfaced this on 05-10 12:40 UTC. Phase-9 follow-up."
- Vault class-level lesson 2: "rotate within 7 days of Warning status, within 24 hours of Critical status"

### ROI

- **Lowest** engineering cost (1-3 days total)
- **Reduces** MTTD from 22h (this incident) to ~5 min (Grafana alert)
- **Documents** the rotation in vault for next engineer

### Blast radius

- ZERO on rollout (no infra changes; only SLA + alerting + ownership)

### Mitigations

- Validate Grafana alert in sandbox first
- Run a tabletop exercise on the SLA with Trade Platform

### Ownership

- Trade Platform team (owns alerting + SLA enforcement)
- On-call rotation as designated rotator

### Verifiability

- PAT-expiry alert fires on schedule (already does)
- Grafana alert fires on next auth break
- Vault runbook is followed (audit by checking incident page after rotation)

### Rollback

- Trivial (it's just policy + an alert)

### Drawbacks

- **Doesn't reduce** rotation toil — humans still do all 9 manual steps
- **Doesn't reduce** SPOF risk (single SA with all 4 PATs)
- **Doesn't address** F4 / ESP / TF SP classes
- Relies on humans not getting distracted (the very failure mode that caused 2026-05-11)

## Comparison matrix

| Dimension | Option A (WIF) | Option B (KV+ESO) | Option C (SLA+Alarm) |
|---|---|---|---|
| Engineering cost | 10-15 days | 7-10 days | 1-3 days |
| Eliminates PAT class | YES | NO | NO |
| MTTD improvement | 100% (no expiry → no incident) | ~99% (KV alert before expiry) | ~95% (Grafana alert at first auth break) |
| Reduces manual toil | YES (zero rotation work) | YES (1-trigger rotation) | NO |
| Cross-cluster consistency | YES (per-cluster identity) | YES (one KV per env) | NO (each cluster manually rotated) |
| F4 / ESP / TF SP applicability | PARTIAL (only where ADO is target) | YES (any KV secret) | NO |
| Risk of cutover | HIGH (auth model change) | MEDIUM (sync layer change) | ZERO |
| Reversibility | HARD (rollback to PAT possible but visible) | MEDIUM (disable Function, ESO stays) | TRIVIAL |

## Sequencing recommendation (preliminary; refine after sidecars)

**Phase 1 (now-30d) — do Option C unconditionally**:
- Grafana alert + SLA + ownership are low-cost and high-MTTD-impact
- Documents the rotation properly
- Buys time for Option A/B decision

**Phase 2 (30-180d) — choose Option B if KV+ESO is already 80% adopted; choose Option A if not**:
- If IaC sidecar confirms ESO is in MC clusters and KV is the source of truth → Option B extends a familiar pattern
- If IaC sidecar shows green-field → Option A is the durable choice (eliminates the class)

**Phase 3 (180d+) — extend chosen option to F4 / ESP / TF SP classes**:
- Unified rotation discipline across all credential classes

## Anti-patterns to call out in the proposal

- **Manual rotation in cluster + KV in parallel** (current asymmetry — sandbox uses kubectl patch; MC uses KV-presumably) → drift, two-source-of-truth confusion → STOP
- **PAT shared across clusters** (one PAT for sandbox + MC) → cross-cluster blast radius → already-avoided by current 4-PAT split
- **PAT in commit** (any repo, ever) → bearer-credential leak → never
- **Restart-controllers-fixes-it superstition** → ineffective, wastes incident time → don't recommend
- **Disable ApplicationSet sync as workaround** → silences symptom; breaks GitOps contract → never
- **Auto-rotation without a verification gate** → if the new PAT is invalid (wrong scope), all 4 clusters lose auth simultaneously → MUST have a pre-patch curl test (per vault recipe Step 4)
