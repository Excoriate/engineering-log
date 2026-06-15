---
title: "How-to (Feynman) — diagnosing the Gurobi Cosmos RU alert from first principles"
description: "Teaching walkthrough so you can understand and independently replicate the diagnosis"
timestamp: 2026-06-15T17:45:00Z
status: complete
category: how-to-feynman
authors: ["Alex Torres Ruiz (with Claude Code)"]
task_id: 2026-06-15-001
agent: coordinator
summary: >-
  First-principles teaching doc for the gurobi-cosmos-normalized-ru-consumption alert: what RU and
  NormalizedRUConsumption really are (per-partition MAX), why a 77.67% average is neither reassuring nor
  alarming on its own, the under-read/over-read trap and the metric that ends the argument (the HTTP-429
  RATE = 2.82%, within Microsoft's healthy band), the step-by-step investigation with the WHY, the
  "aha" moments (rate-not-count, micro-burst-not-sustained, sensor-vs-system, stale-clone reversal),
  a replication decision tree, and self-tests.
---

# How I diagnosed it — and how you can, alone, next time

**Knowledge contract.** After this you should be able to, *without help*: (1) explain what `NormalizedRUConsumption` measures and why 77.67% is neither reassuring nor alarming by itself; (2) name the *one* metric that ends the noise-vs-real argument and compute it; (3) run the 6-probe sequence that turns the alert into a verdict; (4) avoid the three traps that produced two *wrong* intermediate conclusions before the right one. If you can't, this doc failed — tell me where.

---

## 1. First principles (build the model before any command)

**Cosmos bills in Request Units (RU/s).** Every op costs RU; you provision a budget per second. Exceed it and Cosmos **rejects** the excess with HTTP **429** (Mongo surfaces it as error **16500**). The client backs off and retries. [A1: Microsoft Learn.]

**`NormalizedRUConsumption` is the subtle part.** It is *not* "average fullness." It is:

> the **MAX**, across all physical partitions, of (RU consumed ÷ RU provisioned), per 1-minute interval, 0–100%.

Two consequences that break naive intuition [A1: MS Learn]:

- **100% ≠ guaranteed throttling** — it's the *busiest* partition in that minute; and a per-minute Max of 100% can be a *single-second spike*, not a full minute at the ceiling.
- **<100% ≠ safe** — one hot partition can throttle while the account number looks moderate.

So the metric is a **utilization gauge**, not an **impact** measure. The alert here fires on the **PT15M average** of those per-minute maxes being **>75%**. "77.67%" therefore means: *over 15 minutes, the worst-partition-each-minute averaged 77.67%* — which can be a few brief 100% spikes dragging up an otherwise-low average. **You cannot tell impact from this number.** Only the **429 rate** can.

---

## 2. What this system is (so the numbers mean something)

VPP optimises energy-asset dispatch for TenneT markets. **FleetOptimizer** builds a math model; **Gurobi** (a solver) solves it. The Gurobi platform's **Cluster Manager** stores **input models, solutions, and 30-day job history** in this Cosmos DB [A1: Gurobi docs]. Big models/solutions go through **GridFS** → split into binary chunks in the **`fs.chunks`** collection (its `{files_id,n}` index is the GridFS fingerprint). Solves arrive in **bursts** → short, write-heavy spikes on `fs.chunks`. Hold this; it predicts what we find.

---

## 3. The trap — I was wrong *twice* before I was right (this is the real lesson)

Watch my read swing, because each swing is a trap you'll meet:

- **Read #1 (under-read):** "77.67%, barely over 75, *averaged* → probably noise." Tempting, lazy, and **not yet evidence**.
- **Read #2 (over-read):** I pulled the throttle counters and saw **586 HTTP-429 + ~16,555 Mongo-16500** and a "34.5% of ops" figure. "It's a *severe* throttle, ~1/3 of ops!" That felt rigorous — and was **also wrong**, because 16,555 is the **Mongo-protocol count inflated by driver retries** (a rejected op retries up to ~9×, each emitting another 16500). I'd grabbed a real number and divided by the wrong denominator.
- **Read #3 (right):** compute the metric **Microsoft's own action framework uses** — the **HTTP-429 *rate***: `429 ÷ TotalRequests = 586 ÷ 20,792 = ` **2.82%**. Microsoft says **1–5% 429 with acceptable latency is healthy, no action**. So this is **real but minor** throttling — a spiky micro-burst that tripped a *conservative leading gauge*, not an outage.

> **The discipline:** *don't trust a utilization gauge for impact, and don't trust a raw rejection count either — compute the **rate** with the right denominator.* The 429 rate is observable, discriminating, and the exact figure Microsoft's threshold is defined on. It ended the argument that both my instincts got wrong.

And the burst *shape* confirmed "minor": `TotalRequestUnits` showed the hot minutes served only **~3,292 RU/min ≈ 55 RU/s on average** — i.e. the 100% readings were **brief sub-second spikes**, not a sustained 9-minute wall.

---

## 4. The investigation, step by step — with the WHY

Each probe was chosen to *flip a decision*, not to collect data.

| # | Probe | WHY (decision it flips) | Found |
|---|-------|-------------------------|-------|
| 1 | Read the alert payload | Pin scope: resource, metric, threshold, env, aggregation. | Account-level NormalizedRU>75% avg/PT15M, acc, autoMitigate. |
| 2 | `NormalizedRU` Max+Avg per minute | Flat graze or spike-average? | Per-minute Max 100% in ~9 min. |
| 3 | **`TotalRequests` 429 ÷ total = RATE** | *The* pivot — real client impact? | **2.82%** → within Microsoft's healthy band. |
| 3b | `TotalRequestUnits`/min on the collection | Sustained or micro-burst? | ~3,292 RU/min peak (≈55 RU/s avg) → **micro-burst**. |
| 4 | Split NormalizedRU by `CollectionName` | Which collection? (fix targets it) | **`fs.chunks`** 100% vs next 16%. |
| 5 | `collection throughput show` | Under-provisioned? autoscale? | autoscale **max 1000 RU/s**, ~5 GB, single partition. |
| 6 | `alert show` + `list` + fired-instances + `git log` | Who owns it? what changed? | Team IaC alert; **429 alert was removed**; no config change (just the sensor). |

Order matters: 3+3b is the noise-vs-real-vs-minor fork; 4→6 turns "minor throttle" into "where, and why the page."

---

## 5. The "aha" moments (the transferable insight)

1. **Rate, not count.** 16,555 Mongo-16500 events (retry-inflated) screamed "severe"; 586 ÷ 20,792 = **2.82%** said "healthy band." Same incident, opposite verdicts — the **rate with the right denominator** is the truth.
2. **Micro-burst, not sustained.** Per-minute *Max* = 100% looked like a 9-minute wall; `TotalRequestUnits` (~55 RU/s avg) revealed brief sub-second spikes. Average-of-maxes hides shape.
3. **Sensor vs system ("it was not broken before").** Nothing in the DB changed (activity log empty). The **alert** changed — the team swapped a lagging 429 alarm for a leading RU>75% gauge. "Not broken before" = "didn't *page* before."
4. **Stale-clone reversal.** My first IaC read (a Jan-27 clone, *before* the redesign) said "this alert isn't in code." After `git pull`: it's **team-authored IaC, deliberately built.** Pull before trusting an IaC negative.

---

## 6. The mechanism, in one picture

```text
FleetOptimizer fires a batch of solves (bursty)
        │  brief, write-heavy GridFS chunk I/O
        ▼
  fs.chunks  ── single partition (~5 GB), autoscale max 1000 RU/s
        │  sub-second demand spikes  >  1000 RU/s
        ▼
  Cosmos rejects the excess → 586 HTTP-429  =  2.82% of requests  (Microsoft "healthy" 1–5%)
        │  per-minute NormalizedRU Max = 100% in ~9 brief spikes (RU served ≈ 55/s avg)
        ▼
  PT15M average of those maxes = 77.67%  >  75% → leading gauge fires (Sev2)
        ▼
  burst ends → autoMitigate → alert resolves itself (~15 min)
```

So the fix order is: **calibrate the alert first** (page on the 429 *rate* >5%, warn on RU%), then **raise the ceiling** (reduce spikes + noise), then maybe **move GridFS blobs off Cosmos** (durable, if the third-party app allows). See [`fix.md`](./fix.md).

---

## 7. Replicate it yourself — the decision tree

```text
Alert: gurobi-cosmos-normalized-ru-consumption fires
   │
   ├─ 1. Resolved already? (autoMitigate) ── single short fire = low urgency
   │
   ├─ 2. Compute the 429 RATE = (TotalRequests StatusCode=429) ÷ (TotalRequests all) for the window
   │        │
   │        ├─ rate ≤ ~5% AND self-resolved ─→ within Microsoft's healthy band → ACK + link the RCA
   │        └─ rate > 5% OR sustained across windows OR solves failing ─→ ESCALATE to Nuno
   │        (⚠ do NOT use the Mongo-16500 count or NormalizedRU% as the impact figure — both overstate)
   │
   ├─ 3. Split by CollectionName → expect fs.chunks; if different, partition design changed → dig
   │
   └─ 4. Check Gurobi job history for the window → did solves complete? (the metric can't tell you)
```

Exact commands: [`rca.md`](./rca.md) §L11. ~6 `az` calls and one `git log`.

---

## 8. Meta-lessons (carry these to the next incident)

- **Utilization ≠ impact; count ≠ rate.** Confirm a saturation alert with the **429 rate** (right denominator), not the gauge and not the raw rejection count.
- **Average hides shape.** A PT15M average of per-minute maxes can be brief micro-bursts — pull the per-minute series *and* `TotalRequestUnits`.
- **Pull before you trust an IaC negative.** "Not in code" from a stale clone is not evidence.
- **Separate sensor from system.** "It broke" might mean "we started watching."
- **Name the fix tier and order it by evidence.** When impact is in the healthy band, alert *calibration* outranks capacity spend.

---

## 9. Self-test (if you can't answer, re-read the marked section)

1. The account shows 60% NormalizedRU and a partition is throwing 429s. How? (§1)
2. Two engineers compute "throttle %": one gets 34.5%, one gets 2.82%. Both used real numbers. Who's right and why? (§3, §5.1)
3. Per-minute Max = 100% for 9 minutes. How do you tell a 9-minute wall from brief spikes? (§3, §5.2)
4. Which single number decides ack-vs-escalate, and what's its denominator? (§3, §7)
5. Why is re-calibrating the alert the *first* fix here, ahead of buying more RU? (§6, `fix.md` T2)
