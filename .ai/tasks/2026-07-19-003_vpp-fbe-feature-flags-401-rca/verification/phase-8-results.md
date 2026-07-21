---
task_id: 2026-07-19-003
agent: eneco-sre (coordinator)
status: complete
summary: P8 verification — success criteria to evidence map, adversarial dispositions, residual risks for the FBE 401 RCA + how-to-fix.
timestamp: 2026-07-19T00:00:00Z
---

# Phase 8 — Verification Results

## Success criteria → evidence

| Success criterion (P1) | Met? | Witness |
|------------------------|------|---------|
| RCA names the VERIFIED mechanism from the LIVE FBE, not memory | ✅ | Live kubectl: init-myservice writes appconfig.js to emptyDir from application-secret; live drift on 5/6 slots; `az` shows baked stores deleted; live HTTP 401 vs 000 discriminator |
| how-to-fix names exact files/resources/commands with resolved ids | ✅ | `Myriad - VPP/.../frontend/templates/deployment.yaml`, `VPP-Configuration/Helm/frontend/sandbox/values.yaml`, `VPP - Infrastructure/terraform/fbe/app-config.tf`+`common.tf`, `azure-pipelines-featurebr-env.yml` DeployFBEInArgoCD/waitDeploy — all verified real by terraform-oraculum + socrates fabrication sweep |
| EFFECT-based verification (flag 200, not exit-0) | ✅ | how-to-fix P1 gate = baked endpoint == application-secret AND baked store exists in Azure; DoD = browser 200 + "Tennet NL" indicator |
| One-way doors flagged | ✅ | how-to-fix one-way-door list (store/KV rename ForceNew; destroy 2629; wrong-sub whitelist); purge figures corrected per review |
| No fabricated identifiers | ✅ | socrates fabrication sweep: all identifiers/paths/line-refs verified REAL |

## Adversarial verdicts (see adversarial/receipts-ledger.md)

- **sre-maniac (reliability/fix):** architecture SURVIVES; 2 corrections applied (Azure-store assertion in P1 gate; corrected creds overstatement).
- **socrates (goal-fidelity):** PROBLEMATIC → 2 critical over-claims corrected (reproduced-401 → mechanism-drift proof; contradicted temporal story dropped); goal fidelity SURVIVES; fabrication SURVIVES (all real).
- **terraform-oraculum (IaC):** all 4 core claims CONFIRMED against pinned v0.1.0; 3 gotchas applied (tag hygiene, local_auth caveat, plan pre-ship, purge-figure fix).
- **codex ×2 (cross-family):** BLOCKED — exited without receipts (codex-cli cache bug + derailment); NOT retried; typed panel covers the requirement; mechanism reviewer's visible reasoning independently corroborated the fleet-drift-vs-401 correction.

Disposition: 11 RESOLVE, 1 DEFER (disclosed LOW), 2 confirm-no-change. Defer ratio < 50%; no HIGH/BLOCKING deferred; no prose-only rebut.

## Residual risks (disclosed, not blocking)

1. **Provider behaviour doc-verified, not plan-verified** — run one `terraform plan` on a throwaway slot to confirm the store shows no-replacement before shipping P3 (stated in how-to-fix P3).
2. **"Tennet NL" indicator↔App-Config binding is filer-observed (Duncan A1), not code-traced** — DoD verification observes BOTH the 200 AND the indicator.
3. **Per-slot recreation timeline not fully reconstructable** (only current-store createdAt readable) — labelled A3 in RCA L7; does not affect the mechanism or fix.
4. **P2 Reloader requires the controller to be installed** (absent today) — P1 pipeline fix has no such dependency and covers the pipeline-driven case.
5. **Immediate mitigation (restart 5 drifted slots) is authorization-gated** — changes live FBE state; run only with owner OK (not executed by this investigation).

## Map-back to P2

All P2 lanes consumed: incident intake, Obsidian vault (F22/LL-036), precedent RCA, Jupiter probe, GitOps+pipeline source, live cluster, Azure control plane, local repos (pulled to latest). No skipped lane changed the route.
