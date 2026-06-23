---
task_id: 2026-06-22-005
slug: fbe-404-rca-howtofix
agent: eneco-sre-coordinator
status: complete
timestamp: 2026-06-22T11:25:00Z
summary: A1 evidence ledger from the live read-only §5 probes against Sandbox vpp-aks01-d. Root cause CONFIRMED — operations-app-of-apps + assetmonitor stuck mid-deletion (resources-finalizer wedged since 2026-06-01); Rank-2 cred-gap and Rank-3 PAT-expiry ruled out; 404 is undeployed-frontend (no x-correlation-id).
---

# Probe results — FBE 404 operations (live, read-only, 2026-06-22 ~11:19–11:22 UTC)

Context `vpp-aks01-d` (Sandbox AKS, `rg-vpp-app-sb-401`). Raw outputs in `context/probes/`.
No mutation performed. Tags: **A1** witnessed (cmd+output) · **A2** inferred · **A3** blocked.

## CONFIRMED ROOT CAUSE (A1)

**`operations-app-of-apps` (ns `argocd`) and `operations/assetmonitor` are stuck mid-deletion: the
`resources-finalizer.argocd.argoproj.io` finalizer has not completed since 2026-06-01, 21 days.**

| Fact | Evidence (A1) |
|------|---------------|
| app-of-apps `deletionTimestamp` = `2026-06-01T10:50:12Z`, finalizers `[resources-finalizer.argocd.argoproj.io]`, created `2026-05-27`, `reconciledAt 2026-06-22` | `probes/03-app-of-apps.json` (PROBE 3) |
| `operations/assetmonitor` `deletionTimestamp` = `2026-06-01T10:50:13Z`, same finalizer | PROBE 10 (`-A` deletionTimestamp scan) |
| These are the **only two** Applications cluster-wide carrying a `deletionTimestamp` | PROBE 10 |
| app-of-apps lists ~21 managed child Applications **all `OutOfSync`** (`frontend`, `gateway-nl`, `clientgateway`, `marketinteraction`, `monitor`, `telemetry`, …) | PROBE 3b (`.status.resources`) |
| Of those children, **only `assetmonitor` exists** in ns `operations`; `frontend`/`clientgateway`/`gateway-nl` **do not exist** for operations (every other slot HAS them, Synced/Healthy) | PROBE 2, PROBE 11 |
| ns `operations` is **`Active`**, no deletionTimestamp (so `get ns` does NOT reveal the wedge — the Application CR does) | PROBE 1 |
| `argocd-application-controller-0` `Running 1/1`, age `5d22h` (restarted ~06-16, AFTER the 06-01 deletion) yet finalizer still wedged → a controller restart already happened and did not clear it | PROBE 9 |

### Mechanism (A2, built only on the A1 facts above)
On 2026-06-01 a cascading delete of `operations-app-of-apps` was initiated (both parent + child marked
within 1 s). The `resources-finalizer` was meant to delete managed resources then clear — most children
deleted, but the parent and `assetmonitor` **wedged** and never cleared. Because an object with a
`deletionTimestamp` is being torn down (never reconciled to live desired state), the app-of-apps cannot
re-create the slot's app set. Every later "recreate" — Duncan 06-17 (`1681985`), Stefan 06-18 (`1683302`),
Stefan terminate→recreate 06-19 (`1685434`, Infra 2/4) — was a **no-op**: the wedged CR still owns the
`operations-app-of-apps` name, so no fresh app-of-apps can be created. Result: `frontend` (serves `/`)
never deployed → the public URL 404s. "Build succeeded" only proved the pipeline ran, not that ArgoCD
materialized the slot.

## The 404, concretely (A1)
- `curl https://operations.dev.vpp.eneco.com/` → **`HTTP/1.1 404 Not Found`**, `Content-Type: text/html`, **NO `x-correlation-id` / `Request-Context` header** → 404 from the **edge with no backend** (undeployed), NOT a `PathBase`/ingress-path misalignment. (`probes/06-curl.txt`, PROBE 6)
- Only ingress in ns `operations` is `assetmonitor` → `operations.dev.vpp.eneco.com` (50.85.91.121:80); no `frontend` ingress exists. (PROBE 5)
- `assetmonitor` pods are `0/1` (`ContainerStatusUnknown` / `ContainerCreating`) — itself stuck (it is mid-deletion too). (PROBE 5)

## Ruled OUT (A1)
| Hypothesis | Verdict | Evidence |
|-----------|---------|----------|
| Rank 3 — ApplicationSet PAT expiry | **RULED OUT** | `vpp-feature-branch-environments`: `ErrorOccurred=False`, `ParametersGenerated=True`, `ResourcesUpToDate=True` (PROBE 4a) |
| Rank 2 — per-Application source-N credential gap | **RULED OUT** (for operations) | No operations app shows `ComparisonError … source N of M … authentication required` (PROBE 4b). (`loki` has an unrelated helm-values manifest error; `product-vpp-core`/`rabbitmq-cluster-operator` OutOfSync are not operations-slot.) |
| Routing — `PathBase`/ingress misalignment (activation-mFRR howto) | **RULED OUT** | 404 carries no `x-correlation-id` → edge 404, nothing behind `/` (PROBE 6) |
| Rank 4 — mixed-branch partial render | **secondary artifact** | app-of-apps target `fbe-851436`; assetmonitor on `fbe-806738`. The branch divergence is a side effect of the wedged deletion, not the cause. |

## A3 [blocked] — does not change the root cause
- **Trigger of the 06-01 deletion** — `az` is not logged in (`az account show` → "Please run 'az login'"); could not query the `vpp-fbe-autodelete-trigger` Logic App runs or ADO pipeline `2629`. Timing note: `10:50:12Z` = `12:50 CEST` does **NOT** match the auto-evict schedule (Mon–Fri **14:30** W.Europe) → auto-evict is *unlikely*; consistent with a **manual destroy / pipeline 2629 run on 06-01** but unconfirmed. Resolve: `az login` → `az logic workflow run list -n vpp-fbe-autodelete-trigger -g rg-vpp-app-sb-401` + ADO 2629 run history around 2026-06-01.
- **Per-test breakdown of build `1685434`'s 2/4 infra failures** — `az` blocked. The *2/4 failed* fact itself is A1 (Slack bot card, prior task). Resolve: `az pipelines build show --id 1685434` + Timeline.

## Fix implication (feeds how-to-fix)
Controller is healthy and already restarted once without clearing the finalizer ⇒ the corrective action is
**force-remove `resources-finalizer.argocd.argoproj.io` from both `operations-app-of-apps` (argocd) and
`assetmonitor` (operations)** so the 21-day-pending deletion completes — the vault's destructive-cleanup
gate is satisfied (managed workloads already gone; only the two wedged CRs remain) — **then re-create the
slot** (create pipeline `2412` on the intended branch) so a fresh app-of-apps deploys the full app set
(`frontend`, gateways, …) → URL serves `200`. Do NOT use destroy pipeline `2629` (not a rollback).
