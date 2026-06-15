---
title: "Fix spec — gurobi-cosmos-normalized-ru-consumption (RU micro-burst / alert calibration)"
description: "Implementable, tiered remediation spec for the fs.chunks RU micro-burst on cosmosdb-gurobi-platform-a"
timestamp: 2026-06-15T17:45:00Z
status: complete
category: on-call-fix
authors: ["Alex Torres Ruiz (with Claude Code)"]
task_id: 2026-06-15-001
agent: coordinator
summary: >-
  Tiered fix, priority-ordered after the 2.82%-429 finding: T0 verify solve success (read-only gate);
  T2 (PRIMARY) re-calibrate the alert — add a 429-RATE page (>5%, per-env backtested; today's 2.82%
  would NOT fire) and demote the NormalizedRU>75 gauge to Sev3 + fix its stale "5 minutes" description;
  T1 (secondary) raise fs.chunks autoscale max 1000->4000 (single partition serves up to 10k, no shard
  needed; size from measured demand) + bring throughput into IaC; T3 (candidate, feasibility-blocked)
  offload GridFS to Blob or shard. Plus a backpressure note: RU raise without an upstream Gurobi
  concurrency cap only moves the wall.
---

# Fix Spec — Gurobi Cosmos RU Micro-burst / Alert Calibration

> **Scope of authority.** Every change is a **recommendation with an explicit authorization gate** — none applied. Acc/prod infra + alert changes need the owning team's sign-off (Gurobi platform / FleetOptimizer; escalation owner **Nuno**, fallback **#team-platform**). Evidence: [`rca.md`](./rca.md) + [`../context/04-live-azure-evidence.md`](../context/04-live-azure-evidence.md). Constants: `SUB=b524d084-edf5-449d-8e92-999ebbaf485e`, `RG=rg-gurobi-platform-a`, `ACC=cosmosdb-gurobi-platform-a`, `DB=grb_rsm`.

## Decision summary

Spiky Gurobi batch I/O hit `fs.chunks`'s **1000 RU/s** ceiling in brief sub-minute spikes → **586 HTTP-429 = 2.82% of requests (within Microsoft's 1–5% healthy band)** → PT15M NormalizedRU avg 77.67% tripped the team's **conservative leading >75% gauge**, then self-resolved. **The primary problem is alert *calibration*, not urgent capacity** (Microsoft's own >5% action threshold was *not* crossed). Fix the **alert semantics first**, capacity second, storage pattern as a durable candidate.

---

## T0 — Triage / verify (do first; read-only; no gate)

Confirm the one residual unknown: **did any optimization actually fail, or just slow down?**

1. Alert is resolved (auto-mitigated) — confirm in Rootly E89PYM.
2. **Inspect Gurobi job/batch history for 15:27–15:40Z** (Cluster Manager Web UI / REST, or the `jobhistory` collection): did batches complete, retry, or error? **Also check for batch *resubmission*** (a client retry-storm would extend the burst).
   - Completed/retried → degraded-only (the favored outcome given 2.82% + brief spikes) → proceed T2/T1.
   - Errored/abandoned → user-impacting → raise priority, escalate to Nuno.
3. **Acceptance:** a written yes/no on "solves in the window succeeded." Until then the operational call is "degraded (A2); solve-success A3-blocked."

---

## T2 — Re-calibrate the alert (PRIMARY; days; LOW risk; pure IaC; reversible)

**Why this is first:** the rule pages at **Sev2** on a **leading headroom gauge** (NormalizedRU>75% avg) and there is **no tuned client-impact signal**, so it fires on spiky micro-bursts whose real 429 rate (2.82%) is **inside Microsoft's healthy band**. Pages should track real client impact.

**Steelman first (so this isn't rejected as "undo what we just did"):** the team deliberately replaced a chronically-noisy 429-**count** alert (their comment: routine "1 or 2" 429s, threshold raised to 20 to suppress) with a leading gauge — a canon-aligned move. The gap is *not* that the gauge exists; it's the **absence of any tuned client-impact signal**. So re-add a **429-RATE** page tuned **above** the routine-burst floor — do **not** reintroduce the old count alarm (which would fire on 586 again and re-create the noise they removed).

Edit `gurobi-infrastructure/src/locals.tf` `default_cosmosdb_metric_alerts`:

```hcl
# (1) DEMOTE the leading RU gauge to Sev3 (warning) + FIX the stale description.
gurobi-cosmos-normalized-ru-consumption = {
  description = "WARNING (leading gauge): normalized RU consumption averaged >75% over PT15M — RU headroom is tight; confirm client impact via the 429-rate alert before acting."
  severity    = 3            # was 2  -- only after the 429-rate page below is proven (keep at 2 until then)
  window_size = "PT15M"      # description no longer claims "5 minutes" (was stale vs the PT15M window)
  # ...criteria unchanged (NormalizedRUConsumption > 75, Average)...
}

# (2) ADD a CLIENT-IMPACT page on HTTP-429. Full provider-validated HCL is in
#     spec-pr1-gurobi-infrastructure-alert-calibration.md (validated vs azurerm v4 / repo pin 4.41.0).
# RECOMMENDED (spec Option A): a dynamic-threshold azurerm_monitor_metric_alert on TotalRequests
#   filtered StatusCode=429 — the BACKEND layer (the 2.82% world); learns the routine Gurobi-burst
#   baseline; fires on anomalous spikes; no Log Analytics dependency.
# NOTE on a "true %": you CANNOT divide two metrics in a static metric alert. A log alert on the Mongo
#   logs (CDBMongoRequests, ErrorCode in ("429","16500")) DOES yield a %, but it measures the
#   PROTOCOL / retry-inflated layer (~34.5% on 2026-06-15, NOT 2.82%) — so it must NOT be wired to a
#   ">5%" page; it is a diagnostics aid only. Microsoft's 1-5%/>5% framework is defined on the BACKEND
#   429 rate (TotalRequests StatusCode=429 / TotalRequests), which is a triage computation, not a
#   single alert rule.
# Backtest MUST show: 2026-06-15 (backend 2.82%) does NOT page; a genuinely anomalous 429 spike DOES.
```

- **Threshold derivation (do not assert a number):** the 2026-06-15 burst was **586 backend HTTP-429 / 20,792 requests = 2.82%** — *tolerated*, inside Microsoft's 1–5% healthy band. A fixed **count** threshold (e.g. 500) is **wrong** — it fires on this tolerated burst. **Prefer the dynamic-threshold metric alert** (spec Option A): it learns the per-env routine baseline, needs no hand-set number, and avoids the acc↔prod copy hazard. If a fixed number is mandated, set it **per-environment** well above each env's routine-burst 429 count, backtested against the 7-day history (never copy acc's number to prod).
- **Sequencing (per reliability review):** keep the RU gauge at **Sev2** until the 429-rate page is implemented and backtested to catch a real >5% burst; only then demote the gauge to Sev3. Don't remove the only page before the replacement is proven.
- **Rollback:** revert the locals change (git).

**Acceptance (T2):** backtest both rules vs E7's 7-day bursts — the Sev2 429-rate rule fires only >5% (not on 2026-06-15's 2.82%); the Sev3 gauge fires informationally; severities/routing verified in a non-prod apply.

---

## T1 — Raise the ceiling (secondary; days; LOW risk; reversible)

**Why secondary:** at 2.82% 429 (healthy band) this is **not urgent** — it's noise-reduction + headroom, not an outage fix. Microsoft's ">5% ⇒ increase throughput" trigger was **not** crossed.

### T1a — Raise autoscale max (corrected mechanics)

```bash
# AUTH GATE: acc SP + change approval. Reversible (--max-throughput 1000 to roll back).
az cosmosdb mongodb collection throughput update \
  --account-name "$ACC" -g "$RG" --database-name "$DB" --name "fs.chunks" \
  --max-throughput 4000 --subscription "$SUB"
```

- **Single-partition mechanics (corrected + source-verified):** `fs.chunks` is one physical partition (~5 GB, `instantMax:10000`). A single physical partition serves **up to 10,000 RU/s with no split** — so **4000 needs no sharding** and applies instantly. (The earlier "needs sharding" worry was wrong.) Only demand **>10,000 RU/s** forces sharding/Blob (T3). *(Validated against Microsoft Learn — Cosmos "Partitioning and horizontal scaling": each physical partition provides up to 10,000 RU/s and 50 GB; an **unsharded** Mongo collection is a single partition capped at 10,000 RU/s and 20 GB, and "splitting a hot partition with a single hot partition key doesn't improve performance … max RU/s is still 10,000" — so beyond 10k the only options are a real shard key or moving the blobs out, i.e. T3.)*
- **Size from measured demand, don't guess 4000 blindly:** observed peak served was **~3,292 RU/min (≈55 RU/s avg)** with sub-second spikes past 1000 RU/s (`TotalRequestUnits`, E12). Before committing, capture `TotalRequestUnits` over a fresh 100% burst to estimate the spike rate; set max ≈ **1.5× peak demand**, capped at 10,000. If a future measurement shows peak demand **>8,000 RU/s**, skip incremental raises and go to T3.
- **Don't blanket-raise all 12 collections** — only `fs.chunks` is hot (others ≤16%, E11). Raising one collection's max 1000→4000 raises only its idle floor 100→400 RU/s; cost is bounded, not order-of-magnitude.
- **Rollback caveat (validated against the `az` CLI reference):** `az cosmosdb mongodb collection throughput update --max-throughput` documents a **minimum accepted value of 4000 RU/s**. The collection is currently at autoscale max **1000** (set before this constraint or via the portal), so raising to **4000 is valid (it is the CLI's stated minimum)**, but rolling **back to 1000 via this CLI command may be rejected** — if a full rollback to 1000 is required, use the Azure portal, or accept a higher floor. Confirm the achievable range at apply time (`--help` / a dry attempt).

### T1b — Bring throughput under governance

Throughput is **not** in IaC (collections are app-created). Options (pick with the platform team): **(A, recommended)** keep app-managed but record intended per-collection max in `gurobi-infrastructure` + add a drift check to the quarterly throughput/alert audit (extends LL-012); **(B)** full IaC import as `azurerm_cosmosdb_mongo_collection { autoscale_settings { max_throughput } }` — **only if** the Cluster Manager app does not recreate/alter the collection (TF↔app conflict risk; verify ownership first).

**Acceptance (T1):** a comparable burst keeps NormalizedRU Max <100% and 429 count → 0; chosen max > measured peak demand.

---

## T2.5 — Backpressure (note; the durable governor)

Raising RU is **demand-accommodation**, not **demand-control**. The true governor of `fs.chunks` load is **how many Gurobi solves run concurrently** and how much GridFS I/O each emits. Nothing in the IaC names a solve-concurrency or batch-submission cap. **An RU raise without an upstream concurrency cap only moves the wall** (a 5× burst saturates 4000 too). Action: with the Gurobi platform/FTO team, identify whether the Cluster Manager exposes a solve-concurrency / batch-submission limit and cap it to what the sized RU budget can serve. The durable governor is upstream concurrency + Blob offload (T3), not a bigger autoscale number.

---

## T3 — Durable candidate (feasibility-BLOCKED, A3)

**Why a candidate, not a committed fix:** the Cosmos DB is owned + schema-managed by the **commercial third-party Gurobi Cluster Manager**, not Eneco code (it uses only the connection-string secret). **Whether Gurobi Remote Services can redirect its large-object store to Azure Blob is UNVERIFIED**; whether it tolerates a user sharding `fs.chunks` is likewise unverified (and conflicts with "don't touch app-managed collections"). So:

- **Spec (if feasible):** store input models/solutions in **Blob Storage**, keep metadata + a blob reference in Cosmos — decouples large-object I/O from the RU budget.
- **Resolving path (A3):** read Gurobi Remote Services storage-config docs OR ask the Gurobi platform/FTO team whether the large-object store is repointable / whether `fs.chunks` may be sharded. **Do not present Blob-offload as "the fix" until this is confirmed** — until then, T1 (raise ceiling) is the *available* fix and T3 is aspirational.

**Acceptance (T3):** if pursued and feasible — `fs.chunks` RU/s + `DataUsage` drop; NormalizedRU bursts no longer reach 100%; solve latency unchanged.

---

## Production caveat

The prod `-p` sibling is the **same structural class** (IaC `cosmos_db_config` byte-identical acc vs prod), but prod's **live** throughput was **not probed this session** — prod may already be portal-provisioned higher, and prod runs 2 token servers vs acc's 1 (different load). **Verify prod `fs.chunks` live throughput + 429 rate before assuming prod shares acc's 1000 RU/s ceiling.** [A2 + A3]

---

## What NOT to do

- **Don't blind-ack as "noise"** — it's a real (if minor) recurring throttle with a calibration fix outstanding; and solve-success is still A3 (run T0).
- **Don't set the 429 page as an absolute count (e.g. 500)** — it'd fire on the tolerated 2.82% burst (586). Use a **rate ≥5%**, per-env backtested.
- **Don't blind-raise the RU>75% threshold** (e.g. 75→90) as "the fix" — that hides worsening burst behavior; alert tuning changes *who's paged*, not the ceiling.
- **Don't full-IaC-import or shard collections** the Cluster Manager actively manages without confirming the app tolerates it.
- **Don't copy acc alert thresholds to prod** — tune per-env from each env's own op-volume baseline.
