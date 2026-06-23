---
task_id: 2026-06-22-005
slug: fbe-404-rca-howtofix
agent: eneco-sre-coordinator
status: complete
timestamp: 2026-06-22T11:36:00Z
summary: Fix applied and verified. Cleared wedged resources-finalizer on operations-app-of-apps + assetmonitor; ApplicationSet self-healed (fresh app-of-apps Synced/Healthy at 11:32:48); slot converged 21/21 Synced, 19/21 Healthy; public URL 404 -> 200 within ~1 min.
---

# Fix result — FBE 404 operations (applied 2026-06-22 ~11:32 UTC, live Sandbox vpp-aks01-d)

## Action taken (A1 — `context/probes/fix-apply.log`)
Two read-write `kubectl patch` commands (user-authorized; no other mutation):
```bash
kubectl --context vpp-aks01-d -n argocd     patch application operations-app-of-apps --type=merge -p '{"metadata":{"finalizers":[]}}'
kubectl --context vpp-aks01-d -n operations patch application assetmonitor          --type=merge -p '{"metadata":{"finalizers":[]}}'
```
Both returned `application.argoproj.io/<name> patched`.

## Mechanism of the fix (A1-observed)
Clearing the wedged `resources-finalizer.argocd.argoproj.io` let the 21-day-pending deletion COMPLETE.
Because the ApplicationSet `vpp-feature-branch-environments` (healthy) **owns** `operations-app-of-apps`
(ownerReference `controller:true`) and **still generates** `operations` as a target, it immediately
**regenerated a fresh `operations-app-of-apps`** the moment the wedged CR was gone — no pipeline / `az`
recreate needed. The fresh app-of-apps then synced the full child set.

## Verification (A1)
| Probe | Result |
|-------|--------|
| `kubectl get applications -A` deletionTimestamp scan | NONE remain (both wedged CRs deleted) |
| fresh `operations-app-of-apps` | `creationTimestamp 2026-06-22T11:32:48Z`, `Synced / Healthy`, no deletionTimestamp |
| operations child apps (t+3m) | total 21, **Synced 21, Healthy 19**, Missing 0, Progressing 2 (settling) |
| `frontend` / `gateway-nl` / `clientgateway` | all `Synced / Healthy`; pods `1/1 Running` |
| `curl https://operations.dev.vpp.eneco.com/` | **`200`** (was `404`) at t+1m, t+2m, t+3m |

## Rollback note
Finalizer removal is irreversible (it completes a deletion), so there is no "undo" — but recovery was
self-healing forward (ApplicationSet recreated the slot). Pre-fix snapshots retained at
`context/probes/prefix-snapshot/{operations-app-of-apps,assetmonitor}.yaml`.

## Still A3 [blocked] (does not affect resolution)
- Trigger of the original 2026-06-01 12:50 CEST deletion — `az` unauthenticated; not the 14:30 auto-evict (timing). Resolve: `az login` → Logic App `vpp-fbe-autodelete-trigger` run history + ADO pipeline `2629` runs around 2026-06-01.
