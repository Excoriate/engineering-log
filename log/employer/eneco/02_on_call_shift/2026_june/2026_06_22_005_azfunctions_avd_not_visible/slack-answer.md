---
task_id: 2026-06-22-009
agent: claude-opus-4-8
status: complete
summary: "Slack reply for Johnson + Anasthasia — confirmed root cause (prefix-mounted ingress, no rewrite), immediate port-forward unblock, and the permanent chart PR; fix proven live."
---

# Slack reply (for `#myriad-platform`)

> Tier: 100% confidence — root cause confirmed and the fix proven live. Committed answer.

---

Hi @Johnson @Anasthasia — confirmed root cause, this is the same issue as the 2026-06-02 one and the fix from then was never merged.

`telemetryfunctiontestsfn` is healthy; the problem is purely edge routing. Its nginx ingress mounts it under the prefix `/telemetryfunctiontestsfn/` but doesn't strip that prefix, so the backend (which serves health at `/healthz`, at the root) gets `/telemetryfunctiontestsfn/healthz` and returns `404`. `…/api/siteregistry` works only because it's mounted at `/`. It is **not** a network/AVD/whitelist issue — the host is public and the connection succeeds (clean 404, not a timeout/403).

**Unblock right now** (needs `kubectl` to `vpp-aks01-d`, which AVD has):
```
kubectl -n vpp-agg port-forward svc/telemetryfunctiontestsfn 8080:8080
curl http://localhost:8080/healthz      # -> 200 Healthy
```
Point your e2e harness at `http://localhost:8080` if it takes a base URL.

**Permanent fix** (the real one): a small **two-file** change in `Eneco.Vpp.Aggregation` — in `…/Helm/telemetryfunctiontestsfn/values.yaml` add `nginx.ingress.kubernetes.io/use-regex:"true"` + `rewrite-target:/$2` and make the path `/telemetryfunctiontestsfn(/|$)(.*)`, AND in `…/templates/ingress.yaml` change `pathType: Prefix` → `ImplementationSpecific` (required — nginx rejects a regex path under `Prefix`; I confirmed both live today). I proved the rewrite live (a throwaway test ingress returned `200` through the public edge, then I removed it). Heads-up: the canonical chart on `development` still has no rewrite, so the 2026-06-02 fix was never merged. Same change applies to `deliveryreportfn` (its liveness is `…/deliveryreportfn/`, not `/healthz` — that backend has no `/healthz` route). After it's merged **and deployed**, `…/telemetryfunctiontestsfn/healthz` → `200`. Full RCA + how-to-fix attached.

Note: this only restores `/healthz` (the `*fn` are timer/Kafka-triggered, not HTTP-invoked — there are no `/api/<fn>` endpoints on that host). Happy to raise the PR if someone on Aggregation owns the merge.
