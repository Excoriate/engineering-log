---
task_id: 2026-06-15-001
agent: sre-maniac
status: complete
timestamp: 2026-06-15T16:51:42Z
summary: >-
  Operational-call + fix-viability adversarial review of the gurobi-cosmos RU-saturation RCA.
  Net: the "degraded, not broken" call is RISKY (asserted as the headline while solve-success is
  A3-blocked and the burst pinned 100% for 9 min — Mongo 4.0 op timeout is 60s, long enough for
  driver retry exhaustion under sustained 34.5% throttle). T1a (1000->4000) is mechanically SOUND
  and the brief's "single-partition makes 4000 unusable" premise is WRONG: fs.chunks instantMax is
  10000 (1 physical partition CAN serve up to 10k RU/s with no split), so 4000 is well inside
  single-partition capacity. BUT the real wall is the 10k single-partition ceiling: the data never
  showed actual RU *demand* (100% only proves demand>=1000), and if demand exceeds 10k the burst
  needs sharding/Blob (T3), not a bigger autoscale max. T2 429-threshold of 500 is RISKY/mis-tuned
  (set ~= the tolerated-burst count itself -> near-miss / flapping). Backpressure: raising RU with
  no upstream Gurobi concurrency cap can let bigger bursts run and just move the wall. Cost of 4x is
  bounded and not the risk. Required revisions stated per finding.
---

# SRE Maniac — Operational Call & Fix Viability Receipt

## Key Findings

- **degraded_call**: RISKY — headline operational call rests on A3-blocked solve-success; keep T0 a gate, soften L8 wording, keep Sev on the client-impact signal.
- **t1a_4000**: SOUND mechanism, WRONG brief-premise — 4000 < 10000 single-partition ceiling; instantMax=10000 proves no shard needed for 4000.
- **t1a_real_wall**: HIGH — RU *demand* never measured (100% == demand>=1000 only); if demand>10000, single partition is the hard wall and only T3 (shard/Blob) fixes it.
- **backpressure**: no upstream Gurobi concurrency/queue cap named — raising RU may just let bigger bursts run; the real governor is solve concurrency.
- **t2_threshold_500**: RISKY — 500 ~= the 586 tolerated-burst count; near-miss/flapping and prod -p sibling blast radius; derive from rate(%) not absolute count.
- **cost_4x**: LOW — autoscale bills 0.1*max floor + actual; 4x max is bounded, not order-of-magnitude; not the constraint.

Lane: operational call ("degraded, not broken") + fix viability (T1a RU raise, single-partition
mechanics, backpressure, T2 alert tuning, cost). Attacked to break, not confirm.

Load-bearing external facts pulled this session (A1):

- **Maximum RU/s per physical partition (logical & physical) = 10,000.** [A1: MS Learn `concepts-limits` — "Maximum RUs per partition (logical & physical) | 10,000".]
- **The highest RU/s reachable WITHOUT a partition split = `current physical partitions * 10,000 RU/s`**, exposed as `instantMaximumThroughput`. [A1: MS Learn `scaling-provisioned-throughput-best-practices` — "Step 2: Calculate the default maximum throughput … = Current number of physical partitions * 10,000 RU/s".]
- fs.chunks live throughput object: `{ throughput:100, autoscaleMaxRU:1000, minimumRU:1000, instantMax:10000 }`, `shardKey:null`. [A1: RCA E3 / context 04.] `instantMax:10000` ⇒ **fs.chunks currently has exactly ONE physical partition, and that one partition can serve up to 10,000 RU/s with no split.**
- Autoscale scales `0.1*Tmax <= T <= Tmax`; min billable = `0.1*Tmax`. [A1: MS Learn `concepts-limits` autoscale table.]

---

## F1 — "Degraded, not broken" as the headline operational call for a Sev2

**Target:** RCA L8 "Is it broken? Degraded, not down." + summary frontmatter + L12 triage ("Ack, link this RCA").
**Verdict: RISKY** (not WRONG).
**Severity: HIGH** (it is the single sentence an on-call will act on).

**Mechanism.** The call is asserted as the headline while its own evidence chain is A3-blocked:
solve-success during 15:27–15:40 is explicitly "UNVERIFIED[blocked]" (RCA L4:112, T0:35). The
supporting argument is "Mongo driver retries 16500 with backoff, so solves most likely completed
slower" — that is **A2 INFER stacked on an unprobed assumption about driver config**, presented one
line away from a FACT-shaped headline. Two ways it is wrong, both physical:

1. **Retry exhaustion under sustained throttle.** This was not a momentary spike. RU was pinned
   **100% for ~9 of 14 minutes** (E1: 15:32–15:38 all 100) with **34.5% of 47,953 ops throttled**.
   The Mongo 4.0 server-side op timeout is **60 s** [A1: MS Learn `concepts-limits` API-for-MongoDB
   table]. Drivers retry 16500 with backoff, but retries are **bounded** (typical default 3–9
   attempts / a fixed retry window). Under a 9-minute wall of ~1/3 rejection, a large-object GridFS
   read/write that needs many chunk ops can exhaust its retry budget *before* the window clears →
   the solve sees a hard `16500`/timeout, not "slower". That is **failed**, not degraded — and it is
   exactly the case T0 is supposed to catch but the headline pre-empts.
2. **Cascade not traced to the consumer.** The RCA stops at "DB throttled, self-resolved." It never
   traces to: solve abandoned → batch retried by FleetOptimizer → *more* large-object I/O onto the
   same saturated single partition → self-amplifying load. A retry storm on the **client** side
   (Gurobi compute nodes resubmitting failed batches) would extend the burst, not shorten it. The
   RCA has no evidence ruling this out.

**Why RISKY not WRONG:** the degraded reading is *plausible* and may well be correct — but it is
being sold at FACT confidence on A3 evidence, and the failure mode (retry exhaustion → failed
solves) is exactly the high-cost one. An on-call reading "degraded, ack and link RCA" (L12 step 2,
first bullet) may close a real user-impacting solve failure.

**Required change.**
- Demote the headline from "degraded, not down" to **"degraded IF solves completed — solve-success
  is A3-blocked and is the gate."** Move T0 from "do this first" to a **hard close-gate**: the
  incident is NOT closeable as degraded until job history for 15:27–15:40 is read.
- Keep the **client-impact (429) signal at Sev2** (see F5) precisely because the metric cannot tell
  you solves failed; do not let the leading RU% warning be the only page.
- Add one disconfirming probe to T0: check Gurobi compute-node / FleetOptimizer logs for
  batch **resubmission** in the window (rules out the client retry-storm amplification path).

---

## F2 — T1a raises autoscale max 1000→4000 on an unsharded single partition

**Target:** fix.md T1a; brief premise "4000 unusable without sharding; single partition hard ceiling ~10k RU/s, 50GB."
**Verdict: SOUND** (mechanism correct). **The brief's premise is WRONG.**
**Severity: MEDIUM** (correct direction, but oversold as sufficient — see F3).

**Mechanism.** The brief assumed a single physical partition makes a 4000 raise unusable. The
opposite is true and provable from the RCA's own captured evidence:

- A single physical partition can serve **up to 10,000 RU/s** [A1 concepts-limits].
- fs.chunks `instantMax: 10000` (E3) ⇒ it is on **one** physical partition and Azure will let it
  scale to 10,000 RU/s **instantly, with no split, no resharding** [A1 scaling-best-practices Step 2].
- 4000 < 10,000 ⇒ the raise is a pure instant scale-up, fully inside single-partition capacity. The
  RU increase is **usable** as-is. No sharding is required for the 4000 number.

So the bottleneck does **not** move at 4000 — it stays on the same single partition, which is fine
because that partition has 6,000 RU/s of unused ceiling above the new max. The brief's "bottleneck
moves / 4000 unusable" hypothesis is **falsified** by `instantMax:10000`.

**Where the real wall is:** the single-partition wall is **10,000 RU/s** (and 50 GB storage), not
4,000. T1a does not approach it. The genuine risk is not "4000 won't apply" — it is "4000 may not be
*enough*" (F3).

**Required change.** None to T1a's mechanism. Correct any text implying sharding is needed to reach
4000. Add a note: fs.chunks can be raised to **up to 10,000 RU/s on its single partition without a
split**; only demand above 10k forces sharding/Blob.

---

## F3 — Is 4000 enough? RU *demand* was never measured (the actual unknown)

**Target:** fix.md T1a "Start at 4000 (4× headroom)" + T1 acceptance.
**Verdict: RISKY** — 4000 is a guess, not a sized value.
**Severity: HIGH.**

**Mechanism.** `NormalizedRUConsumption = 100%` proves only that demand **≥ 1000 RU/s** — it is
clamped at the ceiling and **cannot show how far above 1000 the true demand was**. The burst could
have wanted 1,500 RU/s or 25,000 RU/s; the pinned-100% metric looks identical in both cases. The RCA
never captured an *uncapped* demand proxy:

- `TotalRequestUnits` (Total, on fs.chunks) over the window = actual RU **consumed** (a floor on
  demand, since throttled ops still cost and rejected ones don't fully count).
- Throttle ratio 34.5% at a 1000 ceiling is a strong hint demand was **well over** 1000 — a
  back-of-envelope: if ~34.5% of ops were rejected while 1000 RU/s was served, true demand is
  plausibly ≥ 1000 / (1 − 0.345) ≈ **1,500–2,000+ RU/s**, and likely higher because rejected ops
  retry and re-queue. This is **ESTIMATED**, not measured — which is the point: nobody measured it.

If true peak demand is, say, 6,000 RU/s, then 4000 still throttles (degraded again, smaller). If it
is > 10,000, **no single-partition autoscale max fixes it** — that is the case where T3 (shard
fs.chunks on `files_id`, or move blobs to Blob Storage) becomes **mandatory, not optional**, because
you hit the 10k hard partition wall.

**Required change.**
- Before committing to 4000, capture **`TotalRequestUnits` (Total) on fs.chunks** for a 100% burst
  to estimate true demand. Size the max to `~1.5× measured peak demand`, capped at the 10k
  single-partition ceiling.
- Make T1 acceptance demand-based, not just "<100% and 429=0": it must state the **measured peak
  RU demand** and confirm `chosen_max > peak_demand`.
- Add an explicit decision branch: **if measured peak demand > ~8,000 RU/s → skip incremental RU
  raises, go straight to T3 (shard or Blob)** because you are within one burst of the 10k wall.

---

## F4 — Backpressure / retry-storm: raising RU with no upstream governor

**Target:** fix.md T1 (raise RU) in isolation; absence of any concurrency cap in RCA/fix.
**Verdict: RISKY.**
**Severity: MEDIUM.**

**Mechanism.** Raising the RU ceiling is a **demand-accommodation** move, not a **demand-control**
move. The true governor of load on fs.chunks is **how many Gurobi solves run concurrently** and how
much large-object I/O each emits — nothing in the RCA names a concurrency cap, queue depth, or
batch-submission rate limit on the FleetOptimizer / Cluster Manager side. Consequences:

- With more RU headroom, a bigger burst simply **runs** instead of being shaped — you have moved the
  wall from 1,000 to 4,000 (or 10,000) RU/s, but the system still has **no backpressure**: there is
  no signal telling FleetOptimizer to slow batch submission when the DB is hot. The next
  marketing/planning-cadence spike that is 5× today's just saturates the new ceiling.
- The client-side retry on 16500 *is itself* uncontrolled backpressure-in-reverse: failed ops
  resubmit, adding load during the exact window the partition is saturated (the F1 amplification
  path). Raising RU reduces the trigger but does not remove the amplifier.

**Required change.** Add to T3 (or a new T2.5): identify whether the Cluster Manager / FleetOptimizer
exposes a **solve concurrency or batch-submission limit**, and cap it to a level the sized RU budget
can serve. State explicitly that **RU raise (T1) without a concurrency cap only moves the wall**; the
durable governor is upstream concurrency + Blob offload (T3), not a bigger autoscale number.

---

## F5 — T2: demote RU alert to Sev3 + 429 threshold = 500

**Target:** fix.md T2 (Sev3 RU warning, new Sev2 429 rule, `threshold = 500`).
**Verdict:** demotion-of-RU-to-Sev3 = **SOUND**; 429 threshold of 500 = **RISKY/mis-tuned**.
**Severity: HIGH** (this is a paging decision with a prod `-p` sibling blast radius).

**Mechanism.**

- **Demote RU% to Sev3 + add a real 429 page: structurally correct.** RU% is a leading
  headroom signal, 429-rate is the client-impact signal; paging on the latter is right (matches MS
  >5% framework, RCA L10). No objection.
- **Threshold = 500 is mis-tuned.** The fix itself notes the 2026-06-15 window had **586** 429s and
  that burst was the **tolerated, self-resolved** one. Setting the page threshold to **500** means
  the page fires at ~85% of a burst the RCA explicitly classifies as *acceptable*. That is a
  **near-miss / flapping threshold**: routine tolerated bursts will sit right at the line, producing
  either constant pages (defeating the demotion) or, if the real burst is only marginally bigger,
  near-zero margin to distinguish "tolerated" from "incident."
- **Absolute count is the wrong unit.** 586 was over a **PT15M-ish** window of **47,953** ops →
  ~1.2% by the count cited, but the *throttle ratio* was 34.5% (16500s). The fix conflates the 586
  backend-429 count with the 16,555 Mongo-16500 count (RCA L7:179 says these are different metric
  layers). A threshold of "500 of TotalRequests StatusCode=429, Total, PT5M" is **not** the >5%
  rate framework it claims to implement — it is an absolute count untethered from op volume. Op
  volume varies by solve cadence, so a fixed 500 is too hot on busy days and too cold on quiet ones.
- **Blast radius — prod `-p` sibling.** The RCA states the same rule class exists in prod (L1:61).
  If 500 is mis-tuned on acc and copied to prod, prod (higher op volume) will breach 500 on routine
  bursts → either chronic prod paging or, if raised reactively, a threshold that **misses a real
  prod throttle** because it was set from acc's smaller profile. A real prod incident can be
  **missed** if prod's tolerated baseline is itself > 500.

**Required change.**
- Express the 429 page as a **ratio**, not a count: `429 count / TotalRequests > ~5%` over PT5M
  (use the metric math expression, or two-series ratio), per the MS framework the fix cites.
- **Backtest against the full 7-day history per environment** (E7 shows multiple 100% bursts/day) to
  find the tolerated-burst 429 ceiling, and set the page **above the 95th percentile of tolerated
  bursts**, not below a known-tolerated one.
- **Tune acc and prod thresholds independently** from each env's own op-volume baseline; never copy
  acc's number to prod.
- Until tuned, keep the **RU% rule at Sev2** as a safety net rather than demoting blind — demote only
  once the 429 page is backtested and proven to catch the 2026-06-15 window at the chosen ratio.

---

## F6 — Cost of 4× autoscale max across collections

**Target:** fix.md T1a "4× headroom" + "review the other 11 collections."
**Verdict: SOUND** (cost concern already correctly bounded by the fix).
**Severity: LOW.**

**Mechanism.** Autoscale bills per hour on `MAX(0.1*Tmax, actual peak that hour)` [A1 concepts-limits].
Raising **max** 1000→4000 does **not** 4× the bill — it 4× the *ceiling* and raises the idle floor
from 100 to 400 RU/s (0.1×4000). Actual cost rises only when a burst actually consumes more.
Order-of-magnitude impact: the idle floor on one collection goes 100→400 RU/s (~+300 RU/s billed
when idle); a fully-consumed burst hour costs up to 4× that hour — bounded and transient, **not**
order-of-magnitude across the account. The fix already guards the genuine cost risk ("don't
blanket-raise all 12 collections; raise only those showing ≥90% under load"), which is the correct
discipline.

**Required change.** None. Optionally note the idle-floor delta (0.1×max) so the team sizes the
floor consciously when picking the max.

---

## Net operational verdict

- **T1a mechanism: SHIP** (correct the "needs sharding" premise — it does not).
- **Sizing of 4000: FIX FIRST** — measure `TotalRequestUnits` demand before committing; add the
  ">8k demand ⇒ go to T3" branch (F3). This is the most important fix.
- **"Degraded, not broken" headline: FIX FIRST** — gate the close on T0 solve-success; do not let
  the leading RU% signal be the only page (F1).
- **T2 429 threshold: FIX FIRST** — ratio not count, per-env backtest, keep RU% at Sev2 until the
  429 page is proven (F5).
- **Backpressure: note as residual** — RU raise without an upstream concurrency cap only moves the
  wall; the durable governor is T3 + concurrency limit (F4).
- **Cost: SHIP** — already bounded.
