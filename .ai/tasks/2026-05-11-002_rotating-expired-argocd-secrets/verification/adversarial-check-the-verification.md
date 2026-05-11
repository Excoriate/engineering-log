---
task_id: 2026-05-11-002
agent: linus-torvalds
status: complete
summary: P8 separate-frame meta-attack — am I verifying the right thing? Verdict PARTIAL with 3 BLOCKING fixes and 5 non-blocking.
phase: 8
---

# P8 Adversarial-Check-the-Verification

Frame: Linus (Data Structure + Simplicity + Hardware + Dependency). Win condition: destroy the verification's premise. Inputs: 3 deliverables + req-final + receipts + plan. All counts `wc -l`-verified.

---

## A1 — Verification surface correctness

- **SC1** ("3-7 surgical questions, not a blank page"). Reality: `how-to-rotate.md:1147-1175` lists **13 questions across 6 groups**. SC1 ceiling **violated**. F5 falsifier at `01-task-requirements-final.md:94` set a FLOOR (≥5), SC1 set the CEILING (≤7) — **falsifier and success criterion CONTRADICT**. Verification optimized for the floor and ignored the ceiling. [CODE-VERIFIED]
- **SC2** (copy-paste Section A today): PASS. Section A is `how-to-rotate.md:339-980` (~640 lines, 12 steps). Executable. [CODE-VERIFIED]
- **SC3** (Section B honest about MC ambiguity): PASS. `DRAFT — DO NOT EXECUTE` banner at `:984` + 4 B-G gates at `:996-1001`. [CODE-VERIFIED]
- **SC4** (proposal: menu with tradeoffs): PASS. 3 options each with mechanism/ROI/blast/mitigations/ownership/verifiability/rollback/drawbacks/risk. [CODE-VERIFIED]
- **SC5** (deliverables in correct path): PASS. [CODE-VERIFIED]

**Verdict A1**: SC1 NOT MET despite F5 passing — process-pass, outcome-fail. [BLOCKING — Fix 1]

---

## A2 — Method-of-verification correctness

F1 measures **citation completeness**. User's bar is **mastery-grade reader-mode comprehension** — correlated but not identical.
- F1 PASSES (every claim tagged in `draft-rotation-secrets.md §3`). [CODE-VERIFIED]
- Mastery-grade requires the reader to internalize the mechanism. 60-second model at `how-to-rotate.md:78-109` + 5 durable principles at `:1238-1252` carry this load.
- The "two clocks" insight at `:260` is buried in prose — for the user's high-bar it should be a callout box.

**Verdict A2**: F1 is necessary but not sufficient for mastery-grade. Self-test at `:1256-1275` is a partial proxy — see A6.

---

## A3 — Cross-document consistency

- `how-to-rotate.md:1179` says "Send all **13** questions". `draft-rotation-secrets.md:191-262` lists same groups. CONSISTENT count — but contradicts SC1 (see A1). [CODE-VERIFIED]
- **INCONSISTENCY 1 (mechanical, BLOCKING)**: `proposal-rotation-automation.md:184` names the KV as `vpp-aks-devops` "per wiki sidecar". `draft-rotation-secrets.md:73` C14 names `vpp-appsec-d`. **Two different KVs cited for the same secret.** Draft is the evidence base; proposal drifted. [CODE-VERIFIED]
- **INCONSISTENCY 2 (semantic, BLOCKING)**: `how-to-rotate.md:917-923` Step 9 instructs storing the new PAT in the team password vault. But `draft-rotation-secrets.md:69` C10 + Socrates S3 receipt (`adversarial-receipts.md:19`) document that **convention stores SA LOGIN only, NOT derived PATs**. Either Step 9 is silently changing the convention or it's wrong — unflagged divergence violates F1 (no unflagged claims). [CODE-VERIFIED]
- **INCONSISTENCY 3 (ordering, non-blocking)**: Anti-pattern #10 at `:1100` says "Trust HTTP 200 + headers as proof of FBE health" = WRONG. But Step 8 code at `:879` runs the header probe FIRST, body-content second (`:882-883`), Swagger third (`:887-888`). A cold-reader stops at the first command. Body-content should be 8.1, headers relegated. [CODE-VERIFIED]

**Verdict A3**: 3 inconsistencies. Fix 2 + Fix 3 BLOCKING. Fix 4 (ordering) non-blocking.

---

## A4 — Did I solve the real problem?

User's underlying problem: "FBEs broken, 3 PATs expire in 21 days, tribal knowledge SPOF."

- **Sandbox TODAY**: Section A executable after G6 Fabrizio DM. SOLVED. [CODE-VERIFIED]
- **MC in 21 days**: Section B is DRAFT with 4 B-G gates requiring Fabrizio answers. Doesn't solve MC — **converts unknown into questionnaire**. Per user's "list pending points" instruction, this is the right SHAPE. But the doc instruction at `:1179` ("Send all 13 questions as one focused Slack message") makes it worse: it batches route-flipping Group A (4 questions, MC-blocking) with research-grade Groups B-F (9 questions, nice-to-have for SLA/proposal). The right instruction is: **send Group A only first; defer B-F to a follow-up DM after sandbox completes.** [CODE-VERIFIED]
- **Counter-steelman**: 13 questions ARE structured. If Alex applies judgment and splits, the doc IS surgical. But the explicit instruction tells him not to split — which is the wrong default for a mastery-grade runbook.
- **Prevent next outage**: Phase 1 (SLA + Grafana + runbook) is right shape, ~1-3 days. **Missing**: explicit "by 2026-05-25, complete MC rotation" deadline action item in `proposal-rotation-automation.md:380-392` Phase 1 deliverables. 7-day buffer to 2026-06-01 expiry. Obvious cheap mitigation, omitted. [CODE-VERIFIED]

**Verdict A4**: PARTIAL. Sandbox solved. MC = correct shape, wrong instruction at :1179. Outage prevention = proposal right but 21-day-countdown action missing.

---

## A5 — Section A Step 5 cold-read (3 AM Saturday)

`how-to-rotate.md:612-689` = **78 lines for one step**. Code block at `:626-658` = **33 lines, 6 sub-steps** (5.1 label guard, 5.2 PRE_RV, 5.3 b64 encode, 5.4 patch, 5.5 round-trip, 5.6 POST_RV). The actual rotation command at `:646-648` is visually one block among 6. Cold-reader executes correctly but scans slowly. Mastery-grade DEPTH met; SPEED bar not. [COMPLEXITY-ESTIMATED]

**Non-blocking fix**: top of Step 5, add 2-line TL;DR command callout above the 33-line block.

---

## A6 — Self-test answerability (the 5 questions at :1256-1275)

I attempted to answer each cold using only the doc:
- **Q1** (ErrorOccurred=False but children missing): cites Step 6.5. PASS.
- **Q2** (HTTP 200 + Request-Context, healthy?): "No, headers necessary not sufficient." PASS.
- **Q3** (patch shows wc -c == 52, done?): "No, capture POST_RV, run 4.5 BEFORE patch." PASS.
- **Q4** (Fabrizio says "I'll handle MC"): "Confirm writing, defer Section B, send runbook + gap list." PASS but **operationally soft** — missing the 2026-06-01 deadline pressure.
- **Q5** (old PAT still in ADO, exposure?): "Sandbox minimal; MC 21 days." PASS.

**Verdict A6**: 5/5 PASS at depth bar. Q4 soft on deadline urgency. [Fix 7 non-blocking]

---

## A7 — Cargo cult / over-engineering (Linus eye)

- **G5 "AskUserQuestion gate for AI executors"** at `:317-321`: dual-audience artifact in a human runbook. Cosmetic, not cargo. Could move to appendix.
- **Glossary at `:1183-1203`** (21 lines): duplicates inline definitions but acceptable for mastery-grade.
- **Step 6 + Step 6.5**: genuinely two clocks per Socrates S4. Separation justified. NOT cargo.
- **17 anti-patterns at `:1089-1107`**: each has distinct mechanism explanation — right shape for mastery. NOT cargo.
- **REAL data bug**: FBE slot list at `:1191` glossary entry lists 10 slots `afi/boltz/enel/ionix/ishtar/jupiter/kidu/operations/veku/voltex` — **missing `thor`**. Section "When to use this runbook" at `:274` says "8 surviving: afi/ionix/ishtar/jupiter/operations/thor/veku/voltex." Draft `:105` matches `:274`. Glossary has stale list. [CODE-VERIFIED — Fix 5 non-blocking]

**Verdict A7**: No structural cargo. One real data inconsistency (FBE slot list).

---

## A8 — Fabrizio's predicted reaction

**What Fabrizio would call out as correct**:
- Cross-source matrix in `draft-rotation-secrets.md §3` — explicit provenance per claim.
- Section A Step 4.5 (ownership probe) — smart catch on the Helm-chart smoking gun.
- Anti-pattern #11 (KV-update theatre) — the exact mistake a junior would make.
- The auth-flow `sequenceDiagram` at `:227-256` — accurate, reusable for onboarding.
- Proposal Phase 1/2/3 framing — matches his "must be automated" DM intent.

**What Fabrizio would say is wrong**:
- **"13 questions is too many. Group A unblocks you; don't send me 13."** [HIGH probability — his 2026-05-11T12:47:35Z "give me a call and I explain you the process" signals time-bounded oral handoff, not 13-item written questionnaire.]
- **"`vpp-aks-devops` vs `vpp-appsec-d` — pick one. We use `vpp-appsec-d`."** [MEDIUM probability — depends on his exact KV knowledge; the draft C14 citation is more recent and source-cited.]
- **"You're saving the PAT to the team vault — we don't. We save the LOGIN. PAT lives in cluster only."** [HIGH probability — Roel's quote + Socrates S3 receipt are explicit.]
- **"'Call Fabrizio per his offer' as Step 4.5 fallback at `:610` doesn't scale. Make it a TODO, not a hotline."** [MEDIUM probability.]
- **"21 days buffer is fine but I'd want MC done by 2026-05-25. Where's that deadline?"** [MEDIUM probability — Fix 8.]

**What Fabrizio would NOT say**: "this is over-engineered" — depth matches his explicitly-offered "I'll explain the process" bar. He'd recognize Socrates S1/S3/S4 + el-demoledor V5/V8/V11 as correct catches.

---

## Verdict — PARTIAL

**Cannot PASS** because:
1. SC1 ceiling violated (13 questions vs ≤7). Instruction at `:1179` makes it worse.
2. KV-name drift (`vpp-aks-devops` vs `vpp-appsec-d`) — unverified claim in proposal, violates user's "no unverified claims" bar.
3. Step 9 PAT-storage convention divergence — unflagged behavior recommendation contradicting documented practice, violates F1.

**Cannot FAIL** because:
- Data structures of the deliverables are correct (3 docs, clean separation: evidence / runbook / proposal).
- Adversarial discipline (Socrates S1-S4 + el-demoledor V1-V13) is real; findings ARE in the runbook.
- Section A executable today for sandbox.
- Section B DRAFT honesty is correct.
- Proposal Phase 1/2/3 framing is the right executive shape.

---

## Required fixes before publication

### BLOCKING (3)

**Fix 1 — SC1 reconciliation**
At `how-to-rotate.md:1179`, replace "Send all 13 questions as one focused Slack message" with:
> "**Phase 1 (BLOCKING for MC rotation)**: send Group A only (4 questions) — unblocks MC PAT rotation. **Phase 2 (after sandbox done)**: send Groups B-F as follow-up DM."

At `01-task-requirements-final.md:94` F5, change "fewer than 5 → likely incomplete" to "Phase-1 surgical set: 3-7 questions; <3 or >7 → FAIL."

**Fix 2 — KV name drift**
At `proposal-rotation-automation.md:184`, replace "likely `vpp-aks-devops` per wiki sidecar" with "`vpp-appsec-d` per `draft-rotation-secrets.md` C14 (4-source-verified)."

**Fix 3 — Step 9 PAT-storage convention**
At `how-to-rotate.md:917-923`, replace "the new PAT value (so the next operator can apply it without re-minting if the cluster is lost)" with EITHER:
- (a) Flag: "**NOTE**: Per current Trade Platform convention (`draft-rotation-secrets.md` C10 + Socrates S3), only the SA LOGIN is stored in the team vault, NOT derived PATs. This step DEVIATES with rationale: cluster-loss recovery. **[PENDING: confirm with Fabrizio.]**", OR
- (b) Delete the PAT-storage prescription; rely on re-mint as recovery. Update prose accordingly.

### NON-BLOCKING (5)

- **Fix 4** — Step 8 ordering: reorder `how-to-rotate.md:871-889` so body-content/Swagger lead, header-probe follows.
- **Fix 5** — FBE slot list at `how-to-rotate.md:1191` glossary entry: add `thor` (10-slot list missing it; correct list is at `:274` and `draft-rotation-secrets.md:105`).
- **Fix 6** — Step 5 TL;DR: insert 2-line command callout at top of `how-to-rotate.md:612-689` before the 33-line block.
- **Fix 7** — Q4 self-test at `how-to-rotate.md:1269-1270`: add the 2026-06-01 deadline pressure into the answer.
- **Fix 8** — Proposal Phase 1 deliverables at `proposal-rotation-automation.md:380-392`: add "By 2026-05-25: complete MC rotation (Section B) — 7-day buffer to 2026-06-01 expiry."

---

## Counter-hypothesis

**Steelman for PASS without fixes**: "Fabrizio called it 'a good opportunity to create one' — he's accepting a DRAFT. 13-question gap list is comprehensive thinking; Alex will use judgment. Internal docs need not be Fabrizio-shaped."

**I still conclude PARTIAL because**:
- User's explicit bar is "no space for unverified claims" + "mastery-grade." The KV-name drift (Fix 2) IS an unverified claim in the proposal. Cannot pass the user's own bar.
- The Step 9 PAT-storage divergence (Fix 3) is a behavior recommendation contradicting documented practice WITHOUT flagging. Exactly what F1 prohibits.
- These are surface-level mechanical errors. 5-minute fixes. Shipping with them is unforced error.

**Would switch to PASS if**: Fixes 1, 2, 3 applied. Fixes 4-8 are improvements, not blockers.

---

## Meta-falsifier

- "Would Linus ACTUALLY block, or am I cosplaying brutality?" → Fix 2 + Fix 3 are CODE-VERIFIED mechanical errors. Fix 1 is a CONTRACT VIOLATION between SC1, F5, and the artifact. Linus blocks all three. **Not cosplay.**
- "Which findings would I retract under counter-evidence?" → If `vpp-aks-devops` IS the real sandbox KV (draft wrong, proposal right), Fix 2 reverses target — error is still BLOCKING.
- "Data-structures-first reflex?" → Yes; cross-document consistency is itself a load-bearing claim per user's "fully holistic" bar. Right lens here.

---

## Receipt to coordinator

- Adversarial-check-the-verification: COMPLETED.
- Verdict: **PARTIAL**.
- Frame: linus-torvalds (≠ primary verifier, per F10b).
- 3 BLOCKING fixes, 5 non-blocking. All findings CODE-VERIFIED with file:line.
- Counter-hypothesis + would-switch-to-PASS criterion stated.
