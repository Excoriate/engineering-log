---
task_id: 2026-04-26-002
agent: claude-opus-4-7
status: complete
summary: RCA delivery plan — write structured artifact, dispatch socrates-contrarian for adversarial review, run all falsifiers, deliver into shift_alerts_summary.
---

# Phase 5 — Plan

## Phase 4 → 5 belief delta

- **Most wrong at Phase 1**: I anchored on the mFRR/Service-Bus parent-task context and listed Service Bus as H1. The alert was unrelated — Key Vault `ServiceApiLatency` on an idle bootstrap KV.
- **Hypotheses now**: H2 CONFIRMED; H1, H3 ELIMINATED (E8).
- **Verify Strategy Delta**: F1-F6 acceptance criteria unchanged, but F4 (IaC reconciliation) source moved from local `MC-VPP-Infrastructure/main` to upstream CCoE `terraform-azure-keyvault`. This **changes the recommendation surface** — fix is module-owner work, not consumer-repo work, and the impact is multi-product/multi-env (every consumer of `terraform-bootstrap` inherits the same hardcoded threshold).
- **CRUBVG re-score**: C 1→1 (still cross-subsystem, but now confirmed cross-product via shared module — borderline 1/2; staying at 1 for blast-radius purposes), R unchanged 0, U 2→0 (mechanism fully resolved), B 1→1 (still single-resource alert; multi-product implication is a recommendation, not active blast), V 1→0 (deterministic via az + cli), G 1→0 (canonical reconciliation done at file:line). New score = 2 + 1 (G≥1 bonus does not apply since G=0). Phase-5 work is shorter than full ≥4 ceremony but full structure remains because of the cross-module recommendation.

## Backward chain

End-state: a single RCA markdown file in `shift_alerts_summary/2026-April (20-26)/` that an on-call engineer can read in <5 minutes, act on (resolve the alert), and use as the citation when filing the upstream module fix.

Required pre-conditions:
1. Adversarial reviewer (socrates-contrarian) has stress-tested the RCA with a distinct win condition ("break the RCA — find a hypothesis incorrectly closed, or a load-bearing claim unfalsified"). Receipts in verification artifact.
2. All Verification Strategy falsifiers F1-F7 PASS (or have explicit residual-risk if PARTIAL).
3. RCA file lives at the user-named directory; manifest records the external write.
4. Cross-link to evidence under `$T_DIR/context/` for any reader who wants raw payload.

## Steps

### S1 — Spec the RCA artifact (Phase 6)

- **Objective**: Produce `$T_DIR/specs/rca-spec.md` defining the RCA contract (sections, frontmatter, evidence anchors, FACT/INFER labelling, residual-risk format).
- **Acceptance**: spec file exists with `## Sections`, `## Front-matter`, `## Evidence Citation Style`, `## Hypothesis Ledger Format`, `## Recommended Action Format`, `## Residual Risk Format`.
- **Falsifier**: spec must say what the RCA must NOT contain (no remediation IaC, no Slack auto-send, no incident-creation guidance).
- **Route premises**: (a) the RCA is for human on-call consumption, not machine ingestion; (b) the recommendation has two layers (immediate operator action + upstream module fix); (c) evidence anchors live as relative file paths under `$T_DIR/context/`. If (c) is falsified by user moving evidence later, RCA still works because evidence was inlined into the RCA itself, not just linked.
- **Visual reasoning**: not needed (≤3 components: RCA file, evidence file, on-call reader).

### S2 — Author the RCA at the external destination (Phase 7)

- **Objective**: Write `shift_alerts_summary/2026-April (20-26)/2026-04-26_pbbtBV_kv-vppagg-bootstrap-d-latency.md` per the spec.
- **Acceptance**: file exists, frontmatter valid (status=`complete`), all six sections present, every load-bearing claim labelled, evidence anchored to `$T_DIR/context/02-evidence-summary.md` AND key facts re-stated inline so the file is self-contained.
- **Falsifier**: a fresh reader, given only this file (no `$T_DIR`), can identify (1) what fired, (2) why, (3) whether to ack/resolve/escalate, (4) what upstream change to file. If any of those four is unanswerable, the RCA fails.
- **Route premises**: (a) destination directory is empty so no naming collision; (b) frontmatter validator requires status ∈ {complete, partial, blocked, pending_review, draft}; (c) the user is the consumer and they prefer terse on-call docs (per project memory + `2026_04_21_stefan_redis_alerts/` style sibling). Conditional: if user later asks for a multi-alert summary in the same directory, this file's name + scope still survives.

### S3 — Adversarial review (Phase 7→8)

- **Objective**: Dispatch `socrates-contrarian` to attack the RCA with a **distinct win condition**: *"break the RCA — find at least one (a) hypothesis incorrectly closed, (b) load-bearing claim that is unfalsified, (c) recommendation step that would harm an on-call engineer, or (d) misclassification of FACT vs INFER."*
- **Marginal contribution declaration**: socrates-contrarian's expected belief change — *if it produces a finding flagged "load-bearing claim unfalsified", I MUST upgrade the claim to UNVERIFIED + add a probe or downgrade the recommendation; if it produces a counter-hypothesis I had not considered, route to recompute hypothesis ledger; if it produces a "no finding", the RCA's epistemic confidence ratchets up but does not promote any INFER to FACT.*
- **Acceptance**: socrates-contrarian writes `$T_DIR/verification/01-adversarial-review.md`; coordinator (me) writes a receipt block in `verification/phase-8-results.md` classifying each finding Accepted/Rebutted/Deferred with explicit response action.
- **Falsifier**: receipt block missing OR systematic Defer ≥50% → GATE-FAIL.
- **Subagent type**: `socrates-contrarian` (typed, not fork — adversarial-reviewer per brain rule).

### S4 — Falsifier execution + activation checklist (Phase 8)

- **Objective**: Run F1-F7. Write `$T_DIR/verification/phase-8-results.md` with PASS/FAIL per falsifier and "Belief Changes" + "what was I most wrong about?".
- **Acceptance**: each falsifier has executed evidence (cmd + output reference) and PASS/FAIL stamp.
- **Falsifier**: any FAIL not addressed by re-plan or explicit PARTIAL/NO-GO with residual risk = HALT.
- **Activation Checklist**: written to `$T_DIR/verification/activation-checklist.md` per NN-6 (CRUBVG≥4 trigger applies because Phase-1 score was 6).

### S5 — Manifest update + delivery message (Phase 8 close)

- **Objective**: Update `$T_DIR/manifest.json` with the external write path; tell user the RCA path + recommended on-call action.
- **Acceptance**: `external_writes` array includes the RCA file.

## Adversarial Challenge (6Q, mandatory; CRUBVG≥4 → +orthogonal)

**Q1 — Assumption + fail mode**: I assumed "single-sample-on-idle-KV" is the entire story. Fail mode: the 2712ms could be the tip of a Microsoft regional control-plane degradation that affected many KVs but only fired on this one because the others were also idle. Probe: cross-region/cross-KV check at the same minute.

→ **Action taken**: I do NOT have evidence ruling this out. Adding to the RCA's Residual Risk: "Could be a regional Azure control-plane blip; not investigated."

**Q2 — Simplest alternative**: Could the breach be a real performance regression for a normal caller? Probe: request count over a longer window (last 30 days instead of 31h).

→ **Action taken**: My 31h window is short. Will pull a 30-day count snapshot in S4 to harden the "always idle" claim, OR will explicitly downgrade the claim to "31h idle" if the longer probe is skipped.

**Q3 — Disproving evidence**: What if the rule's `staticThresholdFailingPeriods.numberOfEvaluationPeriods=0/0` (per payload) means something other than the default-1/1 I assumed? Probe: Microsoft Learn doc on `StaticThresholdFailingPeriods`.

→ **Action taken**: Live rule via `az monitor metrics alert show` does not expose failingPeriods at all (there is no `dynamicCriteria` block, just `criteria.allOf` static). Default Azure behavior for static criteria without explicit failingPeriods is 1/1 — confirmed via `azurerm_monitor_metric_alert` provider docs (criteria block has no failingPeriods sub-block). Risk acceptable. Will note in RCA.

**Q4 — Hidden complexity**: The CCoE module hardcodes the threshold across products. Recommendation "fix upstream module" sounds simple but actually requires (a) PR to `terraform-azure-keyvault`, (b) version bump, (c) consumer-side bump in `terraform-bootstrap`, (d) consumer-side bump in `platform-bootstrap`, (e) per-env apply across dev/acc/prd, (f) per-product apply across vppagg/vppfo/vppidd/gurobi/astsch. Hidden cost is 6+ touchpoints.

→ **Action taken**: RCA recommends *filing an issue* against the module; does NOT recommend "just bump the threshold" because the consumer fix path is non-trivial. Lists the alternative consumer-side mitigation (alert processing rule / suppression at action group level) explicitly.

**Q5 — Version probe**: Provider/library/runtime semantics. CCoE module ref `v1.2.0` (terraform-azure-keyvault) and `v0.4.0` (terraform-bootstrap). Probe: `git tag` and recent commits show v0.4.0 is reasonably recent (most recent merge is `v0.4.0` line item per git log). No outdated-runtime risk.

→ **Action taken**: confirmed via `git log --oneline -5` + `git tag` in S0.

**Q6 — Silent fail + verification methodology** (governance/architecture lens): The verification pipeline is "run az queries, grep IaC, claim done". The silent fail mode: I confirm at the WRONG layer. E.g., I read `metric-alert-key-vault.tf` first, found nothing for the bootstrap KV, then traced upward — but if I had stopped at `metric-alert-key-vault.tf` (not bootstrap, not vppagg), I'd have written a wrong RCA pointing at a non-existent file. The rationalization circuit breaker that saved me: "the bootstrap suffix doesn't match `aks-kv` — keep tracing." Methodology fix going forward: always reconcile against `azurerm_monitor_metric_alert` ID prefix (e.g., `Microsoft.Insights/metricAlerts/<exact-name>`) and grep across the entire eneco-src checkout, not just the most-likely repo.

→ **Action taken**: lessons-learned entry in S5.

**Q7 — Orthogonal frame (CRUBVG≥4)**: From the on-call engineer's perspective, the RCA is irrelevant if the alert blocks their pager. They want: "is it real?", "should I page upstream?", "can I close it now?". My RCA is structured for analysis; need to ensure the "Recommended Action" section is the FIRST thing after Identity, not buried. Failing this = engineer reads, doesn't act, alert fires again.

→ **Action taken**: spec mandates "Recommended Action" within the first scroll of the file (right after Identity + Mechanism, BEFORE Evidence/Hypothesis Ledger).

## Downstream consequences (named)

- **If RCA is correct**: on-call engineer resolves `pbbtBV` immediately with a one-line comment; files an issue against `enecomanagedcloud/ccoe/terraform-azure-keyvault` linking to this RCA; saves ~10-30min of next responder's time when the same pattern fires again.
- **If RCA is partly wrong (e.g., this was actually a Microsoft control-plane blip)**: residual-risk section warns engineer to check Azure Service Health before resolving, so wrong recommendation doesn't damage them.
- **If RCA misclassifies FACT vs INFER**: Q5 + adversarial review catch this; receipts mandatory.

## Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Adversarial reviewer surfaces a hypothesis I missed | Medium | Could overturn recommendation | S3 receipt block + re-author RCA if Accepted |
| 31h window too short to claim "always idle" | Medium | Recommendation looks weaker | S4 pulls 30-day request count |
| User wants summary across all April 20-26 alerts, not just pbbtBV | Low (user said "start with the most recent") | RCA file too narrow | Filename anchored to alert id; user can ask for siblings later |
| External `shift_alerts_summary/2026-April (20-26)` directory write violates task scope | Zero | Already in `allowed_external_paths` in manifest | — |

## Verification Strategy (carried from Phase 3, refined)

F1 (Identity): PASSED — payload retrieved (E1).
F2 (Resource grounding): PASSED — `az resource show` confirmed (E4).
F3 (Metric breach): PASSED — `az monitor metrics list` confirmed (E3).
F4 (IaC reconciliation): PASSED — locals.tf:22-40 + live rule definition match (E5).
F5 (Hypothesis closure): PASSED — E8 ledger.
F6 (Adversarial): PENDING — S3 dispatch.
F7 (Activation Checklist): PENDING — S4.

Plus added F8 from Q2: 30-day quiet-period check — will run in S4.
