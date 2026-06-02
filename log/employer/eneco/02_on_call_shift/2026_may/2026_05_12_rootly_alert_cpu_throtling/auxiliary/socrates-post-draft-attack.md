---
task_id: 2026-05-11-003
agent: socrates-contrarian-post-draft
status: pending_review
summary: "Draft survived the framing attacks at LEDGER LEVEL but smuggled rationalizations back in via (a) E12 HANDOVER label without a Recommended-Next-Action handoff, (b) L8/L11 hypothesis nesting that hides H-A inside H-B, (c) hardcoded pod name + truncated TSV + missing AlertmanagerConfig probe, and (d) an unreconciled `triggered` vs `acknowledged` contradiction between the two cited Rootly sources. PROCEED-WITH-CHANGES."
---

# Socrates — post-draft attack on `rca.md`

Mandate: find what the author rationalized THROUGH the writing. Pre-RCA pair surfaced 9 faults; this pass looks for what survived the absorption.

Sectioning is the 10 checks from dispatch. Verdicts terse; line/section citations precise.

---

## Check 1 — A1 FACT smuggled as A2/A3 (or vice versa)

**FAIL.**

**1a — E1 silently elides a source contradiction.** rca.md `L7 row 6` and `Evidence Ledger E1` both cite the Rootly alert. `rootly-alert-meta.json:7` records `"status": "acknowledged"`. `rootly-alert-raw-decoded.txt:4` records `STATUS: triggered`. **Both are antecedents of the RCA**, both from the same Rootly fetch, both cited as A1. The RCA reports `status: acknowledged` (L1 banner line 147, L7 row 6) and proceeds. **The decoded-text vs meta-JSON disagreement is unreconciled.** Either the decoder strips state-change events and the meta capture happened later, or the two files were captured at different moments — but the RCA treats `acknowledged` as A1 fact. Until the source disagreement is resolved, status is A2 at best.

**Impact**: this matters operationally because L11 Step 1 decision rule (line 665) says *"if status is `triggered`, you are first responder; if `acknowledged`, someone is on it and you should coordinate"* — i.e. the next-shift's next ACTION turns on this bit. The RCA hands them an unreconciled bit and calls it A1.

**1b — E6 class-vs-confidence-math contradiction.** Ledger row E6 is labeled **A2** (line 952). Confidence math (line 971): `A1_confirmed = 7 (E1, E2, E3, E4, E5, E6 partial, E7)`. The class column says A2; the math counts it "A1 partial." There is no defined "A1 partial" class at the top of the document. **Self-contradiction inside the Evidence Ledger and Confidence pair.**

**1c — E12 is not a probeable claim and inflates the denominator.** E12 (line 958) is the *Phase 6D verdict for this intake* — a routing decision, not an evidence claim. It is then counted in `A3_blocked = 5` (line 973), pushing the denominator from 16 to 17 and raising `contradictions_open` from 3 to 4. A routing-decision row does not belong in the A1/A2/A3 evidence accounting; it is a meta-decision over the evidence. Category error.

**1d — E11 ("Team-calibrated Low urgency") demotion is correct but the demotion's REFERENT is still imported elsewhere.** E11 inverts the calibration claim to A3. Good. But L10 Lesson 1 still says *"team-level urgency calibration belongs in a team runbook entry tied to specific rules"* — fine — while L1 (lines 162–167) writes *"What IS calibrated by the team: the Alertmanager receiver ... routes this rule to the Rootly group `trade-platform-on-call` ..."* and labels that as the **actual** calibration. **But the RCA has not probed live whether that AlertmanagerConfig CR routes THIS rule (CPUThrottlingHigh) specifically, or whether the `severity: info` Prometheus label is the routing key.** The "AlertmanagerConfig routes this rule" claim is itself unprobed-against-live. It is A2 inferred from the `groupKey` + `receiver` fields in the payload — fine if labeled A2, but L1 reads as A1.

---

## Check 2 — Cross-section incoherence

**FAIL — three independent incoherences.**

**2a — L8 H-A fix sizing references the WRONG L9 row.** L8 row 1 (line 457):

> "H-A undersized CPU (post-migration regression) | Add `spec.resources.limits.cpu` to the CR (target informed by L9 H-B time series — at least 2× steady-state peak)..."

L9 H-B (lines 510–516) is the **memory** working-set time series — `container_memory_working_set_bytes`. The CPU-sizing time series is not in H-B at all. CPU usage probe sits in L11 Step 6's `process_cpu_seconds_total` (line 815) or L12 §3's `oc adm top pod` (line 912). **L8 tells the reader to size CPU using a memory probe.** Either the cross-reference is wrong, or H-B should be expanded to a memory+CPU joint probe; the current text is incoherent.

**2b — Hypothesis independence claim contradicts mechanism stated in L4.** L9 "Adjudication" (line 556) says *"Run all four probes in any order; they are independent."* But L4 line 322-324 explicitly says CPU pressure on a Go runtime is reachable BOTH from a CPU-limit-too-tight path AND from a memory-pressure-induced-GC path. Sherlock D-ALT-B (referenced in absorption map row "Socrates F1.3/F3.1") makes the same point. **H-A and H-B are NOT independent — H-A's symptom (high throttled-period ratio) can be CAUSED by H-B's mechanism (memory → GC → CPU burst against a tight limit).** The 4-hypothesis framing presents them as competing peers; the L4 mechanism makes one a possible consequence of the other. Cross-section conflict between L4 and L9.

**2c — L11 Step 5 hardcodes a pod-name suffix that may not exist when this RCA is replayed.** Line 793: `oc -n eneco-vpp describe pod opentelemetry-collector-collector-566b6bd96-2htph`. ReplicaSet hash `566b6bd96` and pod suffix `2htph` are point-in-time. **If the pod restarted (likely given 4 memory firings + a CPU firing — restart is part of the failure mode being discussed), the next-shift will get `Error from server (NotFound)`.** No prior step lists `oc get pods -l app.kubernetes.io/instance=opentelemetry-collector` to discover the live pod name. L12 §3 (line 912) uses the label selector correctly; L11 Step 5 does not. Internal inconsistency between the two playbook surfaces.

---

## Check 3 — L11 command without prose rationale

**NEEDS-WORK.**

Audit of L11 steps 1-8 against the five required fields (question / authority / fields / expected output / decision rule / principle / freshness probe):

- Step 1 (line 646): all present. PASS.
- Step 2 (line 678): all present. PASS.
- Step 3 (line 708): **missing "Fields selected" and "Expected output"** — the step has Question + "Why this API" + Decision rule + Principle + Freshness probe, but no expected-output prose. The bash block ends `| @tsv` and the reader has to infer "you get a TSV of short_id+time+summary." Compare Step 1 (line 660), which explicitly enumerates the JSON fields. Step 3 truncates the schema.
- Step 4 (line 730): all present. PASS, but see Check 7 below for the broken freshness assumption.
- Step 5 (line 772): all present, but the bash block at line 793 hardcodes the pod name (see 2c). The Decision Rule references "observed peak usage from Prometheus" — without a back-reference to the Step that gets peak CPU. (Step 6 is memory-only.)
- Step 6 (line 797): present, but Decision Rule and Principle conflate "memory upstream" (H-B) with "trend > single-point" (Lesson 2). Two different reasoning chains in one Decision Rule cell; the reader has to disentangle.
- Step 7 (line 822): all present. PASS.
- Step 8 (line 846): all present. PASS.

**Most damaging gap: Step 3 missing expected-output schema.** A cold reader running it sees a raw TSV and has to guess what the columns are. Fix: add `Fields selected: short_id, created_at, summary` and `Expected output: ≤20 rows, one per alert this pod fired across all rule names`.

---

## Check 4 — Inherited claim still labeled FACT without in-session probe

**FAIL.**

**4a — E2 "Rule's threshold is 25%"** (line 948) cites the generatorURL PromQL in `rootly-alert-payload.json`. **The 25% IS in the PromQL** — that's confirmed. But the corpus §2 (line 64) extended this to *"Eneco has NOT overridden this threshold in any local PrometheusRule (... A1 (confirmed by grep across all clones))."* The RCA L1 line 159 absorbs this: *"the chart author's opinion about CFS throttling at 25% threshold, not Eneco's."* That conclusion requires proving negative coverage across **deployed** PrometheusRule CRs, which the corpus admits was a clone-grep, not a live `oc get prometheusrule -A` probe. Socrates pre-attack F1.2 made this point. The RCA L1 still asserts "this is the chart's default, not an Eneco override" with the air of A1, while the underlying probe is "grep across stale local clones." **Demote in L1, or flag explicitly that the "not overridden" claim is A2 from clones.**

**4b — E7 pre-migration `cpu: 256m, memory: 1Gi`** (line 953) cites `values.yaml:220-223` in the local clone — and the local clone is `2025-11-18`, six months stale. The RCA L2 acknowledges staleness at line 195. **But E7 is marked A1 confirmed.** A stale-clone grep is A2 at best for any claim about what the file says NOW; only if the chart is `Eneco.HelmCharts/opentelemetry-collector` AND it's been frozen since 2025-11-18 (Sherlock's note at line 302–309 of antecedent: "this caveat applies to my attack and equally to your diagnosis") could E7 stand as A1. The RCA does NOT explicitly assert chart freeze; the staleness caveat is in L2 (line 195) but E7's class column doesn't carry it. **E7 should be A2-INFER-from-stale-clone, not A1.** Same applies to any claim about the FBE-chart's CR content (E9 already demoted to A3 — good — but E7 is the same probe class).

**4c — `mode: ENRICH` frontmatter (line 10) vs E12 "HANDOVER per skill's own rule."** Inconsistent labels at the topmost level. Either the mode is ENRICH and E12's HANDOVER inversion is rhetorical, or HANDOVER is real and frontmatter should be `mode: HANDOVER`. (See Check 6 below.)

---

## Check 5 — Walk L11 cold (without L1-L10)

**FAIL — Step 4 alone leaves the reader unable to act on a hypothesis-confirmation, and Step 5 has the pod-name freshness bug.**

Imagine you are reading L11 for the first time, in 5 minutes, at 3 AM.

Step 1: produces alert state. Good.

Step 2: produces 30-day history. Decision rule says "≥10 firings... rule is 'known noisy in this namespace'." **But the TSV at line 950 (E4) is exactly 30 rows because `page[size]=30` truncates.** The decision rule doesn't tell the reader to check whether the result is paginated. If today's `eneco-vpp` namespace has >30 firings in 30d (which it does — 27 assetplanning + 2 integration-tests + 1 otc + the truncation), the reader gets a single page and may conclude "exactly 30, just at the threshold" when the real count is higher. **Silent pagination failure.** Add: `# warn if rows == 30; page size may truncate`.

Step 3: produces pod history. Good, but see 3 above about missing expected-output schema.

Step 4: produces the running CR. Decision rules are clear. **But what happens if `oc whoami --show-server` returns the wrong cluster?** L11 line 765 says *"Expected: 'https://api.eneco-vpp-dev.ceap.nl:6443' or equivalent"* — no instruction for the wrong-server case. The cold reader runs `oc login` how? Against which IDP? Project memory note has the alias `enecotfvppmclogindev` (read-only dev MC env) — **the alias is not in L11 or L12**. A cold reader has no way to know that alias exists.

Step 5: pod-name hardcoded (see 2c). Cold reader will hit NotFound and not know to use the label selector. L11 should lead with: `POD=$(oc -n eneco-vpp get pods -l app.kubernetes.io/instance=opentelemetry-collector -o jsonpath='{.items[0].metadata.name}')`, then describe `$POD`.

Step 6: PromQL queries with `thanos-querier...` URL hardcoded. **No instruction for "what if thanos-querier returns 401/403?"** The OpenShift token retrieval step (`oc whoami -t`, `-H "Authorization: Bearer ..."`) is missing. The cold reader has the URL but not the auth.

Step 7: same auth gap as Step 6.

Step 8: `oc -n openshift-gitops get applications.argoproj.io` — what if the cluster's ArgoCD lives elsewhere (some clusters use `argocd` or `gitops` namespace)? Line 867 says *"(commonly openshift-gitops)"* — good hedge, but the cold reader still doesn't know how to find the actual namespace. Add: `oc get applications.argoproj.io -A | grep -i opentelemetry`.

**The cold-walk reveals: L11 assumes the reader already knows the cluster, the auth, the alias, the pod-name lookup pattern, and how to detect API pagination. The earlier RCA sections never establish any of those preconditions.**

---

## Check 6 — Phase 6D HANDOVER framing: real or rationalized?

**FAIL — the HANDOVER inversion is rhetorical, not structural.**

Socrates F6 demanded: *"The defensible route: write the RCA to the user's named path AND name `eneco-oncall-intake-enrich` as the recommended next-skill in the RCA's 'Recommended next action' section."*

The RCA's response (E12, line 958):

> "the RCA encapsulates enrich's playbook in L11/L12, making the named-path deliverable consistent with HANDOVER framing"

**Search the rendered RCA for `eneco-oncall-intake-enrich`** — it does NOT appear anywhere in L1–L12, L11–L12 one-pager, or the Lessons. **It DOES appear in the Adversarial review log absorption map (line 1025) referencing the Socrates F6 finding — i.e. inside the meta section, not in the deliverable.** The next-shift on-call reading L1–L12 has no idea that "Recommended next action: invoke `eneco-oncall-intake-enrich` if H-A or H-D confirms" was the F6-honoring move. 

Also: frontmatter `mode: ENRICH` (line 10) versus E12 `HANDOVER`. If the document's own classification is HANDOVER, the frontmatter mode should be `HANDOVER` (or the skill's equivalent) — not `ENRICH`. The author has labeled the artifact ENRICH while the verdict cell says HANDOVER. **The label/verdict mismatch IS the rationalization F6 named.**

What "real HANDOVER" would have looked like:
1. Frontmatter `mode: HANDOVER` or equivalent.
2. A "Recommended next action" subsection at the top of L8 or in a new "L13 Handover" section, naming `eneco-oncall-intake-enrich` as the next skill, with the entry conditions (H-A or H-D confirmed → enrich PR track; H-B confirmed → telemetry-volume investigation track; H-C confirmed → rule-exclusion PR track).
3. L12 §5 "ESCALATION" (line 924) including the line `□ If H-A or H-D confirmed AND a PR is appropriate ⇒ invoke skill 'eneco-oncall-intake-enrich' for fix track`.

None of those are present. **The HANDOVER claim in E12 is a label change without a structural change. F6 survives.**

---

## Check 7 — Local-clone staleness applied consistently?

**NEEDS-WORK.**

The RCA does flag staleness at L2 line 195 (*"my local clone of `myriad-vpp/*` is dated 2025-11-18 — 6 months stale relative to the alert"*). But the staleness is applied **selectively**:

| File-derived claim | Class given | Should be |
|---|---|---|
| E7: pre-migration `cpu: 256m, memory: 1Gi` from `Eneco.HelmCharts/opentelemetry-collector/values.yaml` | A1 (line 953) | **A2** (stale clone; no chart-freeze guarantee) |
| E9: FBE chart CR is the running source | demoted to A3 (line 955) — good | A3 ✓ |
| L2 row #1 "Legacy Helm chart container name would be `{{ .Chart.Name }}` = `opentelemetry-collector`, NOT `otc-container`" | Implicit A1 | **A2** (stale clone) |
| L2 row #2 "`eneco-vpp` is not in the active-environments list" | Implicit A1 (Sherlock §0 cited) | **A2** (stale clone; FBE active-environments list could have changed in 6mo) |
| L5 line 354–356: legacy chart's `cpu: 256m` and "no `requests:` block" | A1 from local clone | **A2** |
| E11 vendor stock description string match | A3 — good | A3 ✓ |

**The rule the RCA implicitly follows: stale → A3 only for claims that contradict the author's diagnosis** (E9, E11). **Stale → A1 still** for claims that support it (E7, L5 pre-migration baseline). This is selective application of the staleness discount. Socrates F1.1/F3.3 raised the migration-regression hypothesis exactly because the pre-migration `cpu: 256m` value was load-bearing; if that value is stale-A2 rather than A1, **H-A's strength as a hypothesis drops** because the baseline it would regress FROM is itself unprobed-against-current-state.

---

## Check 8 — H-A built on a foundation the RCA has disowned?

**FAIL.**

H-A (L9 line 486) reads: *"Undersized CPU budget (post-migration regression)."* The "regression" framing requires (a) a pre-migration baseline with explicit resources, and (b) a post-migration state without them. The RCA:

- (a) is sourced from `Eneco.HelmCharts/opentelemetry-collector/values.yaml:220-223` (stale clone — see Check 7).
- (b) is sourced from the FBE chart's CR (E9, demoted to A3 because "name-match is not deployment proof").

**The RCA explicitly disowns (b) at E9** but then continues to use it as the implied "current state" in H-A's title "(post-migration regression)." The L5 text on lines 364–367 partly hedges: *"if the running CR omits `spec.resources`, the migration removed the explicit resource budget. ... But we cannot confirm this until the live probe runs."* — Good. But the HYPOTHESIS NAME in L8 (line 457) and L9 (line 486) and L12 §4 (line 920) all carry "(post-migration regression)" without "[A3]" or "[hypothesis]" qualification. **The label asserts the regression while the prose disclaims it.**

Fix: rename the H-A hypothesis to "Undersized CPU budget (regression vs. legacy chart suspected, unverified)" or just "Undersized CPU budget" without the migration framing. The migration story belongs in the *explanation* of why H-A is plausible, not in the hypothesis NAME, which becomes load-bearing in the playbook tables.

---

## Check 9 — H-A through H-D as competing peers — really independent?

**FAIL.**

Already partly raised in Check 2b. Expanding:

- **H-A (undersized CPU)** = proximate cause: limit too tight relative to demand.
- **H-B (memory upstream)** = root cause: memory pressure forces GC, GC burns CPU, CPU runs into limit. **If H-B is true, H-A is the SYMPTOM, not a peer.** Fixing H-A (raising CPU limit) without addressing H-B leaves the memory leak/growth unaddressed — and H-B will resurface as a memory alert.
- **H-C (rule mis-calibrated)** = independent of A, B, D (it's a question about the threshold's signal:noise, not about this pod's behavior).
- **H-D (debug verbose)** = proximate cause: debug exporter burns CPU. **Could co-cause with H-A** (the debug exporter creates the demand that H-A's tight limit can't handle). Also **could co-cause with H-B** (the debug exporter heap allocations contribute to memory growth).

**The L9 adjudication line** (line 556): *"Run all four probes in any order; they are independent."* — wrong. The PROBES are independent (they fetch different surfaces), but the HYPOTHESES are not. A reader running all four probes can confirm H-A AND H-D AND H-B and not know which is causal.

Last paragraph of L9 (line 558) does say: *"If two or more are confirmed simultaneously, treat them as co-contributing and fix the cheapest one (typically H-D) first while planning the others."* — this acknowledges co-occurrence but still misses the **nesting** structure. Cheapest-first is an action heuristic; it doesn't repair the diagnosis. Fix: in L9 add a brief "hypothesis dependency graph" showing H-B → H-A as a possible chain, H-D → H-A as another, H-C as orthogonal. Then the adjudication rule becomes "if H-B confirms, treat H-A's confirmation as secondary; if H-D confirms, fix it first because it's cheap; if H-C confirms cluster-wide, treat THIS pod's alert as noise even if H-A also confirms."

---

## Check 10 — L12 cold-execute (one-pager standalone)

**FAIL — three specific blockers for a reader who hasn't read L1-L10.**

Imagine the next-shift opens L12 (lines 880–939) cold.

**10a — `oc whoami --show-server` decision rule.** Line 910 says `oc whoami --show-server   # confirm dev cluster`. **Confirm against what?** Cold reader doesn't know the dev cluster's API URL. L11 Step 4 line 765 has it (`https://api.eneco-vpp-dev.ceap.nl:6443`), L12 §3 does not cross-reference. Also: what to do if it returns staging/prod by mistake? Project-memory alias `enecotfvppmclogindev` isn't named.

**10b — Ack vs coordinate guidance.** L12 §1 line 888 says `Status (acknowledged ⇒ coordinate; triggered ⇒ first responder)`. Good — but no instruction on HOW to coordinate. "Check #trade-platform-on-call for prior thread" appears in §2 line 899 but only conditioned on "≥2 firings on otc-container in last 30 days." If today's firing is acknowledged and there is no prior thread, the reader has no guidance. Add: `if acknowledged but no prior thread, post in #trade-platform-on-call asking who acked and what they found`.

**10c — Escalation paths not specific to hypothesis.** L12 §5 (line 924) has four bullets but none names *who* to escalate to. "Platform VPP" appears once (line 928) but isn't mapped to a Slack channel, owner alias, or escalation policy ID. L8 row 1 (line 457) says fix PR target for H-A is "the unmapped repo (4); ArgoCD app: also unmapped" — so on H-A confirm, the on-call has to run L11 Step 8 to find the GitOps owner BEFORE they can escalate. L12 §4 (line 920) just says "Bring the resource budget back" — no pointer to Step 8. The reader confirming H-A has no idea where to file the PR or who to ping.

**10d — Bonus: L12 §6 "POST-INVESTIGATION"** says `Update Rootly alert comment with the discriminator outputs (so next-shift inherits the work)` — but there is no CLI command for "update Rootly alert comment." The reader has to guess (web UI? `rootly-api.sh PATCH /v1/alerts/...`?). Add the command or the URL pattern.

---

## Cross-check observations (not in the 10 dispatch checks but load-bearing)

**X1 — L3 has a residual draft artifact.** Line 265: *"`Otel-Collector-Migration.md` — sorry, wrong path; the canonical reference is..."* — the *"sorry, wrong path"* apology was left in the published artifact. A `status: review` document should not carry editorial false-starts in the rendered prose.

**X2 — The team-routing claim in L1 is itself unprobed-against-live.** L1 lines 162–167 cite `eneco-vpp/alertmanagerconfig/rootly-trade-platform` as the team's actual calibration. This is the `receiver` field in `rootly-alert-payload.json:40` and `groupKey` line 13 of `rootly-alert-raw-decoded.txt`. **What the team has actually calibrated is the routing config FILE/CR** — the RCA does not cite a live `oc get alertmanagerconfig -n eneco-vpp rootly-trade-platform -o yaml` or the source file. This is A2 inferred from the alert payload, not A1 from the source-of-truth. L1 reads it as A1.

**X3 — The `acknowledged-by-whom` gap is named but never converted to a probe step.** Socrates F3.2 demanded the engagement metadata. The RCA L7 row 6 acknowledges the gap ("who/when not surfaced without `oc`-equivalent Rootly audit log probe") but L11 has NO step for it. Rootly v1 API has `/alerts/{id}/timeline` or audit-event endpoints (verify against Rootly skill docs); the RCA should add Step 1.5: "Who acknowledged this alert, when, and what did they say?" — load-bearing for first-responder routing (Check 10b above).

---

## Verdict

**PROCEED-WITH-CHANGES.**

The RCA is structurally sound and the headline framing inversions (E9, E10, E11) DID land — those are real absorptions, not rationalizations. But the post-draft pass has found that:

- The HANDOVER inversion is **rhetorical only** (Check 6) — no structural handoff to `eneco-oncall-intake-enrich`, no frontmatter change, no L12 entry.
- The Evidence Ledger has **internal contradictions** (Check 1: E1 source disagreement, E6 class-vs-math mismatch, E12 mis-categorized).
- The L11 cold-start playbook is **not actually cold-startable** (Check 5, Check 10): hardcoded pod name, missing pagination guard, missing auth, missing cluster-login alias, missing AlertmanagerConfig probe, missing Rootly-engagement probe.
- H-A is **named after a regression hypothesis that the RCA has explicitly disowned** (Check 8); the label is doing work the prose disclaims.
- The 4 hypotheses are **nested, not peer** (Check 9); the adjudication rule misses this.

### Must-fix before promotion to `status: complete`:

1. **(Check 6)** Add a "Recommended next action" subsection that names `eneco-oncall-intake-enrich` as the next skill, with entry conditions per confirmed hypothesis. Reconcile frontmatter `mode:` field with HANDOVER verdict.
2. **(Check 1a)** Reconcile the `triggered` vs `acknowledged` source disagreement, or demote E1 status-bit to A2 with an explicit note.
3. **(Check 1b, 1c)** Fix E6 class-vs-math contradiction; remove E12 from the A3 count (it is a verdict, not a probeable claim) and recompute confidence.
4. **(Check 2a)** Fix L8 H-A cross-reference: CPU sizing time series ≠ L9 H-B (which is memory). Cite L11 Step 6 process_cpu / L12 §3 `oc adm top pod` instead, OR expand H-B to memory+CPU.
5. **(Check 2c / Check 5 Step 5)** Replace hardcoded pod name in L11 Step 5 with label-selector lookup; same for any other hardcoded suffix.
6. **(Check 5 Step 2)** Add pagination guard to L11 Step 2 (warn if rows == 30, raise page[size] or page through).
7. **(Check 5 Steps 4/6/7)** Add cluster-login alias guidance (project memory: `enecotfvppmclogindev` for dev) and auth-token retrieval for thanos-querier (`oc whoami -t`).
8. **(Check 8)** Rename H-A to remove "(post-migration regression)" framing from the label, or qualify it as "[suspected, unverified]" inline at every L8/L9/L12 occurrence.
9. **(Check 9)** Add the hypothesis-dependency note to L9 ("H-B can cause H-A; H-D can cause H-A; H-C is orthogonal") and update the adjudication rule accordingly.
10. **(Check 10c, X3)** Add explicit escalation owners (Platform VPP Slack channel, ArgoCD-app probe ordering) to L12 §5; add a Step 1.5 in L11 for "who acknowledged."
11. **(Check 4a/4b, 7)** Apply staleness discount consistently: E7 → A2; L2 file-claims about chart container names and active-environments → A2.
12. **(X1)** Strike the "sorry, wrong path" editorial fragment from L3 line 265.

### Should-fix (not blockers but visible to a careful reader):

- (Check 3) L11 Step 3 missing expected-output schema row.
- (Check 9 closing) "Cheapest first (typically H-D)" — H-D being "cheapest" assumes the operator's reconciliation path is unblocked; the RCA hasn't probed that.
- (X2) L1 AlertmanagerConfig calibration claim should be labeled A2 from payload, not A1.

### Not blockers (the absorption did its job):

- E9, E10, E11 inversions are real (LEDGER and prose both inverted).
- The four-hypothesis frame survived even though the peer-vs-nested taxonomy is wrong — that is a structure issue, not an evidence issue.
- The "Vendor stock label is not team calibration" lesson IS reusable (the rephrase test passes).
- The PromQL reading and pod-naming-convention decode are accurate.

**The work to clear PROCEED-AS-WRITTEN is roughly 12 specific edits. Most are 1-3 line changes. None require new probes — they are coherence and labeling fixes to material the RCA already carries.**

---

## Self-skepticism (FACT/INFER/UNVERIFIED for THIS attack)

- Check 1a (triggered vs acknowledged): **A1** — both source files cited and read; the disagreement is visible.
- Check 1b (E6 ledger/math mismatch): **A1** — line numbers cited; arithmetic is direct.
- Check 1c (E12 mis-categorized as A3_blocked): **A2** — argued from the meaning of A3 ("blocked by probe"); a routing verdict is not probeable.
- Check 2a (L8 H-A → L9 H-B wrong cross-ref): **A1** — both sections read; H-B is unambiguously memory-only.
- Check 2b/9 (hypothesis nesting): **A2** — argued from L4's mechanism plus general Go-runtime knowledge; could be refuted if H-B's memory probe shows no monotonic trend, but the nesting risk remains regardless.
- Check 2c/5 (hardcoded pod name): **A1** — line 793 cited; pod restart possibility is A2 but the freshness bug is independent of whether the restart actually happened.
- Check 4a (Eneco-not-overridden claim): **A2** — argued from corpus §2's "grep across all clones" language; could be refuted by a live `oc get prometheusrule -A` returning no override.
- Check 6 (HANDOVER rhetorical only): **A1** — full-document search for "eneco-oncall-intake-enrich" returns only the absorption-map row, not the deliverable; frontmatter `mode: ENRICH` is line 10.
- Check 8 (H-A built on disowned foundation): **A1** — E9 is explicitly demoted to A3; H-A name explicitly carries "(post-migration regression)."
- Check 10c (escalation owners not named): **A1** — L12 §5 cited verbatim.
- X1 (sorry-wrong-path artifact): **A1** — line 265 cited.

If any of these falsifies (e.g. a fresh read of the RCA reveals I missed a "Recommended next action" subsection), the corresponding check retires. The biggest risk in my attack is **over-counting nominal contradictions** (E1's triggered/acked disagreement could be a captured state transition, not a contradiction — that is one Rootly API call away from clarifying). If a probe shows that, Check 1a downgrades from FAIL to NEEDS-WORK.

[INFER until coordinator source-verifies] My attack is INFER input to the synthesis until the coordinator re-checks the line citations and the absorption claim.
