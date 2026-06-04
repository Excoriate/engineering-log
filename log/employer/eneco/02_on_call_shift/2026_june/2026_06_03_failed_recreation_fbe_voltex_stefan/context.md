# Context — voltex FBE "failed recreation" (Stefan)

> Investigation context, system overview, and probe index for `rca.md` / `fix.md`.
> All probes **read-only** on live Sandbox `vpp-aks01-d` (sub `7b1ba02e`), 2026-06-04.

## System overview (one diagram)

```
VPP.GitOps/feature-branch-environments/voltex.yaml
        │  (git-file generator)
        ▼
ApplicationSet  vpp-feature-branch-environments  ── owns ──▶  voltex-app-of-apps  (ns argocd)
                                                                      │ Helm: VPP-Configuration/Helm/vpp-core-app-of-apps
                                                                      │ tracks branch feature/fbe-826335-…
                                                                      ▼  renders 22 child Applications → ns voltex
   alarmengine · frontend · monitor · asset · dataprep · telemetry · dispatcher{afrr,mfrr,manual,scheduled,simulator}
   · clientgateway · gateway-nl · marketinteraction · activationmfrr · alarmpreprocessing · assetmonitor · assetplanning
   · secretprovider(+dispatcher) · integration-tests · opstools
        each child → Deployment/Service/Ingress  then  PostSync seed Job → POST /v1/assets/seed
```

Two control planes share the slot: **`vpp-feature-branch-environments`** (the FBE
service stack — this incident) and **`fbe-voltex-monitoring`** (separate
ApplicationSet, ns `voltex-monitoring`, Synced/Healthy — **out of scope**).

## How the symptom maps to the system

| Stefan saw | Mechanism |
|------------|-----------|
| Only `voltex-app-of-apps` + `alarmengine` in ArgoCD | app-of-apps stuck Terminating; ApplicationSet can't recreate; 21 children deleted, alarmengine wedged |
| Pester: frontend/monitor `Succeeded` | zombie pods (deletionTimestamp 2026-05-18), owning ReplicaSets already gone |
| `[FrontEnd] should get 200` → 404 | no frontend Deployment exists (child not materialised) |
| "I messed up vpp-config on my branch" | **partly right** — branch doesn't break the *render*, but his alarmengine image `0.153.feat.49017e3` + new-TSO appconfig is the leading suspect for the **seed-500** |

## Three-surface evidence (skill mandate: ≥3 orthogonal surfaces)

1. **AKS/ArgoCD:** `deletionTimestamp 2026-06-03T13:14:51Z` + `resources-finalizer`
   on app-of-apps & alarmengine; controller `"Skipping auto-sync: deletion in
   progress"`; only 1 child CRD in ns voltex vs 20 in afi. (A1)
2. **Hook/runtime:** `Job/seed-…-1779187628` holds `hook-finalizer` (stuck
   2026-05-19); seed `POST /v1/assets/seed → 500` since 2026-05-18. (A1)
3. **Git/ADO (branch content):** `az devops` diff — alarmengine image tag
   `0.117.dev`→`0.153.feat.49017e3`; `app_configuration.yaml` (+205 lines, new TSO)
   absent on main; afi runs a *different* `0.153.feat` commit and seeds clean. (A1)

## Full evidence ledger + adversarial receipts

- Ledger (14 rows, A1/A2/A3): `.ai/tasks/2026-06-04-001_rca-fbe-voltex-recreation/context/evidence-and-diagnosis.md`
- **sherlock-holmes** (causal re-probe): CONFIRMED E2/E4/E6/E7/E8; alternatives a/b/c/d REFUTED → `subagent-outputs/sherlock-causal-verify.md`
- **sre-maniac** (fix safety): O3 auto-recreate CONFIRMED; blast radius voltex-scoped; runbook corrected; O5 seed-500 is recurrence generator → `subagent-outputs/sre-fix-safety.md`
- **socrates-contrarian** (assumptions/goal): forced retraction of "branch disproven"; necessary-not-sufficient; demanded the branch diff (since done) → `subagent-outputs/socrates-assumptions-goal.md`

## Open items (named, bounded)

- **Seed-500 root cause** — A3[blocked: alarmengine pods torn down]; resolve by
  capturing alarmengine log at seed time after recreate (fix.md Step 6).
- **Precise 13:14:51 delete trigger** — A3; actor bounded to ApplicationSet
  controller (A2); fix is trigger-independent.
- **VPP.GitOps `voltex.yaml` @ HEAD** — A2 (generator currently lists voltex);
  re-confirmed by fix.md pre-flight gate before any mutation.
