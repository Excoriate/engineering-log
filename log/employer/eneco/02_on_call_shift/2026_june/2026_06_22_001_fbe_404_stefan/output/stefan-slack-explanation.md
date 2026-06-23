<!--
Slack-ready explanation for Stefan / #myriad-platform. Plain language, no internal
evidence codes, code-format identifiers. Paste the "Slack message" block; the
"If anyone asks why" block is optional background. All facts are live-verified
(probes + fix run 2026-06-22 against Sandbox vpp-aks01-d).
-->

# Slack explanation — FBE 404 operations (resolved)

## TL;DR (one line)
`operations` FBE is back (`200`); its ArgoCD app-of-apps had been stuck mid-deletion since June 1 (a wedged finalizer), so the slot never re-deployed — clearing the finalizer let it self-heal.

## Slack message (paste-ready)

> <@stefan.klopf> The `operations` FBE is back up — https://operations.dev.vpp.eneco.com/ returns `200` again and all 21 apps are Synced/Healthy.
>
> **What was wrong:** the slot's ArgoCD `operations-app-of-apps` had been stuck *mid-deletion* since **June 1** — a leftover delete that never finished, because the ArgoCD `resources-finalizer` on it was wedged. While an app-of-apps sits in that `Deleting` state, ArgoCD won't deploy the slot, so `frontend` + the gateways were never (re)created and `/` 404'd. The green create build was a red herring — a green FBE build only means the pipeline ran, **not** that ArgoCD actually deployed the slot.
>
> **Why the recreates didn't help:** every recreate (incl. yours on the 19th) was effectively a no-op — the half-deleted app-of-apps still **occupied the name**, so a fresh one couldn't be created on top of it.
>
> **What I did:** cleared the stuck finalizer on the wedged `operations-app-of-apps` and its leftover `assetmonitor`. That let the old objects finish deleting, and the ApplicationSet immediately recreated a fresh app-of-apps that deployed the full app set. URL was back to `200` within a minute.
>
> **One open item:** I couldn't confirm *what* triggered the original June-1 deletion — `az` wasn't logged in to check the pipeline / auto-delete Logic App history, and the timing (12:50) doesn't match the 14:30 auto-evict. If `operations` breaks the same way again, that's the thread to pull.

## If anyone asks "why did this happen" (background)

The FBE platform runs each slot as an ArgoCD **app-of-apps**: an ApplicationSet generates one parent Application per slot, and that parent deploys ~21 child apps (`frontend`, gateways, dispatchers, …). When a slot is deleted, ArgoCD's `resources-finalizer` is supposed to delete the children first, then let the parent go. On `operations`, that finalizer **wedged on June 1 and never completed** — so the parent sat with a `deletionTimestamp` for 21 days, ArgoCD treated the slot as "being torn down," and nothing re-deployed. The ApplicationSet still *wanted* `operations` to exist (it owns it and still targets it), but it couldn't recreate the parent while the wedged one held the name. Clearing the finalizer broke that deadlock and the platform healed itself.

## For next on-call (5-second recognition)

FBE URL 404s but the create build is green → check the slot's app-of-apps for a stuck deletion:

```bash
kubectl --context vpp-aks01-d -n argocd get application <slot>-app-of-apps \
  -o jsonpath='{.metadata.deletionTimestamp}{"\n"}{.metadata.finalizers}'
```

A non-empty `deletionTimestamp` + a lingering `resources-finalizer` = this same wedged-deletion class. The fix is to clear the finalizer (after confirming the slot's workloads are already gone) and let the ApplicationSet recreate it. **Do not** reach for the destroy pipeline (`2629`) — it is not a rollback.
