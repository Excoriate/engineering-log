---
task_id: 2026-06-15-001
agent: precedent-reader
status: complete
summary: >-
  2026-06-15 NormalizedRUConsumption>75% Sev2 alert is NOT a like-for-like
  recurrence of the 2026-03-27 429-throttling alert — it is the WARNING-CLASS
  sibling (avg RU saturation, pre-429) that the March RCA itself recommended
  creating. Same resource, same underlying RU-exhaustion mechanism, but a
  distinct metric/threshold/alert-rule. The real capacity fix (autoscale) from
  March was NOT implemented; canon classifies persistent Gurobi RU alerts as the
  "open RU-exhaustion class — does not self-clear" → escalate to Nuno. The
  cosmos→mongo migration note targets the VPP Dispatcher domain, NOT the Gurobi
  store, so a Cosmos fix here is not moot.
timestamp: 2026-06-15T16:25:28Z
---

# Precedent + Organizational Canon — Gurobi Cosmos RU Alert (2026-06-15)

**Lane**: precedent + organizational canon (read-only). Is 2026-06-15 a recurrence
of a KNOWN cause, and what did we conclude/fix on 2026-03-27?

> All claims below are **INFER** at the coordinator level until source-verified.
> Each load-bearing claim carries A1/A2/A3 + file:line or vault note title.

---

## TL;DR Verdict

The 2026-06-15 alert (`gurobi-cosmos-normalized-ru-consumption-a`, NormalizedRUConsumption
Avg 77.67% / threshold 75% / PT15M, Sev2, ACC) is **a distinct sub-threshold WARNING
class of the SAME underlying RU-exhaustion mechanism** documented on 2026-03-27 — **not**
a like-for-like recurrence of the March alert, and **not** (yet) evidence of escalation
to sustained 429 throttling. The March incident fired a **different alert rule**
(`gurobi-cosmos-throttling-429-a`, TotalRequests/StatusCode=429, threshold 20, PT5M) and
**did observe real 429s**. The June metric is the *early-warning gauge* the March RCA
explicitly recommended adding.

**The discriminator that decides recurrence-vs-distinct** (see §6): *which metric and
which failure mode fired.* 429-count fired in March (rejection happening). Average-RU%
fired in June (saturation approaching, rejection not necessarily occurring). Same disease,
different thermometer.

---

## Q1 — 2026-03-27 root cause: which alert, were 429s observed, payload/threshold

**A1 — March was a DIFFERENT alert rule, and 429s WERE observed.**

- Alert rule: `gurobi-cosmos-throttling-429-a`, metric `TotalRequests`, dimension
  `StatusCode = '429'`, `GreaterThanOrEqual`, `threshold "20"`, `windowSize "PT5M"`,
  `timeAggregation "Count"`, Sev2.
  (A1: `rootly-alert-payload.json:28-51` — `metricName: "TotalRequests"`,
  `threshold: "20"`, `metricValue: 24`, `windowSize: "PT5M"`, dimension value `"429"`.)
- Real 429s observed: **24 throttled requests** in the firing 5-min window
  (`windowEndTime 2026-03-27T13:44:32.994Z`). Repeating ~15-min bursts each driving 24×
  429s and NormalizedRU to 100%.
  (A1: `root-cause-analysis.md:20-45` burst table; `rootly-alert-payload.json:43`
  `metricValue: 24`.)
- The same metric resource (`cosmosdb-gurobi-platform-a`) and RG (`rg-gurobi-platform-a`)
  as the June alert. (A1: `rootly-alert-payload.json:13-25`.)

**Contrast with 2026-06-15** (from the task context, coordinator-supplied — A3 until the
June payload is in hand): June fired on `NormalizedRUConsumption` **Average 77.67% /
threshold 75% / PT15M**. That is the *saturation gauge*, NOT a 429 count. So:

| | 2026-03-27 (March) | 2026-06-15 (June) |
|---|---|---|
| Alert rule | `gurobi-cosmos-throttling-429-a` | `gurobi-cosmos-normalized-ru-consumption-a` |
| Metric | `TotalRequests` (StatusCode=429) | `NormalizedRUConsumption` |
| Aggregation / window | Count / PT5M | Average / PT15M |
| Threshold | ≥ 20 | > 75% |
| Failure mode | **rejection already happening** (429s) | **saturation approaching** (avg RU high) |
| 429s confirmed? | **Yes — 24** (A1) | Not stated in the alert; the metric does not measure 429s (A2) |

**A2 (INFER)**: The June alert is *downstream-named* from the March RCA's own remediation.
The March RCA proposed a new `gurobi-cosmos-ru-saturation` alert: NormalizedRUConsumption,
`aggregation = "Average"`, `window_size = "PT15M"`, `operator = "GreaterThan"`,
**`threshold = 60`**, **`severity = 3`** (warning).
(A1: `root-cause-analysis.md:742-761`.) The June alert is the *same metric/aggregation/
window family* but fired at **threshold 75% and Sev2**, not 60%/Sev3 — so the deployed
alert is **not byte-identical** to the March proposal. *(Falsifier: if the deployed June
alert rule shows threshold=60/severity=3, then the March proposal landed verbatim; if it
shows 75/Sev2, it was retuned or is a different rule. The live IaC/alert payload — outside
this lane — settles it.)*

---

## Q2 — What FIX was applied/recommended in March; landed or open?

**Recommended in March** (A1: `root-cause-analysis.md:570-842`, §7 Remediation):

1. **Today**: alert retune — `window_size = PT15M`, throttling threshold 20→60 (Change 2).
2. **This week**: enable burst capacity (Change 1) — explicitly labelled "TEMPORARY — not a
   fix" / "band-aid" (`root-cause-analysis.md:590-603`).
3. **Within 2 weeks**: **autoscale on hot collections via CLI** (Change 3) — called
   *"the real fix"* (`root-cause-analysis.md:585`, `:802-842`). Cannot be done in Terraform
   (provider can't switch manual↔autoscale; collections are app-created, not TF-managed).
4. **Long-term**: application-side backoff/jitter / schedule redesign (Options C/D).
5. A **temporary triage runbook** with a **mandatory sunset date 2026-04-10**
   (`root-cause-analysis.md:848-851`, `:934`, `:1150`) — explicitly so the runbook would NOT
   suppress feedback pressure to do the real fix indefinitely.

**Landing status — the real fix (autoscale) was NOT implemented. (A2, strong.)**

- The throttling-pattern vault note (captured 2026-04-15, **status: review**) ends with a
  *Historical caveat*: "The source RCA also proposed temporary runbook and alert-tuning
  measures … **Keep the pattern, but re-check any exact threshold, autoscale, or responder
  automation assumptions before using them as live guidance.**"
  (A1: `eneco-vpp-gurobi-cosmosdb-throttling-pattern.md:83-87`.) → the note does NOT record
  autoscale as done; it flags it as unverified.
- The note's durable rule: *"Treat autoscale or higher throughput as the real capacity fix.
  Alert tuning only changes who gets paged, not the database ceiling."*
  (A1: `eneco-vpp-gurobi-cosmosdb-throttling-pattern.md:79-80`.)
- The architecture canon (2026-05-30, status active) confirms the structural enabler is
  STILL in place: *"throughput is **not** managed through Terraform yet"* and the Cluster
  Manager app creates the collections itself.
  (A1: `eneco-vpp-gurobi-cluster-architecture.md:88`.) → No IaC-managed throughput means the
  100-RU/s-no-autoscale provisioning very likely persists.
- The recognition-week digest (2026-06-14) names a still-**"open RU-exhaustion class"** for
  Gurobi/CosmosDB (see Q4). "Open" ⇒ not closed by a landed fix. (A1:
  `eneco-oncall-recognition-week-2026-06-08.md:65`.)

**A3 [blocked]**: I cannot positively confirm autoscale was *never* applied — that requires
a live `az cosmosdb mongodb collection throughput show` probe (out of this lane). Resolving
path: coordinator's live-Azure lane checks current throughput type on the hot collections.
But every canon surface I can read points to OPEN, not fixed.

---

## Q3 — Throttling-pattern vault note: self-resolving or persistent exhaustion?

**A1 — Documents BOTH, and tells you how to tell them apart; the persistent class is real
RU exhaustion, NOT auto-clearing.**

Three patterns (A1: `eneco-vpp-gurobi-cosmosdb-throttling-pattern.md:52-58`):

| Pattern | Signature | Self-resolves? |
|---|---|---|
| **Periodic burst** | RU spikes to 100% then falls to low baseline, repeating cadence | The bursts pass, but the *capacity ceiling* does not — under-provisioned, not auto-fixed |
| **Sustained degradation** | RU stays elevated across consecutive windows, 429s compound | **No** — under-provisioned or retry-amplified |
| **Post-upgrade reconnect storm** | 429 spike clustered against a node-upgrade/pod-reschedule window; replicas-mismatch + memory-high fire together | **Yes — transient & self-resolving**, but indistinguishable from a real regression until upgrade context is known (A1: `:56`, `:58`) |

The reconnect-storm pattern was observed concretely on **2026-03-26** on `eneco-vpp-prd`
during a CMC OpenShift node upgrade (A1: `:58`). That is the ONLY explicitly
self-resolving class, and it is gated on a known upgrade window.

Durable note rules (A1: `:73-80`): watch `NormalizedRUConsumption` not just 429 counts; a
threshold increase is NOT a fix and can hide worsening burst behavior; autoscale/higher
throughput is the real fix. → The note frames the RU-exhaustion as a **persistent capacity
problem**, self-resolving ONLY when the cause is a transient reconnect storm tied to an
upgrade.

---

## Q4 — Recognition-week note: how is a Gurobi RU alert classified; triage routing?

**A1 — Two explicit Gurobi classes, with a hard disambiguator.**
(A1: `eneco-oncall-recognition-week-2026-06-08.md:64-65`, escalation map `:115`, CMC row `:67`.)

| Class | Signature | Routing |
|---|---|---|
| **New-token-server noise** | Gurobi Rootly alerts in the days after **2026-06-02** that **self-resolve** → new Gurobi PROD token server, transient/expected | **ack; no action** (`:64`) |
| **Open RU-exhaustion class** | Gurobi/CosmosDB alerts that **persist** or show **429 / RU-throttling** → "the **open RU-exhaustion class** (NOT new-server noise) — does **not** self-clear" | escalate to **Nuno** (fallback **#team-platform**) (`:65`, `:115`) |
| **CMC-upgrade drain** (overlay) | Memory/replica/CosmosDB-429 alerts **during a planned CMC upgrade** = expected drain — *only if it clears when the node returns* | n/a if it clears; **escalate if it persists or is outside a window** (`:67`) |

Critical timing facts for routing the June 15 alert:
- The "self-resolve" token-server class is **PROD** and tied to the post-2026-06-02 window
  (A1: `:64`). The June 15 alert is **ACC** — so the token-server-noise class does NOT
  apply.
- The CMC-upgrade-drain overlay: **prod OpenShift upgrade is scheduled 2026-06-17**
  (A1: `:100`, `:67`). June 15 is **before** that window and is **ACC**, not prod. ACC
  ArgoCD (~Jun 3) and ACC OpenShift (~Jun 4) upgrades were already **done** (`:67`). So the
  June 15 ACC alert is **outside any active upgrade window** → the digest's own rule says
  *"Drain alerts outside these env/date windows are NOT expected"* (`:67`) → treat as real.
- Net routing: June 15 maps to the **open RU-exhaustion class → escalate to Nuno (fallback
  #team-platform)**, NOT the ack-no-action class. (A2 from `:65`, `:67`, `:115`.)

---

## Q5 — Cosmos→Mongo migration: is `cosmosdb-gurobi-platform-a` being migrated away?

**A1 — NO. The migration note targets the VPP DISPATCHER domain, not the Gurobi platform.**

- The note's scope: *"The VPP Dispatcher domain uses CosmosDB with the MongoDB API"* →
  migrating to **MongoDB Atlas** then on-prem MongoDB.
  (A1: `vpp-cosmosdb-to-mongodb-migration.md:13-15`, `:28-29`; tags include `dispatcher`,
  related notes are `adr-core-layer-consolidated` / `vpp-solution-design-decisions`.)
- It says **nothing** about the Gurobi store. The Gurobi data store is a separate CosmosDB
  account `cosmosdb-gurobi-platform-a` with database `grb_rsm`/`grb_ts`, owned by the
  `gurobi-infrastructure` repo and the Gurobi Cluster Manager — a different domain/repo/team.
  (A1: `eneco-vpp-gurobi-cluster-architecture.md:24-27`, `:83-88`;
  `root-cause-analysis.md:14`, `:330`.)

**A2 (route impact)**: A Cosmos-side fix for the Gurobi RU alert (autoscale / higher
throughput / burst capacity) is **NOT made moot** by the Dispatcher migration. The two are
different systems. Do not assume "Cosmos is going away" as a reason to skip the Gurobi
capacity fix. *(Falsifier: a separate, Gurobi-specific migration note or ADR retiring
`cosmosdb-gurobi-platform-a` — none seen in the canon I read; if one exists it would flip
this. Resolving path: search the vault for a gurobi-specific migration/retirement note.)*

---

## Q6 — VERDICT: recurrence, escalation, or distinct sub-threshold-warning class?

**VERDICT: A DISTINCT WARNING-CLASS alert on the SAME underlying mechanism — most precisely,
the early-warning sibling that the March RCA recommended building. It is *not* a
like-for-like recurrence of the March 429 alert, and on the evidence in hand it is *not yet*
confirmed escalation to sustained 429 throttling.** (A2.)

**The discriminator that decides it** (single, observable):

> **Which metric fired, and is 429 rejection actually occurring?**
> - **429-count metric fired (TotalRequests/StatusCode=429 ≥ threshold)** → recurrence of
>   the March *throttling* class; rejection is happening; user work may be failing.
> - **NormalizedRUConsumption-average metric fired (and no concurrent 429 alert)** → the
>   *warning/saturation* class — RU pressure is high but rejection is not (yet)
>   confirmed. This is the June 15 case.

**Why "same mechanism, different class," not "new cause":**

- Same resource (`cosmosdb-gurobi-platform-a`), same RG, same ACC environment, same
  underlying structural enabler (100 RU/s, no autoscale, no shard key, throughput not in
  Terraform) — all unchanged since March per the architecture canon
  (A1: `eneco-vpp-gurobi-cluster-architecture.md:88`; `root-cause-analysis.md:155-173`,
  `:304-309`).
- The March *real fix* (autoscale) is **open** (Q2). The ceiling that produced March's 429s
  is still there, so the same ceiling producing a 77.67% average-RU warning in June is the
  **expected next reading of the same gauge**, not a new failure.

**Why "warning class," not "confirmed escalation":**

- June fired the *saturation* metric (avg 77.67%), which by design fires **before** 429s are
  guaranteed (the whole point of the March RCA's Change 2 early-warning alert,
  `root-cause-analysis.md:662-687`). An average of 77.67% over PT15M is consistent with the
  periodic-burst pattern (March periodic avg ≈ 39% over PT15M per `:672-674`) being somewhat
  hotter, OR with genuine sustained pressure — **the average alone cannot distinguish them.**
- To upgrade the verdict from "warning" to "escalation," check (coordinator's live lane,
  out of scope here): (a) is the companion 429 alert also firing? (b) is NormalizedRU
  *sustained* across consecutive windows vs spiking-and-falling (the periodic vs sustained
  split, `eneco-vpp-gurobi-cosmosdb-throttling-pattern.md:52-55`)? (c) is the baseline
  *between* spikes elevated (DEGRADED signal, `root-cause-analysis.md:900-909`)?

**Conditional route impacts (mapping the coordinator's stated branches):**

- *"March = 429-throttling AND fix never landed → same unfixed cause possibly worsening"* →
  **CONFIRMED on the "fix never landed" half** (Q2). The June warning at 77.67% is
  consistent with the same unfixed ceiling, and the avg-RU threshold being crossed at all is
  weak evidence of *worsening* baseline vs March's periodic ≈39% — **but the warning metric
  cannot prove worsening by itself.** Route: treat the autoscale/throughput fix as the still-
  outstanding real remediation, not a fresh investigation.
- *"March = same noisy warning classified self-resolve → strong prior June is expected
  noise"* → **PARTIALLY REJECTED.** March's noisy class was the *periodic-burst* pattern, but
  canon does NOT classify the persistent RU-exhaustion class as self-resolving auto-ack — the
  recognition digest puts it in the **"does not self-clear"** bucket
  (`eneco-oncall-recognition-week-2026-06-08.md:65`). The ONLY self-resolving Gurobi classes
  are (a) new-PROD-token-server noise (wrong env — June is ACC) and (b) CMC-upgrade reconnect
  storms (wrong window — prod upgrade is Jun 17, June 15 is ACC, pre-window). So the "expected
  noise / safe to ack" prior is **NOT supported** for this specific alert.
- *"Cosmos being migrated to Mongo → fix rec must account for it"* → **DOES NOT APPLY** to
  Gurobi (Q5). The migration is the Dispatcher domain. A Gurobi Cosmos fix is still worth it.

**Net recommendation to coordinator** (route, A2): Do NOT auto-ack as expected noise. Confirm
sustained-vs-periodic and 429-companion on the live plane; the standing remediation is the
March autoscale/throughput fix (still open), and escalation owner is **Nuno (fallback
#team-platform)**.

---

## Evidence Ledger

| # | Claim | Label | Source |
|---|---|---|---|
| 1 | March alert = `gurobi-cosmos-throttling-429-a`, TotalRequests/429, thr 20, PT5M, Sev2 | A1 | `rootly-alert-payload.json:7,28-51` |
| 2 | 24 real 429s in the firing window | A1 | `rootly-alert-payload.json:43`; `root-cause-analysis.md:23,34` |
| 3 | June alert = NormalizedRUConsumption Avg, thr 75%, PT15M (coordinator-supplied) | A3 | task context (June payload not read in this lane) |
| 4 | March RCA proposed a NormalizedRUConsumption "ru-saturation" Sev3/thr60/PT15M alert | A1 | `root-cause-analysis.md:742-761` |
| 5 | June alert is same-metric family as the proposal but Sev2/thr75 ≠ Sev3/thr60 | A2 | derived from #3+#4 |
| 6 | Real fix = autoscale ("the real fix"); burst capacity = "band-aid"; runbook sunset 2026-04-10 | A1 | `root-cause-analysis.md:585,590-603,802-842,934,1150` |
| 7 | Autoscale NOT recorded as landed; "re-check autoscale assumptions" | A1 | `eneco-vpp-gurobi-cosmosdb-throttling-pattern.md:83-87` |
| 8 | Throughput still not Terraform-managed (structural enabler persists) | A1 | `eneco-vpp-gurobi-cluster-architecture.md:88` |
| 9 | Persistent Gurobi/CosmosDB 429/RU = "open RU-exhaustion class — does not self-clear" → Nuno | A1 | `eneco-oncall-recognition-week-2026-06-08.md:65,115` |
| 10 | Self-resolve Gurobi classes = new PROD token server (post-06-02, PROD) and CMC-upgrade drain | A1 | `eneco-oncall-recognition-week-2026-06-08.md:64,67` |
| 11 | Prod OpenShift upgrade = 2026-06-17; ACC upgrades already done; out-of-window drain NOT expected | A1 | `eneco-oncall-recognition-week-2026-06-08.md:67,100` |
| 12 | Cosmos→Mongo migration = VPP DISPATCHER domain, not Gurobi | A1 | `vpp-cosmosdb-to-mongodb-migration.md:13-15,28-29` |
| 13 | Gurobi store is separate Cosmos account `cosmosdb-gurobi-platform-a` / `grb_rsm`/`grb_ts` | A1 | `eneco-vpp-gurobi-cluster-architecture.md:24-27,83-88`; `root-cause-analysis.md:14,330` |
| 14 | Periodic-burst avg RU over PT15M ≈ 39% in March (June 77.67% is higher) | A1 | `root-cause-analysis.md:672-674` |
| 15 | Autoscale-landed status not positively confirmable in this lane | A3[blocked] | requires live `az cosmosdb ... throughput show` (out of lane) |

## Blocked / Out-of-Lane (for coordinator's live plane)

- A3: Live current throughput type on hot collections (confirms autoscale open/landed).
- A3: Live June 15 alert payload + whether the 429 companion alert is also firing.
- A3: Sustained-vs-periodic shape of NormalizedRU around the June 15 firing window.
- A3: Vault search for any Gurobi-specific Cosmos retirement/migration note (none seen).
