---
title: "El Demoledor — adversarial demolition of PR-180313 RCA + recommended fix"
type: review
status: complete
task_id: 2026-07-19-002
agent: el-demoledor
adversarial_lane: correctness-of-recommendation
summary: Ranked break-attempts against the two-alert PromQL fix, the count>0 merge precondition, the no-destructive-state claim, the L11 cold-run, and unproven victory declarations. Verdict PROCEED-WITH-CHANGES.
timestamp: 2026-07-19
---

# El Demoledor — breaking the DispatcherOutputHealth fix

Target: `rca.md` L8 (§8a/§8b) + `synthesis-recommendation.md` Deliverables 1 & 2.
Win condition: destroy the *correctness* of the recommendation, not its prose.

The RCA is unusually honest (A1/A2/A3 labelled, probes named, "awaiting authorization"). That honesty is also the crack: it flags E10/E12/E13 as unverified, then ships a **concrete "most solid form"** whose safety depends on exactly those unverified facts. Below, ranked by prod blast radius.

---

## D1 — Absent-arm is a pager self-DoS if the metric is traffic-gated [PATTERN-MATCHED, HIGH]

**Severity Gate:** Exploitability HIGH (fires automatically every idle period) × Impact HIGH (permanent false CRITICAL storm in prod) × Confidence MED-HIGH (derived from the RCA's *own* stated mechanism) = **CRITICAL**.

**The break.** The RCA says in three places that the gauge is **activation-traffic-gated**: exec-summary "not produced by an idle dispatcher with no real mFRR activity"; L4 "it needs an actual activation to compute an output-health value"; E6 proves it is genuinely **absent** at idle (not a held/stale value) across every probed slot. mFRR is *Manual* FRR — TenneT activates it **intermittently, not continuously**. Therefore in ACC/prod, during every inter-activation idle window (> the 5m `for:`), `absent(dispatcher_output_health{...})` is true → `DispatcherOutputHealthAbsent` fires **CRITICAL on a perfectly healthy, merely-idle dispatcher**.

The recommendation builds an `absent()` deadman for a metric it simultaneously describes as only-emitted-during-activations. That is internally self-contradictory.

**Concrete trigger.** Metric emits during an activation → `count>0` precondition passes → absent arm merged → next idle gap > 5m in prod → page. Repeats every idle window, forever.

**Why the precondition doesn't catch it.** `count(...) > 0` is a **single-instant** check. It cannot distinguish "emits continuously once enabled (FF-gated)" from "emits only transiently during activations (traffic-gated)." The RCA's own confidence note admits the FF-vs-traffic question is unresolved — and the entire absent-arm viability rides on it.

**Corrective change.** The blocking precondition must prove **sustained/continuous emission at idle**, not `count>0` once. Replace with: `min_over_time(count(dispatcher_output_health{...})[6h:1m]) > 0` in the *target* env across a window that spans multiple idle periods. If the metric is confirmed traffic-gated (intermittent), the `absent()` deadman is **the wrong instrument entirely** — you cannot deadman-alert on a metric that legitimately disappears; you need an activation-scoped alert or a heartbeat the dispatcher emits unconditionally.

**Counter-hypothesis.** *Safe if* the gate is the feature flag (not traffic) and, once FF-on, the dispatcher republishes the gauge continuously even at idle. I favor the break because (a) the RCA states BOTH FF and traffic as candidate gates and E6 shows genuine absence at idle, (b) the precondition as written cannot discriminate the safe case from the fatal one. I would switch IF a healthy-env probe shows the gauge present continuously through a multi-hour idle window.

---

## D2 — `count>0 in a healthy env` proves nothing about the *target* env [PATTERN-MATCHED, HIGH]

**Severity Gate:** Exploitability HIGH × Impact HIGH (permanent false CRITICAL in prod) × Confidence HIGH (FF gating is established A2; flags are per-env) = **CRITICAL**.

**The break.** The precondition says confirm emission "in **a healthy env**." But the metric is **feature-flag-gated** (E10) and the **flag name is unknown** (E12, A3). Feature flags are per-environment. Confirming `count>0` in an FBE-with-FF-on or in ACC says **nothing** about prod, where the flag may be OFF. The prod file mirrors ACC when un-commented (synthesis L36) → the absent arm propagates to prod → if the prod FF is off, the metric is absent → **permanent false CRITICAL in prod**, i.e. precisely the self-DoS the RCA's headline line exists to prevent, merely relocated to the env boundary.

Worse: because E12 (flag name) is blocked, you **cannot even verify FF parity** across envs — you don't know what to check.

**Concrete trigger.** Confirm `count>0` in ACC → merge absent arm → un-comment/mirror to prod where FF is off → prod pages CRITICAL immediately and forever.

**Corrective change.** Precondition must be **per-target-env**: `count>0` (sustained, per D1) in ACC before merging to ACC's rule; independently in prod (or proven FF parity, which requires resolving E12 first) before un-commenting prod. Flag prod as the highest-risk deployment because it is the hardest to dry-run.

**Counter-hypothesis.** *Safe if* the FF is global (single store, all envs) so ACC-on ⇒ prod-on. I favor the break because the RCA never establishes the flag's scope (E12 blocked) and VPP FBE/App-Config topology (LL-036) shows per-slot/per-env config stores are the norm, not global. Switch IF the flag is shown to be a single cross-env toggle.

---

## D3 — `< 1` "robust to fractional" is inverted; the threshold is un-gated while the absent arm is gated [PATTERN-MATCHED, HIGH]

**Severity Gate:** Exploitability MED × Impact HIGH (near-constant CRITICAL if domain is [0,1]) × Confidence HIGH for the reasoning error, MED for the domain = **HIGH**.

**The break.** Synthesis L58-59 justifies `< 1` as "robust to **fractional**/negative gauge values." This is **backwards**. If `dispatcher_output_health` is a health **score/ratio in [0,1]** (fully plausible for an "output health" gauge — 1.0 = healthy, 0.6 = degraded), then `< 1` fires on **any** value below perfect — 0.99 pages CRITICAL → near-permanent false page. `< 1` is robust for integer-counts and for negatives, but **catastrophic** for exactly the fractional domain it claims to handle.

The deeper asymmetry: the RCA gates the **absent arm** on emission confirmation (E13) but does **not** gate the **threshold choice** on value-domain confirmation — even though a wrong threshold is the *same class* of pager self-DoS. E13 explicitly leaves "value domain (binary vs float)" unverified, yet `< 1` is shipped as "most solid."

**Concrete trigger.** Metric turns out to be a [0,1] health ratio → `max by(...)(health) < 1` is true whenever health < 1.0 → CRITICAL fires on any non-perfect scrape.

**Mitigating evidence (stated honestly):** the PR annotation "health **count** decreased to 0" leans toward an integer count where `< 1 ≡ == 0` and the choice is fine. So the *likely* domain is safe — but "likely" is not "verified," and the RCA elsewhere refuses to ship on "likely."

**Corrective change.** Add value-domain (E13) to the blocking precondition, symmetric with the absent gate: confirm the domain before committing `< 1`. If fractional [0,1], the threshold must be `== 0` / `<= 0` / a domain-appropriate floor, not `< 1`. Delete the "robust to fractional" justification — it is false.

**Counter-hypothesis.** *Safe if* the gauge is a non-negative integer count (PR annotation suggests it). I favor keeping the finding because the justification text is provably wrong regardless of actual domain, and the domain is unverified by the RCA's own E13. Switch to LOW only after E13 confirms integer-count.

---

## D4 — `max by(exported_job)` masks single-replica death and contradicts the L1 deadman framing; shipped as "most solid" [EXPLOIT-VERIFIED (PromQL semantics), MED-HIGH]

**Severity Gate:** Exploitability MED × Impact HIGH (missed page on a partial dispatcher outage) × Confidence HIGH (pure PromQL + internal contradiction) = **HIGH**.

**The break.** `max by(exported_job)(dispatcher_output_health{...}) < 1` fires only when the **maximum** health across all replicas is < 1 — i.e. only when **every** replica is unhealthy. If replica A = 1 (healthy) and replica B = 0 (dead), `max = 1`, `1 < 1` is false → **no page** while a dispatcher replica is dead. L1 explicitly frames this alert as a money-and-grid deadman where "a silent dispatcher is worse than a noisy one." `max` is the **most silent** aggregation possible — it directly contradicts the design philosophy the same document states.

The RCA relegates min/max to "a Core-team call" residual — but by shipping `max` as the concrete "most solid" recommendation, it **has made the call**, toward the least-safe option, while branding it most solid. That is declaring victory on an unresolved, safety-relevant decision.

Secondary: the stated *reason* for `max by(exported_job)` — "gives both arms the same label set so a present-0↔absent flap no longer resets the `for:` timer" — is imported from the **single-expression** analysis (FM2). In the **two-alert split**, the arms are separate alertnames with independent `for:` timers; there is no cross-arm flap to protect against. So the justification for `max by` in the two-alert form is a copy-paste from the wrong context; the aggregation's real (and un-discussed) effect there is replica-masking.

**Concrete trigger.** Metric has ≥2 replica series (E13 cardinality unverified); one replica hangs at 0, others at 1 → dispatcher is partially down, pager stays silent.

**Corrective change.** For a deadman, default to `min by(exported_job)(...) < 1` (any replica unhealthy pages), OR keep `max` only after Core explicitly accepts "all-replicas-down" semantics AND add the `count(...) < <expected>` partial-loss warning the RCA already mentions but leaves optional. Do not brand `max` "most solid" while E13 (cardinality) is unverified.

**Counter-hypothesis.** *Safe if* cardinality is exactly 1 series (max ≡ min ≡ raw). I favor the finding because E13 leaves cardinality unverified and the RCA still picks an aggregation whose only failure mode is silence — the one thing L1 forbids. Switch IF E13 confirms a single series, in which case drop `by(exported_job)` entirely.

---

## D5 — "Nothing destructively broken, nothing to roll back" is scoped to the YAML and ignores the procedure's side effects [THEORETICAL, MED-HIGH]

**Severity Gate:** Exploitability MED × Impact HIGH (real asset dispatch / cross-env contamination) × Confidence MED (depends on FBE isolation) = **HIGH**.

**The break.** The "no destructive state" claim is true for the *alert config*, but the **§8b procedure** contains three state-changing actions the claim silently covers:

- **D5a — "drive a (real or simulated) mFRR activation" (step 2).** The dispatcher's job (L2) is to "turn market activations into asset dispatch." Injecting an activation — even in Sandbox — can cause the dispatcher to **emit dispatch commands**. VPP Sandbox Kafka is **shared dev-test** (memory: vpp-agg-sb certs, leaf CN `vpp-dt`), so a "simulated" activation may publish onto topics consumed by *other* dev-test consumers, or (worst case) touch a real/shared asset-control path. "Nothing to roll back" never assessed this blast radius. **Corrective:** before driving activation, prove the FBE dispatcher's downstream is fully sandboxed (no shared Kafka topic to other consumers, no real asset-controller binding); prefer FF-enable-only over activation-injection to elicit the metric.

- **D5b — enable an unknown-scope feature flag (step 2).** E12 says the flag name/behavior is **unknown**. An unknown flag may gate more than metric emission (dispatch behavior, downstream calls). Enabling it **is** a state change requiring rollback (disable after). "Nothing to roll back" is false for this step. **Corrective:** identify flag scope before enabling; add an explicit "disable flag / restore slot state" teardown step.

- **D5c — "reuse a running slot" (step 1).** Each slot ↔ one branch ↔ one dev (E7). Deploying Julian's branch onto an occupied slot makes ArgoCD **sync away the current occupant's branch** — destroying a colleague's live FBE. **Corrective:** provision a fresh slot or get the current owner's consent; never silently commandeer.

**Counter-hypothesis.** *Safe if* Sandbox FBEs are hermetically isolated (no shared Kafka, no asset binding) and the flag is metric-only. I favor the finding because the RCA never establishes isolation and memory evidence shows Sandbox Kafka is shared dev-test. Switch IF FBE isolation is proven.

---

## D6 — L11 playbook is not cold-runnable: missing cluster auth + hardcoded ephemeral slot [PATTERN-MATCHED, MED]

**Severity Gate:** Exploitability HIGH (fresh on-call runs it verbatim) × Impact MED (playbook unusable, not prod damage) × Confidence HIGH = **MED**.

**The break — walked cold:**

- **D6a — no path to authenticate to `vpp-aks01-d`.** The playbook asserts `kubectl config current-context # must be vpp-aks01-d` but never says **how** to get that kubeconfig. A fresh on-call has no credentials for the Sandbox AKS cluster. The documented dev alias `enecotfvppmclogindev` (memory) is **MC dev Azure-CLI read-only — a different plane**, not Sandbox AKS. On-call trips at command 1. **Corrective:** prepend the exact `az aks get-credentials --resource-group <rg> --name vpp-aks01-d` (+ any kubelogin/AAD-group step).

- **D6b — hardcoded `jupiter`.** Every probe hardcodes `jupiter-monitoring` / `prometheus-kps-jupiter-prometheus-0`. FBEs are **ephemeral** (L3). By the next shift jupiter may not exist → "namespace/pod not found." No discovery step precedes the exec. **Corrective:** add a discovery step (`kubectl get ns | grep -- -monitoring`, then derive the pod) before any hardcoded exec; parameterize the slot.

- **D6c — ADO `az rest` has no auth precondition.** The first command uses opaque GUIDs and requires an authenticated `az` session with ADO access, unstated. Minor but a cold-start trip. **Corrective:** note the `az login` / ADO access requirement.

**Counter-hypothesis.** *Safe if* the on-call already has vpp-aks01-d in their kubeconfig and jupiter is pinned/long-lived. I favor the finding because the RCA's own L3 calls FBEs ephemeral and memory shows the documented alias is a different plane. This is a playbook-usability break, not a prod break — hence MED.

---

## D7 — Root cause "FF/traffic-gated" declared but a simpler competing hypothesis is not eliminated [THEORETICAL, MED]

**Severity Gate:** Exploitability MED × Impact MED (sends remediation down the wrong path) × Confidence MED = **MED**.

**The break.** The exec-summary declares the gauge "activation-traffic- and/or feature-flag-gated" (an A2 inference stated declaratively). But E6 probed slots running branches `main`, `1.2.feat`, `1.1.feat` — **none of them Julian's** `feature/820018-…`, which is the branch that *adds the metric*. A simpler, un-eliminated hypothesis: **the metric is absent because the emitting code is not in those branches at all.** "Across every build age" (E6) checks age, not whether the branch **contains the metric code**. If this is the cause, the entire FF/traffic narrative — and the FF-enabling step — is a wild goose chase; the only real requirement is deploying a branch that has the code.

The RCA's confidence note offers only ONE alternative (continuous emission → real bug) and misses this one.

**Corrective change.** Before committing to the FF/traffic story, eliminate the code-presence hypothesis: confirm the health-metric commit is an ancestor of the branch running in the probed slot(s), or probe a slot **running Julian's branch** (which requires step 1 anyway). Label the root cause A2-with-open-alternative until then.

**Counter-hypothesis.** *Safe if* the metric-emitting PR was merged upstream long before `main`/`1.2.feat`/`1.1.feat` diverged, so all probed branches contain the code. I favor keeping the finding because the RCA never shows the code is present in the probed branches — it infers gating from absence without ruling out non-deployment. Switch IF code-presence in a probed branch is demonstrated.

---

## SPECULATIVE OBSERVATIONS (not counted)

- **absent() keyed on an exact, space-containing, relabel-derived label.** `absent(dispatcher_output_health{exported_job="Activation mFRR"})` fires if the metric emits under any **variant** of that string (trailing space, casing, a relabel drift), because `exported_job` is honor-labels-derived (L3). Any drift → false absent CRITICAL even though the metric is live. No concrete drift observed, so SPECULATIVE. Worth considering `absent(dispatcher_output_health)` on name alone, or a stability check on the label.
- **`for: 5m` on the absent arm vs real deploy duration.** "Tolerates rolling deploys" is asserted, not measured. E9 shows activationmfrr startup is non-trivial (NullReferenceException in `AddInfrastructure` at boot). If a rolling deploy's metric-gap exceeds 5m, every deploy pages. Unverified assumption; measure the real gap.

---

## Redundancy / bias check

- **Root causes, not symptoms:** D1+D2 share the generator "the merge precondition (`count>0`, one env, one instant) is too weak to guarantee the absent arm is safe where it deploys." Kept separate because the corrective changes differ (sustained-emission vs per-env-parity) and both are independently prod-fatal. D3+D4 share "a concrete present-arm form was shipped despite E13 (domain+cardinality) unverified" — reported as two manifestations (threshold vs aggregation) with distinct fixes.
- **Severity honesty:** D6/D7 held at MED (usability / mis-direction, not prod damage) despite adversarial temptation to inflate. D5 is HIGH only because Sandbox Kafka is *shown* shared (memory), not theoretical.
- **Not manufactured:** `absent(...) == 1` template-forcing is **correct** (fires when absent, silent when present) — no finding. `(A==0) or (B==1)` precedence and mutual-exclusivity claims are **correct** — no finding. Operator-precedence and `avg_over_time`-empty analysis are **correct**. The diagnosis's A1 spine (defective `==0`, healthy pipeline, no slot on Julian's branch, no FBE loads the rule) survives intact.

## Meta-falsifier (self-attack)

- **Would I reject any finding if someone else presented it?** D3's domain risk leans on an unverified [0,1] hypothesis that the PR annotation ("count") argues against — so I split it: the *inverted-justification* half is HIGH-confidence and stands; the *domain-catastrophe* half is explicitly conditional. Kept, correctly bounded.
- **My unchallenged assumption:** I assumed mFRR activations are intermittent (basis for D1). mFRR = *Manual* FRR is on-demand, not continuous — this is domain-standard and the RCA's own L4 agrees ("needs an actual activation"). Assumption holds.
- **Strongest defense against my top finding (D1):** "the gate is the FF, and once FF-on the gauge is continuous." If true, D1 dissolves. But the RCA cannot currently assert this (E10/E12 unresolved), and the precondition can't test it — so D1 stands *as a gate on the precondition*, which is the actionable point regardless.
- Confirmed: D1, D2, D4, D5, D6. Bounded/conditional: D3, D7. Removed: none.

---

## VERDICT

**PROCEED-WITH-CHANGES.**

The diagnosis (defective `==0`, environmentally-gated metric, three walls to a green FBE test) and the *shape* of the fix (split present/absent, absent-awareness, gate-before-merge) survive demolition. What breaks is the **specific committed form and precondition**:

1. **Blocking (must fix before any merge):** precondition must prove **sustained emission in the target env** (D1) and **per-env/FF parity** (D2) — `count>0` once in "a healthy env" is insufficient and can reproduce the exact prod pager-DoS the RCA exists to prevent. If the metric is confirmed traffic-gated/intermittent, the `absent()` deadman is the wrong instrument.
2. **Blocking:** gate the **threshold and aggregation** on E13 (value domain + cardinality) symmetric with the absent gate; default deadman aggregation to `min`, not `max` (D3, D4). Delete the false "robust to fractional" justification.
3. **Before executing §8b:** assess activation-injection / FF-enable / slot-reuse side effects; "nothing to roll back" is false for the procedure (D5).
4. **Before handoff:** make L11 cold-runnable — add cluster auth and slot discovery (D6).
5. **Tighten the root-cause claim:** eliminate "code-not-in-branch" before committing to the FF/traffic narrative (D7).

Not REJECT: nothing here is destructive-to-data, and the RCA is correctly parked "awaiting authorization." Not PROCEED-AS-WRITTEN: the recommended form can page-storm prod under the RCA's own stated mechanism.

---
*El Demoledor: proving resilience through destruction.*
