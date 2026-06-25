---
task_id: 2026-06-24-002
agent: simplicity-maniac
timestamp: 2026-06-24
status: complete
review_lane: simplicity-and-complecting (Hickey)
epistemic_note: This output is INFER until Alex source-verifies it against the four read artifacts.
summary: |
  Audited a 6-artifact PROD TLS rotation for accidental complexity. The ONE real
  braid is Q1: two hand-written orchestrators (rotate_tls.go + rotate_tls.py)
  encode the same logic with no shared source and no generator — twin sources of
  truth that WILL drift. The Manual mode in the spec is a third copy of the same
  command set (Q4) — same drift class, larger surface. The per-step action+probe
  pairing (Q2) is NOT complecting: probe is verification of the step's own effect,
  correctly co-located, decomposition is clean. The dry-run/state-file/JSON
  machinery (Q3) is mostly essential for a probe-gated irreversible-ish prod change,
  with ONE accidental sub-part (cross-invocation /tmp JSON state). The versioned-URI
  toggle (Q5) is ESSENTIAL complexity — forced by Azure App Gateway's documented
  refresh semantics, not an implementation choice. Net: one braid to cut (collapse
  to a single canonical orchestrator), one to fence (manual mode), three to keep.
---

# Simplicity & Complecting Review — VPP PROD TLS Rotation

## Key Findings

- **Q1** — Go+Python twins are two sources of truth with no generator; real drift braid. RECOMMEND: pick ONE canonical, drop or generate the other.
- **Q4** — Manual mode is a THIRD transcription of the same `az` commands; same drift class. RECOMMEND: derive manual from the canonical script (`--print`) or label it non-authoritative.
- **Q2** — action+probe per step is co-location, not complecting. Decomposition is clean. KEEP.
- **Q3** — dry-run + probe gating essential; cross-invocation `/tmp` JSON state is the one accidental sub-part. Mostly KEEP, fence the state file.
- **Q5** — versioned-URI toggle is ESSENTIAL complexity forced by Azure (MS docs Resolution E). Not accidental. KEEP.

**Lane**: Hickey simplicity doctrine — *what concepts does this artifact complect?*
**Doctrine sources**: "Simple Made Easy" (simple/easy, complecting, four axes); "Out of the Tar Pit" (essential vs accidental state/control); "No Silver Bullet" (essence vs accidents).
**Evidence classes**: ARTIFACT-OBSERVED (read directly) → projects to **A1 FACT**; AXIS-INFERRED → **A2 INFER**; UNVERIFIED → **A3**. Every claim labelled. This whole document is INFER until you source-verify.

**Artifacts read in full** (ARTIFACT-OBSERVED):

- `rotation-execution-spec.md` (319 lines)
- `how-the-vpp-tls-rotation-works.md` (290 lines)
- `rotate_tls.go` (552 lines)
- `rotate_tls.py` (402 lines)

---

## Lexicographer's opening — strip the praise to topology

The spec calls the two orchestrators "equivalent" and "identical behaviour" (spec line 63, 81-84). Pulled back to *simplex* (one fold): "equivalent" is an **easy** claim, not a **simple** claim. It says *the operator gets the same experience whichever they reach for* (proximity, comfort). It says nothing about whether the artifact is one-fold. Two files encoding the same logic are, topologically, **two folds that must be kept in phase by hand**. The comfort of "pick whichever language you like" is precisely the ease that purchases a drift braid. That confusion is the spine of finding Q1 — hold it.

---

## Q1 — Two orchestrators (Go + Python): real complecting/drift hazard?

### What is braided

**ARTIFACT-OBSERVED [A1]**: `rotate_tls.go` and `rotate_tls.py` are **hand-written twins**. I verified, by reading both:

- Identical constants, independently transcribed — `SUB`, `RG`, `KV`, `OBJ`, `AGW`, `SSL`, `VLESS`, `WORKDIR`, `PFX`, `EXPECT_ENDDATE` (go lines 37-55; py lines 47-66).
- Identical step roster and order — `preflight|whitelist-on|baseline|import|verify-import|enable|refresh|verify-effect|whitelist-off|rollback|run` (go line 523; py lines 380-385).
- Identical probe semantics, independently expressed — `expect`/`expectTrue` (go 118-141) vs `expect`/`expect_true` (py 103-120).
- **No generator. No shared source. No codegen banner.** Neither file is derived from the other or from a third spec. (ARTIFACT-OBSERVED: I looked for a generation header in both — none present.)

The complected concepts: **rotation logic (essential) + language runtime choice (accidental) fused into two physical sources of truth.** The single concept "what the rotation does" is now braided across two artifacts such that changing the rotation requires changing both, in phase, forever.

### Four-axis map

- **Value** (the rotation procedure, the constants): duplicated. The *same* value lives in two places.
- **Time**: the braid bites *over time* — at the next renewal, when someone edits one file (say, the `EXPECT_ENDDATE`, or a new `az` flag, or a changed resource name) and not the other. Value + Time is the classic mutable-duplication braid: the "true" procedure changes meaning depending on *which file you read and when it was last touched*.
- **Identity**: "the orchestrator" has no single identity — it is two entities pretending to be one ("equivalent").
- **State/Logic**: identical, which is exactly the problem — identical-today says nothing about identical-after-the-next-edit.

### Essential vs accidental (Moseley-Marks)

- **Essential**: the rotation procedure (whitelist → baseline → import-disabled → gate → enable → refresh → verify → cleanup). Exactly one of these is needed.
- **Accidental**: the *second language*. Nothing in the Azure domain requires both a Go binary and a Python script. The second orchestrator is pure accidental state — a second copy maintained for convenience/preference.

This is the **tar-pit signature in miniature**: accidental duplication (two languages) entangled with essential logic (the one true procedure), such that the essential logic can no longer be changed in one place.

### Simple-vs-easy verdict

This is **simple-vs-easy confusion, confirmed**. "Ship both so the operator picks their comfort language" is an *ease* argument (facilis — near at hand). It is sold under the word "equivalent," which smuggles in a *simplicity* connotation it has not earned. The artifact is **not** simpler for having two; it is one-fold doubled.

### Is parallel maintenance ever justified here?

**AXIS-INFERRED [A2]**: No, and the artifact itself proves it. This is a **once-per-renewal operational script**, run by one operator (spec: "single-operator laptop", line 317), not a library with two distinct consumer ecosystems. There is no second audience that *needs* Go-but-not-Python or vice versa. The only thing the duplication buys is "whichever the operator feels like today" — pure ease. Parallel maintenance is justified only when two independent consumers genuinely require two surfaces; that condition is **absent** here (ARTIFACT-OBSERVED: single operator, single run cadence).

This is **not** anti-pattern §9.11 (DRY-without-why): the two files do not merely *look* alike, they encode the *same root concept* by explicit intent ("identical behaviour", spec line 81). Collapsing them is concept-match, not shape-coincidence — the legitimate de-duplication case.

### Recommendation (clear, as requested)

**Pick ONE canonical orchestrator; drop the other.**

- **Recommended canonical: Go.** Reasons grounded in the artifacts: the Go file's own header argues explicit error returns make "stop on a failed probe first-class" and `defer` gives guaranteed cleanup (go lines 4-9); it builds to one static binary with no interpreter-version surface. These are genuine one-fold properties for an irreversible-ish prod action. *(This is a mild preference, AXIS-INFERRED — Python is equally defensible on "no build step." The load-bearing point is ONE, not which.)*
- **Conditional — if both are kept anyway** (you decide the dual-runtime convenience is worth it): then **generate one from the other, or both from a single declarative step-table.** The steps are already a flat list of `(name, az-args, probe)` tuples — that is declarative data (Hickey: information as data, toolkit-of-simplicity). Extract the step table to one source (JSON/YAML), and let each runtime be a thin ~80-line interpreter over it. Then there is **one** source of truth and the language is genuinely just a rendering. *Do Y to prevent drift: a CI check that diffs the two generated outputs, or a test that asserts both emit the identical dry-run command transcript.*
- **If simplified to one — Z**: delete the other file *in the same change* (Rule 4: "refactor later" is not a plan — the second copy will accrete edits), and update the spec's Mode A to name a single orchestrator. The spec currently presents both as co-equal (lines 61-85); that framing must go or it re-seeds the braid.

---

## Q2 — Does any single step do more than one thing (state-change + verification + control-flow braided)?

### Diagnosis: NOT complecting. Co-location, not fusion. KEEP.

**ARTIFACT-OBSERVED [A1]**: each step is structured `action → probe → return-error-on-mismatch` (e.g. go `stepImport` 317-353; py `step_import` 235-252). At first glance "state change + verification + control flow in one function" looks like the imperative braid from the taxonomy (intent + control). It is not, and here is the falsifier I applied (self-questioning protocol #2 — *what would prove these are colocated, not fused?*):

> Can you change the **verification** of a step without touching its **action**, and vice versa?

**Yes.** The probe is a *separate* `az ... show` call asserting the *effect* of the action, expressed through the shared `expect()`/`expectTrue()` helpers (go 118-141; py 103-120). The action mutates; the probe reads back and compares; control flow is `return err`. These are three *named, separable* operations that happen to sit in one function because **they share one subject** (the step's own effect). That is correct co-location — the probe verifies *this step's* state transition, which is exactly where a probe belongs.

Crucially, the design **un-braids the thing that matters**: it separates "did `az` exit 0" (control-plane write) from "is the effect true" (the probe / the handshake). The whole spec hammers this (spec line 41: "Success = EFFECT"; how-it-works line 220: "az exit 0 is meaningless on its own"). That is *de*-complecting Value (the real served cert) from Time/Control (the command returned). The authors already did the Hickey move here.

### One real (small) sub-braid inside the steps

**AXIS-INFERRED [A2]**: `stepRefresh` does two *essential-but-distinct* sub-actions in one function: (1) force the re-pull via the versioned toggle, and (2) restore versionless. Both are essential (see Q5) and causally ordered (you must toggle then restore), so this is **essential sequencing, not accidental control** — the WHEN-NOT clause of the Tar-Pit probe (H-SIMPLE-3) applies: do not split inherent domain ordering. The probe correctly checks the *end* state (back on versionless, go 413-419; py 298-301). KEEP.

### Verdict

Decomposition is **clean**. No step braids independent axes. The action+probe pairing is the toolkit-of-simplicity move (explicit state edges + verification at the edge), not a braid. **Simple-vs-easy: not applicable — this part is genuinely simple.** No change required. *(If anything, do NOT "simplify" by stripping the probes — that would re-braid exit-code with effect, anti-pattern §9.3 tests-as-proof inverted.)*

---

## Q3 — Is the dry-run / probe / JSON-state machinery essential or over-engineered for a once-per-renewal task?

### Split (Moseley-Marks)

| Machinery | Class | Verdict |
|---|---|---|
| **Dry-run default** (go `dry=true`/`-execute`; py `DRY=True`/`--execute`) | **Essential** | KEEP |
| **Per-step probe gating** (`expect`/`expectTrue`) | **Essential** | KEEP |
| **Guaranteed cleanup** (`defer`/`finally` whitelist-off) | **Essential** | KEEP |
| **Cross-invocation /tmp JSON state file** (`STATE = /tmp/vpp-rot-state.json`) | **Accidental** | FENCE / reconsider |

### Reasoning

**Dry-run + probe + cleanup are essential, ARTIFACT-OBSERVED [A1] + AXIS-INFERRED [A2].** This change touches **production TLS for four live listeners**, opens a **prod KV firewall**, and has a **hard expiry-driven deadline** with a rollback that itself expires (spec lines 32-34). The cost of a silent wrong-state is an outage. In Hickey terms, dry-run and probes are *explicit state edges* — they make the effect witnessable before and after each mutation. For a once-per-renewal task the *frequency* is low but the *blast radius* is high; over-engineering is measured against blast radius, not frequency. This machinery is proportionate. It is **not** §9.1 (easy-looking-simple dismissal) nor §9.6 (abstraction-as-ceremony) — each piece removes a named failure mode from the spec's own failure table (how-it-works lines 251-257).

**The /tmp JSON state file is the one accidental sub-part [A2].** It complects **identity + state + time across process boundaries**: `OLD_SID`/`NEW_VER` etc. persist in `/tmp/vpp-rot-state.json` so that separately-invoked steps share memory (go 152-167; py 125-130). This is accidental state introduced for the convenience of "run one step at a time in separate shells." Risks it carries:

- It is **mutable shared state on disk** — a stale `/tmp/vpp-rot-state.json` from an aborted earlier attempt could feed a *wrong* `old_sid` into rollback (the exact scenario where you least want stale state). The Value (which version is OLD) changes meaning by *time and prior runs*, the canonical mutable-variable braid (Value + Time).
- The `run` path doesn't need it at all — within one process the values are in scope. The state file exists **only** to support the split-invocation mode.

### Verdict & conditional

Mostly **essential, KEEP** (dry-run, probes, cleanup). This is correct proportioning, not over-engineering. **Simple-vs-easy: the core machinery is genuinely simple** (explicit edges); the state file is **ease** (convenience of separate-shell stepping) buying a small Value+Time braid.

- **If kept** (you want the one-step-at-a-time mode → do Y): treat the state file as a hazard — have `baseline`/`import` **refuse to overwrite** a state file from a different day/run (stamp it with a run-id + timestamp and assert match), and have `whitelist-off`/`run` **delete** it on clean completion so no stale `old_sid` survives. Print the loaded `old_sid`/`new_ver` loudly before rollback acts (the Go/Py already echo, go 308-309 — make it a *gate*, not a log).
- **If simplified → Z**: make `run` the only blessed path and drop the file (in-process state only); keep single-step mode for emergencies but have it **re-derive** `old_sid`/`new_ver` live from the vault rather than trust /tmp. That removes the cross-process mutable-state braid entirely.

---

## Q4 — Spec carries BOTH Manual and Scripted modes — duplication / drift risk?

### What is braided

**ARTIFACT-OBSERVED [A1]**: the spec's Manual mode (Mode B, lines 89-304) is a **third hand-transcription** of the same `az` command set already encoded in both scripts. Example: the refresh toggle appears as literal bash in spec lines 231-232, as Go in `stepRefresh` (396-405), and as Python in `step_refresh` (287-292). Three copies of one command pair. The rollback commands appear four times total (spec 290-291, spec is one; go 474-481; py 347-350).

So the true source-of-truth count for "what commands the rotation runs" is **THREE** (manual bash + Go + Python), not one. Q1's two-way braid is actually a **three-way braid** once the spec's manual mode is counted.

### Axis map

Same as Q1: **Value (the command set) + Time** — three copies that must stay in phase, drifting independently as each is edited. The manual mode is the most dangerous copy because it is *prose-embedded bash* with no probe-gating harness enforcing it and no build/parse step that would catch a typo'd resource name. (The scripts at least fail loudly on a bad `az`; a wrong command pasted from stale spec prose fails *in production*.)

### Essential vs accidental

- **Essential**: a human-readable explanation of *what each step does and why* — the "what could go wrong / what to do" narrative is genuine teaching value (and pairs with the how-it-works doc). That content is **not** duplication; it is the essential "why."
- **Accidental**: the **executable command literals** duplicated in prose. The operator can run either the script *or* paste the prose commands; the moment those diverge, the prose lies.

### Simple-vs-easy verdict

**Confusion confirmed.** "Provide both manual and scripted so the operator can choose" is an *ease* argument (operator comfort, fallback if the script won't run). It buys a third drift surface. The spec even half-admits the scripts are canonical ("Scripted ... recommended", line 12) — which is the tell: if one is recommended and the others are fallbacks, they are **not** equal, and the fallbacks are unmaintained-by-default copies.

### Recommendation + conditional

- **If kept** (manual mode is a genuine break-glass for "the script won't run") **→ do Y**: make the manual commands **derived, not transcribed.** Add a `--print` / `-step run` (dry-run already prints every command, go 87-90 / py 89-91!) and have the spec **say**: "for manual execution, run the orchestrator in dry-run and copy the emitted commands." The dry-run output *already is* the manual playbook, generated from the canonical source. That collapses three sources to one with a rendering. *Prevent drift: delete the hand-typed command literals from Mode B; replace with the explanatory prose + "the exact command is whatever `rotate_tls -step <x>` prints in dry-run."*
- **If simplified → Z**: keep Mode B's *prose rationale* (the "why / what could go wrong" — that is the essential teaching), but strip the literal `az` lines and point to the script. One source of truth for commands; the spec owns the "why," the script owns the "what."

Either way: the dry-run printer makes the manual/scripted braid **fully avoidable** — the canonical source can *render* the manual steps. Not exploiting that is leaving an easy un-braiding on the table.

---

## Q5 — The versioned-URI toggle refresh: essential or accidental complexity?

### Verdict: ESSENTIAL complexity. Forced by Azure. KEEP. No change.

**ARTIFACT-OBSERVED [A1]**: the toggle (point ssl-cert at versioned URI → restore versionless) is documented as the *only* way to force the gateway to re-pull, citing Microsoft Learn "Resolution E": *"Application Gateway refetches the certificate from Key Vault only when the configured `keyVaultSecretId` changes ... an empty `az network application-gateway update` ... doesn't force the gateway to pull the newer version"* (how-it-works lines 117-121; evidence ledger row 5 marked FACT; spec line 228).

**Brooks frame (essence vs accidents)**: this complexity is **inherent in the problem domain** — specifically in Azure App Gateway's caching/refresh contract. It is not introduced by the implementation's choices; *any* correct rotation against this gateway must change `keyVaultSecretId` to trigger a re-pull. The authors did not invent this braid; Azure did. That is the definition of **essential** complexity.

**Why it is not accidental, with the falsifier I applied** (H-SIMPLE-3 WHEN-NOT — *is the sequencing inherent to the domain or imposed by convenience?*): inherent. Remove the toggle and the cert sits in the vault **unserved until expiry** (how-it-works "dangerous shortcut" ladder, lines 207-220). There is no simpler representation available to the operator — the gateway exposes no "refresh now" verb. The toggle is the minimal correct move: *momentary* versioned pin (forces pull) then *restore* versionless (preserves auto-rotation + matches terraform, avoiding drift). It even un-braids a would-be drift braid by restoring versionless (so terraform's stored value stays canonical — how-it-works line 224).

### One note (not a defect)

**AXIS-INFERRED [A2]**: the toggle *is* a two-step sequence whose correctness depends on the restore completing. The scripts handle this well (the restore is unconditional after the pin, and the probe asserts the end state is versionless — go 413-419; py 298-301). If the restore step were ever made conditional or skippable, the essential complexity would *become* an accidental drift braid (gateway pinned to a version, auto-rotation silently off). Keep the restore non-skippable and probe-gated, exactly as written.

**Simple-vs-easy: not applicable** — this is irreducible essential complexity. The honest move (which the docs make) is to *name* it as a leaky abstraction (how-it-works line 275: "where does the abstraction leak?"). That is correct Hickey practice: don't hide essential complexity, expose it.

---

## Summary ledger

| Q | Braid? | Concepts complected | Essential/Accidental | Simple-vs-easy confusion? | Verdict |
|---|---|---|---|---|---|
| Q1 two orchestrators | **YES — real** | rotation logic + language choice → 2 sources of truth (Value+Time) | Accidental (2nd language) | **Yes** ("equivalent" = ease sold as simple) | **CUT to one canonical** (Go), or generate both from one step-table |
| Q2 step internals | No | action/probe/control share one subject (co-location) | Essential | No | **KEEP** — clean decomposition |
| Q3 dry-run/probe/state | Mostly no | core=essential edges; /tmp JSON state = Value+Time | Core essential; state file accidental | Partial (state file = ease) | **KEEP core, FENCE state file** |
| Q4 manual + scripted | **YES — real** (3rd copy) | command literals + prose → 3 sources of truth | Accidental (duplicated literals); prose=essential | **Yes** (operator-choice = ease) | **DERIVE manual from dry-run `--print`**, strip literals |
| Q5 versioned-URI toggle | No | n/a — irreducible | **Essential (Azure-forced)** | No | **KEEP** — exemplary handling |

### The one-paragraph decomplecting path

There is **one root braid** and it appears twice: *the command set has multiple hand-maintained sources of truth* — Q1 (Go + Python) and Q4 (+ manual prose) are the same braid at different magnifications (Value duplicated across copies that drift over Time). The decomplecting move is singular and clean: **make the rotation procedure exist in exactly ONE canonical place, and let every other surface be a rendering of it.** The dry-run printer already proves this is cheap — it *already* renders the manual playbook from the canonical script. Adopt one orchestrator as canonical, generate (or delete) the rest, and the six artifacts collapse toward one coherent thing. Q2, Q3-core, and Q5 are already simple and should be left alone — including resisting any "simplification" that strips the probes or the toggle, which would re-braid effect with exit-code or break Azure's refresh contract.

### What I VERIFIED vs OPINION

- **VERIFIED (ARTIFACT-OBSERVED, read directly)**: the two scripts are hand-written twins with no generator; identical step rosters/constants/probe semantics; the manual mode re-transcribes the same `az` commands a third time; the dry-run path already prints every command; the versioned-toggle refresh is cited to MS docs and is the only documented re-pull trigger; the state file is cross-invocation mutable disk state.
- **OPINION / INFERENCE (AXIS-INFERRED)**: that Go (vs Python) should be the canonical one (mild — the binding point is *one*, not which); that parallel maintenance is unjustified *here* (grounded in the single-operator, once-per-renewal facts, but a judgment); that the /tmp state file is the weakest sub-part. These are reasoning chains, not observations — weigh them as such.

### Handoffs (if you act on this)

- Turning "one canonical orchestrator + rendered manual" into a concrete structure → `architect-kernel`.
- Proving the collapse didn't change the rotation's behaviour (dry-run transcript diff Go-vs-Python-vs-manual as the discriminating test) → `verification-engineer`.
