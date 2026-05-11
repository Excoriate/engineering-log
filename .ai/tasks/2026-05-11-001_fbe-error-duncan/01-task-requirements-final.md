---
task_id: 2026-05-11-001
agent: claude-opus-4-7
status: pending_review
summary: Final task requirements — root cause confirmed (F2 Azure-resource sub-class), fix route chosen, verification strategy locked
---

# Task Requirements — FINAL

## Verify Strategy Delta (vs initial.md)

| Surface | Initial assumption (P1) | After P2 evidence | Δ |
|---|---|---|---|
| Pipeline definition | `azurepipelines-fbe.yaml` in `enecomanagedcloud/VPP%20-%20Infrastructure` | **CORRECTED**: actual is `azure-pipelines-featurebr-env.yml` in `Myriad - VPP` repo (ID 2412) | MAJOR — wrong file initially mapped; corrected via P-OBSOLETE-YAML |
| State backend mechanism | Pipeline YAML uses `${{ parameters.environment }}` (ADO template) | **CORRECTED**: pipeline 2412 uses PowerShell variable substitution `terraform.$(featurebranchname)`, NOT ADO template; `featurebranchname` derived from limiter-table lookup | MAJOR — initial typo-bug hypothesis refuted |
| Root cause | Possibly typo bug in pipeline OR orphan from prior tenant | **CONFIRMED**: F2 Cleanup-Residue at Azure-resource layer; orphan namespace from old kidu tenant (2025-06-10) | REFINED — hypothesis narrowed to F2 |
| Failure scope | Multiple possible orphan resources | **NARROWED**: only `vpp-evh-premium-kidu` is the orphan; namespace is empty (no EHs, no CGs); standard NS is tracked correctly | NARROWED |
| Fix complexity | Could require terraform import + state surgery | **SIMPLIFIED**: orphan is empty → `az eventhubs namespace delete` + pipeline rerun is safe | SIMPLIFIED |

## Verification Strategy

| Acceptance | Probe | Witness | Truth Surface |
|---|---|---|---|
| SC1 RCA at `output/rca.md` follows L1-L12 ladder | `grep -E '^## L[0-9]+' output/rca.md` | filesystem | reader (post-doc) |
| SC2 Load-bearing FACTs cite externally-witnessable evidence | `grep -E 'A1|A2|A3' output/rca.md` + manual spot-check | filesystem | adversarial reviewer |
| SC3 Fix doc has exact commands + expected output + decision rule + rollback | `grep -E '## Step|Expected|Decision|Rollback' output/fix.md` | filesystem | Duncan or AI agent following the doc |
| SC4 All C1-C16 re-probed | `context/evidence-ledger.md` exists with classification per claim | filesystem | adversarial reviewer |
| SC5 Adversarial dispatch absorbed | `auxiliary/adversarial-review-*.md` files exist with deltas | filesystem | manifest.gate_witnesses |
| SC6 Zero-context reader can replicate cold | Read-through test by author + Phase 8 self-stress | reader trace | meta — kant frame |
| SC7 Fix command safe (does not destroy shared Sandbox infra) | Destructive-action lexicon check + namespace-scope verification | static analysis | command output post-fix |
| SC8 Duncan unblocked | Pipeline 2412 rerun → success → Slack notification in `#myriad-env-fbe` | Duncan's pipeline | functional outcome |

## Hypotheses — FINAL (after P2 evidence)

| H | Statement | Status |
|---|---|---|
| H1 | Orphan from prior failed FBE create on kidu slot | **CONFIRMED** — namespace created 2025-06-10, no tags, not in state, slot was released to "unused" before Duncan |
| H2 | env-name collision (`kidu` is reused literal across runs) | **TRUE BUT NOT THE FAILURE** — slot reuse is the FBE design; collision is mitigated by full-cleanup destroy; the design works when destroy is clean. F2 is the design's failure mode |
| H3 | State backend mis-config / typo bug | **REFUTED** — pipeline 2412 uses PowerShell var-sub correctly; no typo |
| H4 | Premium SKU slow-delete left orphan | **PLAUSIBLE MECHANISM** for how the namespace became orphan, but it's a sub-mechanism of H1; the catalog (F2) does not constrain the destroy-side mechanism |
| H5 | Variable `environment=kidu` reused by Duncan after prior FBE was torn down without state cleanup | **CONFIRMED** — exactly Duncan's situation; matches the F2 mechanism |

## Final Mode + Reader

- **Compression Mode**: Full (CRUBVG=9, control-plane FALSE, deliverable-bearing, investigation+review)
- **Named reader**: Duncan (immediate unblock) + next-shift on-call (long-term mastery transfer)
- **Output Package level**: standard (multi-system: pipeline ↔ repo ↔ state ↔ Azure ↔ AKS ↔ ArgoCD)
- **Levels in the ladder selected for THIS incident**: L1, L2, L3, L4, L5, L6, L7, L8, L9, L10, L11, L12 — all twelve. The incident is multi-system, multi-repo, and the reader needs end-to-end mastery to defend the conclusions and execute the fix.
