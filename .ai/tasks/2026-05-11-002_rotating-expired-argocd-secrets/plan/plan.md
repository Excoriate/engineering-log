---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: complete
summary: P5 plan with 6Qs, Adversarial Challenge, deliverable structure, verify strategy delta
phase: 5
---

# P5 — Plan

## Cross-source convergence matrix

| Claim | Vault | Slack | Wiki | IaC | Status |
|---|---|---|---|---|---|
| 4 PATs in scope, sa_platform_vpp owner | ✓ | ✓ | ✓ | ✓ | A1 FACT (4-source) |
| Sandbox cluster vpp-aks01-d / RG / sub | ✓ | ✓ | ✓ | ✓ | A1 FACT |
| Auth-break timestamp 2026-05-10T12:40Z | ✓ | ✓ | ✗ | ✗ | A1 FACT (2-source) |
| NO documented procedure exists | ✓ (vault flags it) | ✓ (Fabrizio explicit) | ✓ (only FAQ ownership statement) | ✓ (no runbook in repo) | A1 FACT (4-source) |
| MC ArgoCD URLs (eneco-vpp-server-...ceap.nl) | ✗ | ✗ | ✓ | ✓ (CR exists) | A1 FACT (2-source) |
| TWO ArgoCD per MC cluster (custom + openshift-gitops) | ✗ | ✗ | ✓ | ✓ (CR namespace eneco-vpp-argocd) | A1 FACT |
| PAT-expiry generator = ADO pipeline 2735 / PR 140615 | ✗ | ✓ | ✓ | ✓ (PS1 in devops repo) | A1 FACT (3-source) |
| sa_platform_vpp creds in Trade Platform Team password vault | ✗ | ✓ (Roel Jan 23) | ✗ | ✗ | A2 INFER (1-source) |
| MC PATs possibly CMC-side-operated | ✗ | ✓ (Roel Mar 3 hint) | ✗ | ✗ | A3 UNVERIFIED — must ask Fabrizio |
| `goldilocks` repo identity | ✗ | ✓ (1 mention as "Goldilocks application") | ✗ | ✗ (only k8s VPA goldilocks) | A3 UNVERIFIED |
| ESO is NOT deployed | ✗ | ✗ | implicit | ✓ (zero matches) | A1 FACT (IaC-confirmed) |
| Sandbox repo Secret IaC source | (recipe assumes manual) | ✗ | partial (CSI for TLS only) | ✓ (Helm chart placeholder; NO Terraform; NO ESO) | A2 INFER — likely manual `kubectl apply` |
| Vault KV note ('vpp-appsec-d' has acc + devmc ArgoCD PATs) | ✓ | ✗ | partially refutes (wiki says vpp-aks-devops) | ✓ (acc/devmc KV entries exist but not Terraform-managed) | A2 INFER — likely partial/stale |

## The 6Qs

### Q1 — What load-bearing assumption could flip the plan?

**Candidate assumptions**:
- A. The vault recipe's `kubectl patch` step works on the LIVE sandbox cluster (i.e., the Secret is NOT Helm-managed / sealed-secret-managed, so a patch survives the next ArgoCD reconcile).
- B. MC PATs are rotated by us, not by CMC-side staff.
- C. Updating the KV (e.g., `argocd-repository-credentials-template-url-devmc`) actually propagates to the cluster Secret (without a sync mechanism this is FALSE).
- D. The `sa_platform_vpp@eneco.com` PAT minting authority is held by anyone on Trade Platform.

**Most route-flipping**: **A**. If the sandbox Secret is Helm-rendered and the live values come from a pipeline secrets store, then `kubectl patch` works for ~5-10 min until the next Argo sync overwrites it from a stale Helm-rendered value. My runbook would silently regress.

**Probe** (if cheap and route-changing): `kubectl get secret repo-NNNNNNNNNN -n argocd -o yaml | grep -E 'managed-by|argocd.argoproj.io/instance|app.kubernetes.io/managed-by'`. Cheap and discriminating. **BUT** runtime probing is out of scope for this task per user directive — therefore I MUST surface this as a load-bearing `[PENDING: ask Fabrizio]` and have the runbook's Section A include this exact probe BEFORE the patch step (defense-in-depth).

**Decision**: runbook Section A adds a Step 4.5 ("Check ownership labels — if any sync controller owns this Secret, STOP and follow that controller's rotation path") between Step 4 (curl test) and Step 5 (patch).

### Q2 — What is the simplest mechanism that explains the observations?

**Observation**: 4 named PATs exist; PAT-expiry pipeline reports them via ADO API; KV has 2 of 4 entries; vault recipe documents direct kubectl patch for sandbox; no ESO; CMC-side mention for Goldilocks.

**Simplest mechanism**: 
- All 4 PATs are minted manually under `sa_platform_vpp@eneco.com` in ADO UI (no IaC).
- The PAT values are stored in (a) Trade Platform Team password vault (1Password/Bitwarden) as the source-of-truth, (b) optionally Azure KV (vpp-appsec-d has 2 entries; missing the other 2 — probably never added or stale).
- For each cluster's repo Secret, the PAT is **manually applied** to the cluster (kubectl/oc apply) after minting.
- The KV entries are vestigial or used only for CSI-mounted contexts that don't exist for ADO Git repo creds.
- CMC-side may operate MC ArgoCD PATs because the MC clusters live on CMC-managed OpenShift; Trade Platform may not have direct kubectl access to MC OpenShift.

This explains: (i) why no procedure exists in code (it's manual), (ii) why KV has 2/4 entries (drift), (iii) why CMC was mentioned (operational boundary), (iv) why vault recipe works for sandbox only (sandbox is Trade-Platform-managed AKS; MC is CMC-managed OpenShift).

**If this mechanism is right** → runbook Section A and B differ structurally:
- Section A (sandbox) — Alex executes
- Section B (MC) — Alex FILES A REQUEST with CMC, providing the new PAT(s)

### Q3 — What evidence would disprove the simplest mechanism?

| Disproof | Effect |
|---|---|
| Fabrizio confirms MC is Trade-Platform-operated (not CMC) | Section B becomes executable by Alex (different KV/cluster path) |
| Live cluster Secret has `app.kubernetes.io/managed-by: Helm` or sealed-secret annotation | Section A must change: rotation = update Helm values / sealed secret, not kubectl patch |
| KV `vpp-aks-devops` (not `vpp-appsec-d`) holds the sandbox PAT and there IS a sync mechanism | Section A could be "az keyvault secret set + wait for sync" instead of kubectl patch |
| The 2 missing KV entries (accmc, prdmc) exist in a different KV per-env | Section B has 3 KV update steps, one per env |

**Each of the above becomes a `[PENDING: ask Fabrizio]` block** in the runbook, with the exact probe that would resolve it.

### Q4 — Hidden complexity I haven't surfaced?

**Surfaced**:
- TWO ArgoCD per MC cluster (custom `eneco-vpp-argocd` + Red Hat `openshift-gitops`) — section B MUST disambiguate
- Helm-managed vs manually-applied Secret ownership labels — Section A pre-flight probe added
- CMC-side ownership of MC PATs — Section B becomes "file request" not "execute"
- Trade Platform Team password vault as parallel source-of-truth to ADO mint UI — Section A must address "where do I save the new PAT for the team" alongside "where do I put it in cluster"

**Not yet surfaced (potential blind spots)**:
- **ApplicationSet on MC**: does `vpp-feature-branch-environments` ApplicationSet exist on MC too? If yes, the same failure mode + recovery applies; if no (likely — FBEs are sandbox-only), the post-rotation verification step differs for MC (no ApplicationSet recovery probe to run)
- **Annotation `argocd.argoproj.io/refresh=hard` for OpenShift GitOps Operator-managed ArgoCD**: does the same annotation work? Likely yes (it's an ArgoCD CRD annotation, controller-agnostic), but worth flagging
- **Goldilocks application reconcile cadence**: if Goldilocks application is sync-policy `manual`, the PAT rotation doesn't auto-recover even after Secret update — manual `argocd app sync goldilocks` needed
- **Cross-PAT propagation timing**: if Alex rotates all 4 PATs in sequence, each PAT mint requires a fresh login as `sa_platform_vpp@eneco.com` in ADO UI; the SA's MFA / authentication may rate-limit. **Plan to mint in a batch, not iteratively.**

→ Each of these becomes a section in the runbook + a `[PENDING]` for confirmation.

### Q5 — Versions and binary semantics I must verify

| Binary / API | Version-sensitive claim | Verification |
|---|---|---|
| ArgoCD sandbox | `v2.10.5` (per IaC sidecar Q2) — supports `argocd.argoproj.io/refresh=hard` annotation and ApplicationSet conditions | ArgoCD v2.10+ docs (cross-cited; OK) |
| ArgoCD on MC (`openshift-gitops` operator) | Version `[UNVERIFIED]` — operator version determines whether `argoproj.io/v1beta1` CR is in use (yes per IaC sidecar Q6); CRD field schema | OpenShift GitOps Operator changelog (`librarian` if needed) |
| Azure DevOps PAT API | `https://vssps.dev.azure.com/{org}/_apis/Token/SessionTokens` and `https://dev.azure.com/{org}/_usersSettings/tokens` (per IaC sidecar Q7) | Microsoft Learn — stable API |
| Azure CLI | `az keyvault secret set --vault-name $KV --name $NAME --value $VALUE` — stable since 2.x | `az --version` on operator's box |
| kubectl | `kubectl patch secret ... --type=json` — stable since 1.16 | `kubectl version` |
| `oc` (OpenShift CLI) | `oc apply -f` semantics on Operator-managed ArgoCD — Operator may revert changes if Secret is in its watched scope | OpenShift GitOps Operator docs |
| Bitnami SealedSecret controller | Exists in MC clusters per asset-scheduling — version unknown | `[PENDING]` |

**Most critical**: `oc apply` vs the Operator on MC. If the Operator's CR has `spec.repo.repositories` referring to a Secret it owns, manually applying a different Secret may be REVERTED by the Operator's reconciler. **Section B must address this** — and `[PENDING: ask Fabrizio: does OpenShift GitOps Operator on MC own the repo creds Secret?]`.

### Q6 — How could this look successful while wrong? Method-of-verification failure?

**Silent-fail scenarios for the runbook**:

1. **Pattern: rotated PAT, ApplicationSet still failing** — could mean: (a) wrong Secret patched (multiple `repo-*` exist), (b) Helm controller overwrote the patch, (c) Operator reverted, (d) ADO PAT scoped wrong (not Code Read on this specific repo), (e) PAT minted for personal user not SA.
   **Verification step**: post-patch curl test + ApplicationSet condition watch. **Must require BOTH probes; either alone is insufficient**.

2. **Pattern: ApplicationSet recovers but downstream services still missing** — could mean: (a) CVE-blocked Docker images (vault pattern doc), (b) sealed-secret decrypt failure for service secrets, (c) Helm value drift. **Out of scope** for this task — runbook step 8 explicitly delegates to other vault notes.

3. **Pattern: KV updated but cluster Secret unchanged** — could mean: no sync mechanism exists (most likely per IaC sidecar). **Verification step**: after KV update, EXPLICITLY run `kubectl get secret -o yaml` to confirm value matches. Do not assume KV update propagates.

4. **Method-of-verification failure**: "I curl'd the URL and got HTTP 200" — could be SPA catch-all per vault `eneco-vpp-argocd-healthy-but-unreachable-troubleshooting.md`. **Must check `Request-Context` + `x-correlation-id` headers**, not just status code.

5. **Wrapper-mirror drift**: runbook references vault recipe step IDs; if vault recipe changes after this runbook is authored, drift. **Mitigation**: runbook embeds the commands inline rather than referencing.

6. **Manifest drift on MC**: even if I rotate the PAT and the OpenShift GitOps Operator accepts the new Secret, the Goldilocks application's Helm values may still reference an old credential by name. **Verification step**: `oc get application goldilocks -n eneco-vpp-argocd -o yaml | grep -A5 source` to confirm.

7. **Compact-mode silent failures**: N/A — this task is Full mode.

### Q7 (CRUBVG≥4) — Orthogonal angle I haven't asked

**Other consumers of these PATs** I haven't named: are these PATs ONLY used by ArgoCD, or also by other systems (e.g., a CI pipeline that runs `git clone` using the same PAT)?

- The PAT names strongly suggest single-purpose: `argo-cd-sandbox`, `argo-cd-{env}mc-cmc-goldilocks-repository`
- But Slack Q3 finding mentions `sa-platform-vpp-monitoring-pat-token` is a DIFFERENT PAT used by the monitor script
- So there are MORE PATs under `sa_platform_vpp` than the 4 in scope — meaning the rotation pipeline doesn't even reset its own counter (rotating these 4 doesn't extend the monitor's life)

**Implication**: Section 9 ("Document the rotation") MUST cross-reference the broader PAT inventory; the post-rotation check should include "verify the 2026-05-08-style report next-cycle no longer flags these 4."

## Adversarial Challenge

Per CRUBVG=8 + control-plane-adjacent action-bearing doc → **TWO frames triggered, both dispatched**:

| Frame | Agent | Attack vector | Artifact | Expected belief-change |
|---|---|---|---|---|
| Socrates (assumption) | `socrates-contrarian` | "What if the vault recipe is wrong about the kubectl patch path? What if the recipe is correct for the wrong reason?" | `auxiliary/socrates-attack-on-procedure.md` | If Socrates surfaces a routable hidden assumption → runbook gets a new `[PENDING]` or a different Step 4.5 |
| El-Demoledor (destruction) | `el-demoledor` | "How can the rotation procedure fail in a way the runbook claims is impossible? Force a counter-example for each Decision Rule." | `auxiliary/eldemoledor-attack.md` | If el-demoledor proves a Decision Rule false → runbook prose gets corrected; falsifiers refined |

**Both run BEFORE I author the deliverables in P7.** Coordinator does NOT self-attack — typed adversarial subagents only. Frame composition rule satisfied (≥2 frames, both dispatched).

Plan.md `## Adversarial Challenge` populated below ↓.

### Adversarial Challenge (manifest)

- Frame 1: socrates-contrarian → attack inherited interpretation of vault recipe + Fabrizio quote + simplest-mechanism hypothesis from Q2
- Frame 2: el-demoledor → attack each Decision Rule in the planned runbook; find counter-examples
- Both dispatched in parallel from P5; await both artifacts before P6.

## Verify Strategy Delta (from P3 final)

| Element | P3 Final | P5 Plan | Change reason |
|---|---|---|---|
| F1 unflagged claims | Same | Same | UNCHANGED |
| F2 KV→cluster mark as PENDING | Same | Same | UNCHANGED |
| F3 each command has Decision rule | Same | TIGHTENED — Decision rule MUST list at least one failure mode + remediation pointer | Q6 surfaced silent-fail patterns |
| F4 ≥1 mermaid + ≥1 ASCII | Same | TIGHTENED — visuals MUST disambiguate sandbox vs MC and the 3 sync candidates | Wiki sidecar's two-ArgoCD finding |
| F5 PENDING items ≥5 | Same | TIGHTENED — ≥10 explicit `[PENDING: ask Fabrizio]` blocks; each names probe-or-question | Sidecars surfaced 13+ gap classes |
| F6 ≥3 proposal options | Same | TIGHTENED — Option B (KV+ESO) reframed as "KV+ESO is greenfield (ESO not deployed); cost includes ESO install" | IaC sidecar confirmed ESO absent |
| F7 Agent Laundering | Same | TIGHTENED — every load-bearing claim from a single sidecar gets `[INFER from <sidecar>]` flag in the deliverables | Honesty about provenance |
| F8 escalation template | Same | TIGHTENED — escalation MUST address the CMC-side-operated-MC hypothesis (file request to CMC rather than execute) | Slack sidecar Q2 hint |
| F9 (NEW) | — | NEW — runbook must include "previous PAT lifetime cleanup" — disable / leave-to-expire the old PAT post-rotation | INC-75 + Roel's pattern from F4 |
| F10 (NEW) | — | NEW — Section B must explicitly direct on whether Alex acts (Trade-Platform-managed) or files request (CMC-managed) | Slack sidecar Q2 hint |

## Plan steps (each = file write + adversarial gate)

| Step | Output | Predecessor | Acceptance | Failure mode |
|---|---|---|---|---|
| S1 | `auxiliary/socrates-attack-on-procedure.md` | — | Socrates artifact populated, `test -s` | Socrates fork-as-fallback → HALT (typed only) |
| S2 | `auxiliary/eldemoledor-attack.md` | — | EL-d artifact populated, `test -s` | Same |
| S3 | Consolidated receipts | S1, S2 | Per finding: Accepted/Rebutted/Deferred + evidence | Systematic Defer ≥50% → HALT |
| S4 | `specs/draft-rotation-secrets.spec.md` | S3 | Spec exists with sections + falsifiers | grep on required sections |
| S5 | `specs/how-to-rotate.spec.md` | S3 | Spec exists | grep |
| S6 | `specs/proposal-rotation-automation.spec.md` | S3 | Spec exists | grep |
| S7 | `output/draft-rotation-secrets.md` → user path | S4 + adversarial receipts | F1-F10 PASS sample | grep + visual inspection |
| S8 | `output/how-to-rotate.md` → user path | S5 + adversarial receipts | F1-F10 PASS sample | grep + visual inspection |
| S9 | `output/proposal-rotation-automation.md` → user path | S6 + adversarial receipts | F1-F10 PASS sample | grep + visual inspection |
| S10 | `verification/phase-8-results.md` | S7, S8, S9 | All falsifiers PASS or `[CRITERION-Δ]` evidence | P8 attack |

## Runtime attacks (for `manifest.runtime_attacks` per execution step)

Each S7-S9 step triggers a Frame attack pre-completion:
- S7 → sre-maniac on draft-doc (does the harvest miss a critical source?)
- S8 → neo-hacker on how-to-rotate (trust-boundary attack)
- S9 → sre-maniac on proposal (failure-path attack on each option)

## Compression mode reaffirm

**Full** — UNCHANGED from P1/P3. CRUBVG=8 still applies. U axis partially resolved for sandbox; still high for MC.

## Counterfactual: what if Socrates + el-demoledor find NOTHING

Then the plan proceeds to P6 with confidence enhanced (adversarial dispatch was real attack, not theater). Deliverables still get authored per spec. Verify strategy unchanged.

## What if they find a route-flipping issue

Then P5 re-entry: update this plan with the new finding + delta; re-dispatch the affected frame on the revised premise.
