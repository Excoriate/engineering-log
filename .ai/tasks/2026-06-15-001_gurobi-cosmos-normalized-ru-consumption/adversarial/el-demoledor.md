---
task_id: 2026-06-15-001
agent: el-demoledor
status: complete
timestamp: 2026-06-15T16:53:32Z
summary: >-
  Adversarial demolition of the gurobi-cosmos RU-saturation RCA's load-bearing claims. Verdicts:
  C1 (fs.chunks=GridFS) HOLDS as A2, inference safe. C2 (unsharded => single physical partition)
  CRACKED — valid for THIS collection by live size, but the RCA states it as an absolute mechanic;
  unsharded Cosmos collections CAN split past ~50GB, and the claim must be scoped to "current size".
  C3 (Max==Avg => one series) CRACKED — Max==Avg proves at most ONE non-zero partition per minute,
  not permanently one partition; corroborated by single-partition size but over-stated as proof.
  C4 (IaC == live "byte-for-byte") BROKEN — field names differ (frequency vs evalFreq) so NOT
  byte-for-byte; semantically equal only. C5 GATE: found a hard internal contradiction the RCA
  never flagged — the IaC alert DESCRIPTION says "greater than 75% for more than 5 minutes" while
  window_size=PT15M (15 min), AND the removed 429 alert had threshold>=20 (not "5%") and WOULD HAVE
  FIRED on this 586-count burst (29x its threshold) — a load-bearing omission that weakens L6/L7/L10/T2.
  Plus several label leaks. None of the cracks overturn the root cause (RU-ceiling saturation is
  A1-solid), but four claims must be re-scoped/relabeled before status=complete.
---

# El Demoledor — Demolition Receipt

**Target:** `rca.md` + `fix.md` load-bearing claims (lane: artifact epistemics only; NOT fix economics, NOT goal-fidelity).
**Scope:** Full (verified against live local IaC at HEAD `c17995a` + the f956e9b removal diff + external-docs lane).
**Method:** Read all 4 artifacts; re-ran the IaC reads the RCA cites; pulled the actual `f956e9b` diff that the RCA only describes.

> **Evidence grades:** EXPLOIT-VERIFIED (I re-ran the probe / read the source and confirmed) ·
> PATTERN-MATCHED (known-fragile shape, not re-executed) · THEORETICAL (mechanism-real, reachability bounded).

---

## DESTRUCTION SUMMARY

| Metric | Count |
|--------|-------|
| Claims attacked | 5 (+ gate scan) |
| HOLDS | 1 (C1) |
| CRACKED (over-stated / must re-scope or relabel) | 3 (C2, C3, C5-contradiction) |
| BROKEN (false as literally written) | 1 (C4) |
| Label leaks found | 6 |
| Does any crack overturn the root cause? | **NO** — RU-ceiling saturation is A1-solid (E2/E3) |
| Highest-stakes crack | C5: removed 429 alert (threshold >=20) **would have fired** on this 586-count burst — RCA never says so |

---

## C1 — "fs.chunks is GridFS storing Gurobi input models/solutions"

**RCA location:** L4:110 (`A2 INFER`), summary:11, L8 Depth-2/3, fix.md T3:111.

**VERDICT: HOLDS** (correctly labeled A2; inference is safe).

**Severity:** n/a (no crack) · **Confidence:** EXPLOIT-VERIFIED.

**Evidence the inference is safe:**
- A1 substrate is real: `collection show` reports `fs.chunks` + `fs.files` present, indexes `_id` + `(files_id,n)` (E3:43). The `(files_id, n)` compound index is the *literal* GridFS chunk-index signature — this is not "looks like GridFS," it IS the GridFS chunk schema. MongoDB's GridFS spec mandates exactly `{files_id:1, n:1}` on `fs.chunks`. So "fs.chunks is GridFS" is stronger than A2 — it is effectively A1 by schema signature.
- The *second half* — "storing **Gurobi input models/solutions**" — is the genuinely inferential part, and it is correctly A2: it chains GridFS-large-object-pattern (A1 MongoDB convention) + Gurobi Cluster Manager stores "input models and their solutions" (A1 docs, 03-external-docs B.3:229). The RCA does NOT over-claim here; it labels it A2 at L4:110.

**Counter-hypothesis I tried:** Could `fs.chunks` be something else — e.g., a different app's GridFS, or a coincidentally-named collection? Rejected: it lives in `grb_rsm` (Gurobi Remote Services Manager DB, E3/mongodb.tf:42), alongside `batches`/`jobhistory`/`registry` (Gurobi Cluster Manager's documented schema). No competing consumer of this DB exists. The inference holds.

**I would switch IF:** the `(files_id,n)` index were absent, or a non-Gurobi writer of `grb_rsm` were found. Neither is true.

**Required edit:** none. (Optional: the RCA could upgrade the "is GridFS" half to A1 on the index signature, but A2 is conservatively correct.)

---

## C2 — "Unsharded (shardKey:null) => single physical partition"

**RCA location:** L3:98 ("`fs.chunks`, which is **unsharded** (`shardKey: null`) -> a single physical partition [A1]"), mermaid:84, L8 Depth-2:188, E1:27.

**VERDICT: CRACKED** — true for THIS collection *right now*, but the RCA states it as an absolute, label-tags it `A1`, and uses it as a load-bearing premise for the "single series" reasoning (C3). The mechanic is not absolute.

**Severity:** MEDIUM (Exploitability: low — needs the collection to grow; Impact: medium — it is the premise under C3 and the L8 Depth-2 "single partition" diagnosis; Confidence: high). · **Evidence grade:** THEORETICAL (mechanism is real; reachability depends on collection size, which the RCA never measured).

**The crack:** In Azure Cosmos DB for MongoDB, "unsharded" / `shardKey: null` means there is **no user-defined shard key**, so all documents currently route to a single partition-key value. That gives a single *logical* partition. But Cosmos physical partitions have a hard ~50 GB (and ~10k RU/s) ceiling **per physical partition**; an unsharded collection that crosses ~50 GB of data, or whose throughput needs exceed a single physical partition's ceiling, gets **split into multiple physical partitions** by the service — even without a user shard key. "Unsharded" is a *logical* property; "single physical partition" is a *physical* runtime fact that is only true while the collection stays under the split thresholds.

- The external-docs lane the RCA itself relies on states the metric is "the **maximum** RU/s utilization **across all partition key ranges**" and "Each partition key range maps to one physical partition" (03-external-docs A.1:51-59). That definition presupposes a collection can have *multiple* partition key ranges. The RCA imports the convenient half ("max across partitions") for C3 but asserts the opposite ("single partition") for C2 without reconciling them.
- **What rescues C2 for THIS incident** (and why it is CRACKED not BROKEN): `fs.chunks` throughput floor is `minimumRU 1000` with `autoscaleMax 1000` (E3:40) — Cosmos sets `minimumRU = max(1000, 100 * ceil(maxRU/10000) , 0.01 * maxStorageGB ...)`; a `minimumRU` pinned at exactly 1000 implies the collection is small (well under the storage that would bump the floor) and has **not** triggered a storage-based split. So *empirically* it is single-partition today. But the RCA never makes THIS argument — it asserts "unsharded => single partition" as a categorical A1 truth.

**Counter-hypothesis I tried:** "Unsharded always means one partition, full stop." Rejected — that is precisely the Cosmos misconception that the troubleshoot-hot-partition docs (03-external-docs A.3:103-109) exist to correct; a collection can have multiple physical partitions with no user shard key once it grows. The RCA's own cited source contradicts the absolute reading.

**I would switch to HOLDS IF:** the RCA re-scoped the claim to "single physical partition **at its current size** (minimumRU pinned at 1000 => below the ~50GB / RU split threshold) [A1 size + A2 inference]" instead of stating it as an unconditional mechanic.

**Required edit (L3:98 + mermaid:84 + L8:188):** Downgrade the bare "`shardKey: null` -> a single physical partition [A1]" to: "`shardKey: null` (unsharded) -> a single **logical** partition; and — at its current size, with `minimumRU` pinned at 1000 RU/s, below Cosmos's ~50 GB physical-partition split threshold — a single **physical** partition today. [A1: shardKey + minimumRU; A2: physical-single-partition inference, valid only while under the split threshold.]" This protects the RCA against the day `fs.chunks` grows and silently splits, at which point NormalizedRU stops being a clean single-series read.

---

## C3 — "Max == Avg per minute => effectively one series"

**RCA location:** E1:27 ("Max≡Avg per minute ⇒ effectively one series (consistent with the unsharded single-partition `fs.chunks`)"), and implicitly the RCA's whole "the account metric == the fs.chunks metric" simplification (L8 Depth-1).

**VERDICT: CRACKED** — the inference direction is over-stated. `Max == Avg` is *consistent with* one hot series but does **not prove** "effectively one series." E1 hedges ("effectively", "consistent with") which is honest, but the reasoning chain leans on it as if it pins the hot collection to `fs.chunks`.

**Severity:** LOW-MEDIUM (Exploitability: low; Impact: medium — it is part of the "the 77.67% account reading IS fs.chunks" identification; Confidence: high on the logic). · **Evidence grade:** EXPLOIT-VERIFIED (the logical gap is verifiable from the metric semantics).

**The crack — Max==Avg can arise three other ways the RCA does not exclude:**
1. **Multiple partitions whose maxes are all equal in that minute.** NormalizedRU is the *max across partition key ranges* (03-external-docs A.1). If two partitions each peg at 100% in the same minute, `Max == Avg == 100` — yet that is TWO hot series, not one. The window data (E1:23, seven consecutive minutes at 100/100) is *equally consistent* with two-or-more co-saturated partitions as with one.
2. **Aggregation-shape artifact.** For a metric where the per-minute datapoint is *already a max-over-partitions* (A.2:73), Azure Monitor's `Max` and `Avg` over a PT1M grain operate on a stream that may be a single time-series per resource at the account scope. If the account-scope NormalizedRU is emitted as ONE series (not split by `CollectionName`/`PartitionKeyRangeID`), then `Max(series) == Avg(series)` whenever the series has one datapoint per minute — i.e., `Max==Avg` would be a **trivial identity of the aggregation**, telling you nothing about partition count. E1 does not state whether the probe split by CollectionName; if it did not, Max==Avg is near-tautological.
3. **A single hot *collection that is itself multi-partition*** (see C2) — Max==Avg at the account level is consistent with one collection dominating, but that collection could already be multi-physical-partition.

**What rescues the *conclusion* (fs.chunks is the hot one):** the RCA has an INDEPENDENT A1 path — command #3 in L11:250-253 splits NormalizedRU by `CollectionName` and the RCA asserts the hot one is `fs.chunks` (Context Ledger:45, L3:98). That per-collection split — not the Max==Avg coincidence — is the real evidence. So the *identification* survives; the *Max==Avg => one series* inference is a weak, partly-circular supporting argument that should not carry weight.

**Counter-hypothesis I tried:** "Max==Avg genuinely proves a single active series." Rejected — it proves at most that in each minute the distribution of per-partition maxes collapsed to one value; with a max-of-maxes metric and equal co-saturation, that is satisfied by N>=2 partitions. The implication is one-directional and the RCA uses it bidirectionally.

**I would switch to HOLDS IF:** E1 stated whether the metric was split by `CollectionName`/`PartitionKeyRangeID`. If it was a per-collection split and `fs.chunks` was the only non-zero series, then "one series" is A1-observed (not inferred from Max==Avg).

**Required edit (E1:27):** Reword to: "Max==Avg per minute is **consistent with** a single dominant hot series; the hot collection is independently identified as `fs.chunks` by the per-`CollectionName` split (L11 cmd #3, A1). Max==Avg alone does not prove single-partition — it is also consistent with multiple co-saturated partitions, given NormalizedRU is a max-across-partitions metric." Demote the parenthetical from load-bearing to corroborating.

---

## C4 — "IaC alert == live alert byte-for-byte"

**RCA location:** L5:145 ("The deployed rule matches the IaC **byte-for-byte**: ... `windowSize PT15M`, `evalFreq PT5M` ..."), Reconciliation:147 ("IaC alert == live alert ✓").

**VERDICT: BROKEN** (as literally written) — the two are **semantically equivalent**, not byte-for-byte. The RCA's own quoted tokens disprove the literal claim.

**Severity:** LOW (Exploitability: trivial — it is self-evident from the RCA's own text; Impact: low — semantic equivalence is what matters operationally; Confidence: high). · **Evidence grade:** EXPLOIT-VERIFIED (I re-read both the IaC at HEAD c17995a and the live E4 capture).

**The break — three byte-level mismatches between IaC (verified live at c17995a) and live ARM (E4:49-53):**
| Field | IaC (`src/locals.tf` / `alerts.tf`, c17995a) | Live ARM (E4) | Byte-identical? |
|-------|-----------------------------------------------|---------------|-----------------|
| eval frequency | `frequency = "PT5M"` | `"evalFreq":"PT5M"` | **NO** — different *key name*; value matches |
| metric criterion key | `NormalizedRUConsumption` (HCL map key) | `"metricName":"NormalizedRUConsumption"` | value matches, structure differs |
| aggregation | `aggregation = "Average"` | `"timeAggregation":"Average"` | **NO** — different key name |
| description | `<<DESC` heredoc, 3 lines | (not shown in E4) | unverifiable as "byte-for-byte" |

The IaC field is `frequency`; ARM serializes it as `evalFreq`. `aggregation` becomes `timeAggregation`. These are the Terraform-provider-to-ARM field renames — expected and correct, but **definitionally not "byte-for-byte."** The RCA even lists the divergent key names (`evalFreq` vs the IaC `frequency`) in the same sentence that claims byte-for-byte, which is internally self-refuting.

**Counter-hypothesis I tried:** "Byte-for-byte is rhetorical shorthand for 'no drift.'" Partially granted — operationally there is no *semantic* drift (every value matches; deployed == intended). But the RCA is an evidence-labeled A1 document where precision is the whole point, and it states a literal byte claim that its own evidence breaks. In an A1-graded artifact, "byte-for-byte" is a falsifiable assertion and it is false.

**I would NOT switch:** the literal claim is false; only a wording change fixes it.

**Required edit (L5:145):** Replace "matches the IaC **byte-for-byte**" with "matches the IaC **semantically — every criterion value is identical** (Terraform `frequency`/`aggregation` serialize to ARM `evalFreq`/`timeAggregation`; values: `NormalizedRUConsumption`, `GreaterThan 75`, `Average`, `PT15M`, `PT5M`, sev 2, enabled, autoMitigate). No deployment drift. [A1]". Keep the ✓ in Reconciliation but drop "byte-for-byte".

---

## C5 — "NO UNVERIFIED CLAIM" GATE (scan rca.md + fix.md for unlabeled / mislabeled load-bearing statements)

**VERDICT: CRACKED** — one hard internal contradiction the RCA never flags, plus 6 label leaks. The contradiction is the highest-stakes finding in this receipt.

### C5.0 — INTERNAL CONTRADICTION (highest severity, EXPLOIT-VERIFIED)

**The IaC alert description contradicts its own window, and the removed 429 alert would have fired on this incident — the RCA states neither.**

1. **Description vs window contradiction (verified at c17995a, `src/locals.tf:22-23`):** the live, team-authored alert description reads *"Trigger when normalized RU consumption is greater than 75% **for more than 5 minutes**"* — but the rule's `window_size = "PT15M"` (15 minutes) and `frequency = "PT5M"`. The description says 5 minutes; the rule evaluates a 15-minute average. The RCA's L5:122-138 code block **paraphrases the heredoc down to** `description = "Trigger when normalized RU consumption is greater than 75% ..."` — truncating the exact "for more than 5 minutes" clause that exposes the contradiction. The RCA thus *hid* (unintentionally) the one piece of evidence that the alert's stated intent (5-min sustained) does not match its implemented behaviour (15-min average). This is load-bearing for the RCA's "the sensor changed" thesis: the description was written for a PT5M window (the original `f956e9b` config had `window_size = "PT5M"`), and `d7fc972` later changed the window to 15M **without updating the description** — leaving a stale, self-contradicting alert definition. **Required edit:** Add to L5/L10 a flagged finding: "The alert description (`for more than 5 minutes`) is **stale** — `d7fc972` widened the window to PT15M but left the PT5M wording. The implemented behaviour is a 15-min average, not a 5-min sustained check. [A1: locals.tf:22-23 + git d7fc972]."

2. **The removed 429 alert WOULD HAVE FIRED — RCA never computes this (EXPLOIT-VERIFIED from the `f956e9b` diff, which the RCA only *describes* but never *opened*):** the removed `gurobi-cosmos-throttling-429` alert was `TotalRequests StatusCode=429, aggregation Count, GreaterThanOrEqual, threshold = 20, window PT5M`. Its own inline comment: *"We see 429 responses regularly... 1 or 2... set the threshold to 20 to prevent the alert from being triggered by normal behavior."* The 2026-06-15 window produced **586** 429s (E2:31), with single-minute peaks of 181 (15:32). **586 is ~29x the old threshold of 20; the 15:32 minute alone (181) is ~9x.** The OLD 429 alert would have fired hard on this incident. The RCA repeatedly calls the removed alert merely *"lagging"* (L6:161, L7:171, L10 lesson 2:218) and frames the new RU alert as the thing that made the page "look new" — but it **never states the decisive fact that the deleted alert would have caught THIS exact burst**, which is the strongest possible argument for T2 (re-add the 429 alert). The RCA *under-sells its own fix*. **Severity: HIGH** for the gate (a load-bearing, fix-justifying fact is absent and the supporting diff was never opened — it is cited from the commit *subject line* only). **Required edit:** L6/L7/L10/T2 must add: "The removed `gurobi-cosmos-throttling-429` alert had threshold `>=20` 429s/PT5M (comment: tuned to ignore the routine 1-2 429s). This incident's **586** 429s (peak 181/min) is ~29x that threshold — **the deleted alert would have fired on this burst.** [A1: git show f956e9b src/locals.tf]." This converts T2 from "good practice" to "restores a sensor that demonstrably caught this class."

3. **Fix.md T2 threshold inconsistency (MEDIUM):** fix.md:92 proposes the re-added 429 alert with `threshold = 500` ("~>5% of normal window op volume; backtest vs 2026-06-15 (586 in window)"), `aggregation Total`, `window PT5M`. But the *original* (deleted) alert used `threshold 20`, `Count`, and the incident had 586. A threshold of 500 over PT5M would have fired on this incident (586 > 500) but only barely, and would MISS the 15:32-only spike pattern if spread differently. fix.md never reconciles its proposed 500 against the historical 20, nor against the per-minute distribution (the 586 is not evenly spread — it is 85/181/57/145/118 across 5 discrete minutes, E2:31). Picking 500/PT5M-Total is asserted, not derived. **Severity: MEDIUM** (preference-shaped: a tuning choice, recoverable). **Required edit:** fix.md T2 must show the derivation: state the old threshold (20), the incident distribution (E2), and why 500 (not 20, not 100) — or label the 500 as `A3 UNVERIFIED[needs backtest]` rather than presenting it inline as a worked number.

### C5.1 — LABEL LEAKS (statements presented as harder than their evidence supports)

| # | Location | Statement | Leak | Required edit |
|---|----------|-----------|------|---------------|
| L1 | rca.md L3:98 | "unsharded (`shardKey: null`) -> a single physical partition [A1]" | Physical-partition-count is **A2** (inferred from minimumRU/size), not A1. Only `shardKey:null` is A1. | Split the label (see C2). |
| L2 | rca.md E1:27 / L8:187 | "Max≡Avg per minute ⇒ effectively one series" used to support the single-partition diagnosis | Unlabeled inference doing load-bearing work; it is at most A2 and partly circular (see C3). | Label A2 + demote to corroborating. |
| L3 | rca.md summary:11-16 (frontmatter) | "saturated the unsharded GridFS fs.chunks collection... ~34.5% throttled... avg 77.67%..." stated flatly | Frontmatter summary states the GridFS-content inference (A2) and the single-partition inference (A2) as bare fact with no labels. Summaries are exempt from inline labels, but this one asserts the two weakest inferences as headline fact. | Acceptable IF body labels hold; tighten "GridFS fs.chunks" -> "the hot fs.chunks (GridFS) collection". Low severity. |
| L4 | rca.md L5:145 | "matches the IaC **byte-for-byte** ... [A1]" | A1-labeled but literally false (C4). The label is correct that it was *witnessed*; the *claim* is wrong. | Reword per C4. |
| L5 | rca.md L7:179 | "586 HTTP-429 vs 16,555 Mongo-16500 is a metric-layer difference... one backend response can surface as many rejected Mongo ops [A2 INFER]" | The *direction* is plausibly inverted: typically MANY client Mongo ops (16500) map to FEWER backend 429 accounting events, i.e. 16500 >> 429 because the Mongo protocol counts per-operation rejections while TotalRequests/429 counts at a coarser grain — the RCA's wording "one backend response surfaces as many rejected Mongo ops" is a hand-wave that is correctly A2 but mechanistically vague. | Acceptable as A2; optionally tighten the mechanism or mark the ratio explanation `A3 UNVERIFIED[mechanism not confirmed]`. Low severity. |
| L6 | fix.md T1:41 | "Microsoft's framework: NormalizedRU consistently 100% **and** 429 > 5% => increase throughput. **Both hold.**" | "429 > 5%" is asserted as holding, but neither rca.md nor the evidence computes the **429 rate as a percentage** — E2 gives 586 (429) and 47,953 (total Mongo ops) => 429/total ~1.2%, which is **inside Microsoft's 1-5% "healthy" band, NOT >5%**. The 16500 rate is 34.5%, but 16500 != HTTP 429 (the RCA itself separates them at L7:179). So "429 > 5%, both hold" is **unverified and likely FALSE** by the HTTP-429 measure. | **HIGH severity leak.** fix.md must either compute the correct 429% (586/47953 ~1.2% HTTP-429, or justify using the 16500 34.5% figure as the rate) and relabel; as written it overstates the Microsoft trigger. This directly affects T1's justification. |

**C5 verdict rationale:** the gate FAILS at the "no load-bearing claim unlabeled/mislabeled" bar on three counts that matter (C5.0.2 the would-have-fired omission, L6 the 429%>5% overstatement, L1 the A1/A2 conflation) and several cosmetic ones. None falsify the root cause, but `status: complete` is not earned until C5.0.2, C4, C2-label, and fix.md-L6 are corrected.

---

## CASCADE / WHAT DOES *NOT* BREAK (exhaustive-proof discipline)

I tried to collapse the **root cause** itself and could not:
- **RU-ceiling saturation is A1-bulletproof:** E3 (`autoscaleMax 1000`), E1 (RU pinned 100% for 7 of ~14 min), E2 (586 HTTP-429 + 16,555 Mongo-16500, 34.5% of 47,953 ops) are all live `az` captures. The collection hit its ceiling and threw real throttling. No crack.
- **"Not a regression" is A1-solid:** E9 (activity log empty since 2026-05-15 => no throughput write) + E10 (git history shows the *alert* changed, not the DB). The `f956e9b`/`d7fc972` diffs I re-pulled confirm the sensor-swap narrative. No crack.
- **autoMitigate / self-resolved:** E4 + E5, A1. No crack.
- The solve-success residual is **correctly** held as A3 (L4:112, L9, fix.md T0) — the RCA does not overstate it. Good discipline.

So the demolition outcome is: **the diagnosis stands; four supporting claims are over-stated/mislabeled and one fix-justifying fact (and the strongest argument for T2) is missing.** The structure is sound; four load-bearing beams are mis-rated and must be re-stamped before sign-off.

---

## ADVERSARIAL SELF-CHECK

- **Pattern-matching check:** C2 and C3 are real logical/mechanistic gaps, verified against the RCA's *own* cited MS Learn definition (max-across-partitions presupposes multiple partitions) — not pattern-dumped. C4 is verified from the RCA's own quoted tokens. C5.0.2 and C5-L6 are arithmetic I performed (586/47953, 586 vs 20). Not noise.
- **False-positive conditions named:** C2 is a false positive IF the collection is provably <50GB AND the RCA had said so (it did not). C3 is a false positive IF E1's probe was per-CollectionName split (E1 does not state it). C4 is NOT a false positive — the literal claim is false. C5-L6 is a false positive IF the RCA intends "429" to mean Mongo-16500 (but it explicitly separates them at L7:179, so the 1.2% HTTP-429 reading stands).
- **Redundancy / root-cause grouping:** C2 and C3 share a root cause — both stem from treating "unsharded" as "permanently one physical partition" and reading more into the metric than its max-across-partitions semantics allow. They are ONE conceptual flaw with two manifestations (partition mechanic + Max==Avg). C5-L1 and C5-L2 are the label-side of the same flaw. Reported as related, not inflated.
- **Severity-inflation check:** I did NOT rate the root cause as cracked (it is not). C4 is correctly LOW. Only C5.0.2 (missing would-have-fired fact) and C5-L6 (429%>5% overstatement) are HIGH, and both are *omissions/overstatements of fix-justifying facts*, not root-cause errors — honestly scored.

**Meta-falsifier (strongest defense against my own findings):**
- *Strongest defense of C4:* "byte-for-byte is colloquial." I downgraded C4 to LOW accordingly but did not remove it — in an A1-labeled artifact a literal falsifiable claim must be literally true.
- *Strongest defense of C2/C3:* "for THIS incident, fs.chunks is provably single-partition and provably the hot collection." Granted — which is why both are CRACKED (re-scope), not BROKEN. The diagnosis is safe; the *general claims* are not.
- **Confirmed after meta-falsification:** C2, C3, C4, C5.0.2, C5-L6, C5-L1. **Downgraded:** C4 to LOW, C5-L3/L5 to cosmetic. **Removed:** none.

---

## CONDITIONAL ROUTE IMPACT (required before status=complete)

| Crack | Verdict | Mandatory edit before `status: complete` |
|-------|---------|------------------------------------------|
| C2 | CRACKED | Re-scope L3:98 / mermaid:84 / L8:188 to "single **physical** partition **at current size** [A2]"; split the A1/A2 label. |
| C3 | CRACKED | Reword E1:27 — Max==Avg is corroborating not proof; identification rests on the per-CollectionName split (A1). |
| C4 | BROKEN | Replace "byte-for-byte" with "semantically identical, no drift" at L5:145. |
| C5.0.1 | CRACKED | Flag the stale alert description ("5 minutes" vs PT15M window) at L5/L10. |
| C5.0.2 | CRACKED (HIGH) | Add the would-have-fired fact (586 ~29x the deleted alert's threshold 20) to L6/L7/L10/T2 — open the f956e9b diff, do not cite by subject line. |
| C5-L6 | CRACKED (HIGH) | fix.md T1:41 — compute the real HTTP-429 rate (~1.2%, inside 1-5% healthy) vs the 16500 rate (34.5%); do not assert "429 > 5%, both hold" unlabeled. |
| C5.0.3 | CRACKED (MED) | fix.md T2 — derive the proposed 429 threshold (500) from the old 20 + the per-minute distribution, or label A3. |

**C1 requires no edit.** None of these overturn the diagnosis; all are precision/labeling corrections that an A1-graded RCA must pass before sign-off.

*El Demoledor: proving resilience through destruction. The building stands — four beams need re-stamping.*
