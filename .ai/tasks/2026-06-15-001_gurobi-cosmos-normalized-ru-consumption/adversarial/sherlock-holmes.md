---
task_id: 2026-06-15-001
agent: sherlock-holmes
status: complete
summary: "fs.chunks-as-cause is unproven (per-collection probe never captured); 34.5% throttle figure is retry-inflated; depth-1 should be Hypothesis Set pending a CollectionName-split discriminator probe."
timestamp: 2026-06-15T16:52:16Z
---

# Adversarial Receipt — Causal Chain & Uneliminated Alternatives

**Reviewer lane:** causal chain + uneliminated alternatives (mechanism attack). NOT fix-design (sre-maniac), NOT claim-breaking-generic (el-demoledor), NOT goal-fidelity (socrates).

**Net verdict:** The RCA's *capacity-saturation* class is sound, but the **specific identification of `fs.chunks` as THE saturated collection is an INFER dressed as A1**, and the **34.5% throttle metric is inflated by driver-retry amplification**. Depth-1 as written overstates evidence. Two findings require RCA changes (one downgrade, one discriminator probe, one figure correction).

---

## F1 — "`fs.chunks` is the saturated collection" — the per-collection probe was NEVER captured

**Claim attacked:** Depth-1 (rca.md:187): *"a sustained Gurobi batch burst drove unsharded `fs.chunks` to its 1000 RU/s autoscale ceiling … [A1]."* L11 command #3 (rca.md:251-253) is presented as the probe that identifies the hot collection; L12:282 says "expect `fs.chunks`."

**Verdict: WEAKENED (→ borderline FALSE as an A1).**

**Severity: HIGH** (it is the proximate cause; if wrong, T1's "raise `fs.chunks` 1000→4000" targets the wrong collection).

**Evidence (mechanism, not category):**

1. **The CollectionName-split output is physically absent from the evidence file.** `grep -ni "collectionname"` on `context/04-live-azure-evidence.md` returns *"NO per-collection NormalizedRU split captured"*; command #3's output appears nowhere. The user-prompt's premise that "the split returned only fs.chunks" is **not backed by the captured evidence** — that probe result was never recorded. (A1: grep of evidence file this session.)
2. **What E1 actually shows is account-level, and "Max≡Avg ⇒ single series ⇒ fs.chunks" is a non-sequitur.** Microsoft Learn (monitor-normalized-request-units, fetched this session, A1): NormalizedRUConsumption is *"the **maximum** RU/s utilization across **all partition key ranges**."* Each of the 12 collections has its OWN dedicated throughput (E3:45 — all 12 at autoscaleMax 1000), so each is its own set of partition-key-ranges. The account series in E1 is therefore **MAX across all 12 collections**. `Max≡Avg` per minute proves only that *one* partition-key-range dominates each minute — it does **not** name which collection. fs.chunks being unsharded makes it a *plausible* dominant, but the metric cannot distinguish "fs.chunks at 100%" from "objects (also GridFS-adjacent, also potentially hot) at 100%" without the split.
3. **A co-saturator is not eliminated.** `objects`, `fs.files`, `batches`, `jobhistory` all carry burst-correlated large-object I/O and all share the same 1000-RU ceiling (E3:45). fix.md:53 *itself* concedes "objects, batches, jobhistory may co-burst." The RCA simultaneously asserts fs.chunks is THE cause (A1) and that others may co-burst (unmeasured) — internally inconsistent.

**Why the RCA's own labels are wrong here:** rca.md:98 cites this as `[A1: collection list]` + `[A1: collection show]`. Those A1 probes prove fs.chunks *exists and is unsharded* — they do **not** prove it *carried the saturating load on 2026-06-15*. The latter is the GridFS burst narrative (rca.md:110, explicitly self-labeled A2 INFER). The depth-1 sentence promotes that A2 to A1.

**Required change:**
- Downgrade depth-1's "fs.chunks" identification from A1 to **A2 INFER**, OR
- Add the **discriminator probe** (and capture its output): re-run command #3 but with **aggregation Maximum at PT1M** (not PT5M — PT5M smoothing can hide a collection that peaks in a different minute) split by `CollectionName`, over 15:27–15:40Z. Expected if H1 true: fs.chunks ≥ all others. **Falsifier: any non-fs.chunks collection ≥90% in the window → the cause is broader and T1's single-collection raise is wrong.**

---

## F2 — "NOT a regression" — only config-writes were tested; workload growth is uneliminated

**Claim attacked:** rca.md:191 / Lesson 5 (rca.md:221) / E9 (evidence:83): *"no throughput change since 05-15; the sensor changed, not the system … no capacity regression."*

**Verdict: WEAKENED.**

**Severity: MEDIUM** (does not break the capacity fix, but a *growth* regression would change urgency from "chronic, tolerated" to "worsening trend → escalate now").

**Evidence:**

1. **The activity log (E9) only rules out one of two regression mechanisms.** An empty `az monitor activity-log` proves no *control-plane write* (throughput/account change). It is **silent on demand-side regression**: more solves, or larger models per solve, raise RU draw with zero activity-log entries. The RCA treats "activity log empty" as sufficient for "not a regression" — it covers supply-side only.
2. **There IS a positive signal of worsening that the RCA does not engage.** Precedent note (02:287, A1): March periodic-burst PT15M avg ≈ **39%**. June PT15M avg = **77.67%** — roughly **2×**. The precedent note explicitly flags this as *"weak evidence of worsening baseline"* the average alone cannot prove (02:237, 02:250). The RCA's "not a regression" conclusion never reconciles with this 2× jump.
3. **E7 recurrence data is not analyzed for trend.** E7 lists spike-*hours* per day (Jun08–15) but never compares burst **magnitude or duration** across days — the exact measurement that would distinguish "stable chronic" from "growing." Today's was "sustained enough to push PT15M>75" (E7:70) — that *is* a duration anomaly the RCA notes but does not treat as possible growth.

**Required change:** Soften rca.md:191/221 from *"not a regression"* to **"not a *configuration* regression (activity log empty, A1); a *workload-growth* regression is not excluded — June PT15M avg 77.67% vs March ≈39% is consistent with hotter bursts (A2, unresolved)."** Add discriminator: plot 7-day PT1M Max burst duration + peak-minute count per day; rising trend → demand-side growth.

---

## F3 — "586 vs 16,555 = metric-layer difference" hand-wave; the 34.5% throttle figure is retry-inflated

**Claim attacked:** rca.md:179 (*"metric-layer difference … one backend response can surface as many rejected Mongo ops"*) and the derived **"~34.5% of 47,953 Mongo ops throttled"** (rca.md:174, evidence E2:35), which drives fix.md:41's "429 > 5% ⇒ increase throughput" trigger.

**Verdict: WEAKENED (the 34.5% figure is FALSE as "fraction of distinct ops throttled").**

**Severity: MEDIUM-HIGH** (the 34.5% / >5% framing is load-bearing for T1 priority and the L8 "degraded ~1/3 of ops" headline; the *direction* survives, the *magnitude* does not).

**Evidence (mechanism):**

1. **Driver retry amplifies the 16500 count, not the 429 count, in exactly this ratio.** Microsoft Learn (monitor-normalized-request-units + error-codes-solutions, fetched this session, A1): on a 429/16500, *"the SDKs automatically retry requests … typically up to nine times."* Each *re-rejection* of one logical op emits **another** 16500 in `MongoRequests`. So 16,555 16500-events ≠ 16,555 distinct throttled operations — a single throttled logical op retried 9× contributes up to 9 events. The 28× gap (16,555 vs 586) is the **signature of retry amplification**, not an unexplained "metric-layer difference."
2. **Therefore 34.5% is computed wrong twice over.** Numerator (16,555) is retry-inflated; the denominator (47,953 total MongoRequests, E2:35) *also* counts retries as separate ops — so the ratio is "rejected protocol-events / total protocol-events," NOT "throttled distinct operations / distinct operations." The true distinct-op throttle fraction is **unknown and almost certainly well below 34.5%**. The 586 backend-429 count is the less-amplified figure and points to a much smaller real-impact fraction.
3. **This is not nitpicking:** rca.md:189 / L8 headline "~1/3 of ops throttled" and fix.md:41 "429 > 5% ⇒ increase" both inherit the inflated figure. The >5% Microsoft trigger should be evaluated against the **HTTP-429 fraction** (586 / TotalRequests in window), not the 16500 fraction.

**Required change:**
- Re-label the L7:179 reconciliation: state explicitly it is **retry amplification (SSR/driver retry up to 9×, A1 MS Learn)**, not a vague "metric-layer difference."
- Replace "~34.5% of ops throttled" with **"16,555 16500-events (retry-inflated) and 586 backend-429s over the window; the distinct-op throttle fraction is the 429-vs-TotalRequests ratio, A3 until TotalRequests window-total is captured."** Add the missing probe: `TotalRequests` Total (all status) for 15:27–15:40 → compute 586/total = true 429 rate, the figure the >5% rule actually wants.

---

## F4 — Depth-3 "Verified Root Cause" vs Hypothesis Set

**Claim attacked:** rca.md:185 *"Diagnosis class: Verified Root Cause (depth 3)."*

**Verdict: WEAKENED → should be a qualified Verified Root Cause.**

**Severity: MEDIUM** (classification integrity per the repo's Claim Gates).

**Evidence:** The depth-2 (single unsharded GridFS store at 1000 RU/s) and depth-3 (GridFS-in-Cosmos coupling + throughput-out-of-IaC + sensor-swap) layers ARE A1-grounded and survive — those are structural facts (E3, E10, L5/L6). What is NOT verified is **depth-1's collection attribution** (F1) and the **A3 solve-success gap** (rca.md:112, openly acknowledged). Per the repo's Diagnosis gate (min depth 2 for HIGH, confirmed by independent disconfirmation): the *class* (RU-ceiling saturation) is Verified; the *specific saturator* is a Hypothesis (fs.chunks, leading, not eliminated).

**Required change:** Keep "Verified Root Cause" for the **saturation class / depth-2-3 structure**, but explicitly scope it: *"Verified: RU-ceiling saturation of the grb_rsm collection set (depth 2-3). Hypothesis (leading, not yet discriminated): fs.chunks is the specific saturator — confirm via per-collection PT1M Max split (F1)."* This is honest depth-3-on-the-mechanism + Hypothesis-on-the-attribution, not a blanket downgrade.

---

## Conditional Route Impact (the one-line asks)

| Finding | If it holds → RCA must |
|---|---|
| **F1 (HIGH)** | Either downgrade depth-1 fs.chunks to A2, **or** run + capture the **per-collection PT1M Max split** discriminator (15:27–15:40Z). Falsifier: any other collection ≥90% → broaden cause, fix T1. |
| **F2 (MED)** | Reword "not a regression" → "not a *config* regression; workload-growth not excluded (June 77.67% vs March ≈39%)." Add burst-trend probe. |
| **F3 (MED-HIGH)** | Re-label 586-vs-16,555 as **driver-retry amplification (A1 MS Learn)**; drop/qualify the 34.5%; capture `TotalRequests` window-total to compute the real 429 rate against the >5% trigger. |
| **F4 (MED)** | Scope the "Verified Root Cause" to the saturation *class*; mark the fs.chunks *attribution* as leading Hypothesis. |

**Survives intact:** the RU-ceiling-saturation mechanism, the structural depth-2/3 enablers (unsharded GridFS, 1000-RU ceiling, throughput-out-of-IaC, 429-alert removal), the "not noise / not new-token-server / not CMC-drain" classification (precedent canon, well-sourced), and the tiered-remediation direction. My lane found **no evidence the diagnosis is in the wrong class** — only that the *collection attribution* and the *throttle magnitude* are overstated relative to captured evidence.
