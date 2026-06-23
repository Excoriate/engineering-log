---
task_id: 2026-06-22-004
agent: codebase-analyzer
status: complete
summary: |
  Independent verification of an 8-claim handoff brief against the eneco-sre
  worked-exhibit skill. 7 of 8 claims CONFIRMED with file:line evidence; 1 is
  CONFIRMED-WITH-CORRECTION. The brief's single hedge — that the effect-witness
  gate (claim #7) exists "only after the F1 fix lands" — is FALSE: H-EFFECT-1,
  H-ROLLBACK-1, the DF3 close-rule, and R2/R4 routes are all fully present in the
  committed SKILL.md NOW. No claim is REFUTED. The actual implemented shapes are
  extracted below as templates for the meta-skill heuristics.
---

# Exhibit Verification — eneco-sre worked exhibit

## Key Findings

- claim_7_brief_hedge_false: effect-gate is PRESENT now, not pending F1
- claim_4_commands_verified: argocd v3.4.4 + Sandbox commands carry probe provenance
- schema_consistent: all 13 references share title/description/type:reference
- claim_6_calibration_record: C1-C5 captured rules present, but waived up-front

**Exhibit root:** `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/stdlib/std/skills/10_employer/eneco/eneco-sre`
**Method:** read actual file contents + line numbers; grep-confirm claimed verbatim strings; never trust the brief's prose.
**Verdict tally:** CONFIRMED 7 · CONFIRMED-WITH-CORRECTION 1 · PARTIAL 0 · REFUTED 0.

The single brief hedge ("one exemplar exists only after the F1 fix lands", claim #7) is **FALSE** — the gate is in the committed file now.

---

## BRAIN SCAN (this verification)

- **Dangerous assumption:** the brief's structure descriptions are accurate enough to skim-confirm.
- **Falsifier:** if a claimed verbatim string (`## Reference Map`, `LOAD NOW:`, `H-EFFECT-1`) is absent, the claim is REFUTED regardless of plausibility.
- **Likely failure mode:** confirming by partial filename match (file named `mc-avd-execution-boundary.md` exists but documents something else). Mitigated by reading full bodies.

---

## Claim 1 — Primacy "## Reference Map" with load-triggers — CONFIRMED

`SKILL.md:53` literally `## Reference Map (you are AWARE of all of these — load each on its trigger)`. It sits near the top (after the description, Skill Selection Gate, Enforcement Contract; BEFORE the Mental Model and all Decision Frameworks). It is a linked inventory grouped by load-trigger class.

**Actual shape (this is the template):** entries are `[label](path) — <what it gives>` lines grouped under **trigger headers**, NOT bare labels. The WHEN-trigger lives in the group header + the entry tail, not a per-line "load WHEN" prefix:

- `SKILL.md:60` group header `**Always (every run):**`
- `SKILL.md:61` → `[classification-spine](references/classification-spine.md) — the origin+surface taxonomy, confidence rubric, epistemic ledger, 4-predicate handover.`
- `SKILL.md:64` group header `**Failure-surface kind — load the ONE matching the classified surface:**`
- `SKILL.md:73` group header `**Context — load when you need its specific anchor:**`
- `SKILL.md:78` → `[mc-avd-execution-boundary](...) — WHEN an MC dev/acc/prd OpenShift/oc proof is needed: it is AVD-gated → the USER executes it ...; the agent cannot run oc on MC directly.`

**Nuance for the meta-skill:** the load-trigger is encoded TWO ways — (a) the group header gives the trigger *class* ("always" / "the ONE matching surface" / "when you need its anchor"), and (b) several individual entries embed an inline `WHEN <scenario> → gives <value>` (clearest at line 78). It is NOT a uniform per-line `load WHEN X → gives Y` table — it is a **grouped linked inventory where the group is the coarse trigger and the entry tail is the value (+ optional inline WHEN)**. The map also self-declares (line 55) that `classify-incident.sh` prints the per-incident `LOAD NOW:` subset of this same inventory, and (line 58) `A relevant-but-unqueried reference is a failure.` If the meta-skill heuristic demands a strict uniform `load WHEN…→gives…` on EVERY line, this exhibit only PARTIALLY matches that exact micro-format; if it demands "grouped inventory at top, each entry names its value, triggers explicit," it fully matches.

`A1 FACT` — SKILL.md:53-78.

---

## Claim 2 — classify-incident.sh "LOAD NOW:" emitter + SURFACE=unknown→HALT — CONFIRMED

**LOAD NOW emitter** (`scripts/classify-incident.sh:74-85`):

```bash
echo "LOAD NOW:"
echo "  [always] references/classification-spine.md"
[ "$SURFACE" != "unknown" ] && echo "  [kind]   ${KIND}"
echo "  [skill]  references/eneco-skills-to-use.md -> ${SKILL}"
case "$ORIGIN" in
  slack-lists)  ORIGIN_HINT="dispatch harvest+reply to eneco-oncall-intake-slack" ;;
  rootly-alert) ORIGIN_HINT="dispatch decode/triage to eneco-oncall-intake-rootly / eneco-tools-rootly" ;;
  *)            ORIGIN_HINT="eneco-sre owns end-to-end (raw origin)" ;;
esac
echo "  [origin] ${ORIGIN_HINT}"
echo "  [context] ${CTX}"
```

It prints a **per-task checklist** with bracketed load-classes `[always] [kind] [skill] [origin] [context]`. The `[context]` line is surface-specific (the `case "$SURFACE"` block at lines 47-56).

**unknown→HALT branch** (`scripts/classify-incident.sh:87-93`):

```bash
if [ "$SURFACE" = "unknown" ]; then
  echo ""
  echo "HALT: SURFACE=unknown — do NOT free-probe across an unclassified boundary." >&2
  ...
  exit 3
fi
```

Header documents it (`:8`): `Exit: 0 = classified, 2 = usage, 3 = SURFACE=unknown (HALT — do not free-probe).` Note the HALT prints the `LOAD NOW:` block FIRST (line 75) then HALTs (line 87) — so even on unknown it still emits the always-load + a re-read hint, then exits non-zero. `set -u` at line 10 (fail-on-unset). `A1 FACT` — classify-incident.sh:74-93.

---

## Claim 3 — mc-avd-execution-boundary.md is an execution-access-boundary reference — CONFIRMED

File exists and its body IS an execution-access boundary (not a partial-name match).

**Frontmatter** (`mc-avd-execution-boundary.md:1-5`):

```yaml
title: "MC AVD Execution Boundary (OpenShift access)"
description: "When OpenShift/oc proofs on MC dev/acc/prd are needed they are locked behind the Azure Virtual Desktop (AVD); the agent cannot run them directly — the user executes them, or the agent only with explicit authorization + computer-use access. Azure (az) access is NOT behind AVD."
type: reference
```

**Structure (section headers — the template):**
- `## The boundary (who can reach what)` (:14) — MC oc behind AVD; `az` NOT behind AVD; Sandbox is AKS/kubectl not MC OpenShift.
- `## Execution rule (who runs the oc proof)` (:25) — 3-way: agent prepares exact cmds → USER executes in AVD → OR agent only with explicit auth + computer-use; unobtained proof stays `A3 UNVERIFIED` (:32-34).
- `## Round-trip state contract (don't lose the proof mid-incident)` (:36) — pending-proof log + verify-match-on-pasteback.
- `## What this changes in intake + troubleshoot` (:47).
- `## Near-miss (who runs it)` (:54) — Azure-plane = agent; Sandbox kubectl = agent; acc/prd oc = AVD-gated.
- `## Sibling references / skills` (:61).

It explicitly distinguishes which probes the agent runs directly (`az`, Sandbox `kubectl`) vs gated behind AVD/human/computer-use (MC `oc`), exactly as claimed. `A1 FACT` — mc-avd-execution-boundary.md:1-63.

---

## Claim 4 — eneco-clis-and-tools.md VERIFIED argocd Sandbox commands + DIRECT vs GATED — CONFIRMED

**DIRECT (Sandbox argocd, NOT behind AVD)** — `eneco-clis-and-tools.md:59-70`, header `## ArgoCD CLI — Sandbox (DIRECTLY accessible, NOT behind AVD)`:
- `:60` `argocd v3.4.4. The agent CAN run this against **Sandbox** (argocd.dev.vpp.eneco.com) — Sandbox is not an MC environment, so no AVD.`
- `:61` login alias `argosandboxlogin = argocd login argocd.dev.vpp.eneco.com --sso --grpc-web --insecure --skip-test-tls`
- `:62-69` read-only aliases table: `argo-sick`, `argo-drift`, `argo-stuck`, `argo-why <app>`, `argo-tree <app>`.

**GATED** — `:72-73` header `## oc — MC OpenShift (AVD-gated)`: `MC dev/acc/prd oc/console is behind the Azure Virtual Desktop — the agent CANNOT run it directly`.

**Are the commands marked verified/probed (not fabricated)?** YES — provenance is recorded, not in this file but in the design ledger: `skill-design.md:40` — `ArgoCD Sandbox is directly agent-accessible via argosandboxlogin + argo-* aliases | Known | probed argocd v3.4.4 + dotfiles aliases-work-eneco-devops.sh this session`. The exact version string `v3.4.4` matches between the design ledger (probe record) and the reference (clis line 60), which is strong evidence the command map was probed, not invented. Subscription IDs are also flagged verbatim/ground-truth (`:16`). **Caveat for the meta-skill:** the verification provenance lives in the *sibling design doc's evidence ledger*, NOT inline in the reference file itself — the reference has no per-command `# verified <date>` annotation. So "marked verified" is true at the skill level via the ledger cross-ref, but a builder copying ONLY the reference file would lose the provenance trail. `A1 FACT` — eneco-clis-and-tools.md:59-73; skill-design.md:40.

---

## Claim 5 — surface-azure-resource-alert.md pattern-not-instance trigger — CONFIRMED

`surface-azure-resource-alert.md:14-15`, header `## Trigger signals`. The trigger:

> **Any** Azure Monitor metric on an MC resource breaching its configured threshold — this surface is GENERIC; the PATTERN selects it (a metric crossed a threshold and Rootly/Azure Monitor fired), not the specific resource. The resources below are **examples, not the definition**: CosmosDB ServerSideLatency / 429 throttling, SQL CPU / deadlock ... , Service Bus deadletter ...

This is explicitly a generic category pattern ("Any … breaching its threshold") with the concrete resources called out verbatim as **"examples, not the definition"** — CosmosDB is listed as an example, NOT as the defining instance. Exactly the pattern-not-instance shape claimed. The DO-NOT-COLLAPSE note (`:22-25`) reinforces it: `Pattern attribution needs payload match, NOT rule-name`. `A1 FACT` — surface-azure-resource-alert.md:14-15.

---

## Claim 6 — skill-design.md §8 calibration record with C1-C5 — CONFIRMED

`skill-design.md:116` header `## 8. Calibration Record (validate-calibration.sh gates this)`.

**:118** `CALIBRATION-WAIVED:` followed by the user's verbatim waiver (sign-off deferred to file-by-file review).
**:120** `**Captured rules from the file-by-file review** (full register: $T_DIR/feedback-register.md, FB-1…FB-8):` then a table with rule ids **C1-C5** (:122-127):

- C1 — every reference entry answers `load/fetch WHEN <scenario> → gives you <value>`, never a label/vocab dump.
- C2 — deterministic loading: `classify-incident.sh` prints `LOAD NOW:`; SKILL.md has a primacy Reference Map; every ref self-declares its trigger.
- C3 — a category reference states the generic PATTERN; concrete instances are examples (no Cosmos-as-definition).
- C4 — reference frontmatter carries title + description + type.
- C5 — access boundaries (MC `oc` AVD-gated; Sandbox argocd direct) are first-class references with verified commands.

**Note:** these C1-C5 are themselves the SOURCE heuristics the brief is propagating, and each maps 1:1 to claims here (C2→claims 1+2, C3→claim 5, C4→claim 8, C5→claims 3+4). The section is an accumulating calibration record as claimed, BUT the calibration was *waived up front* (:118) and the rules captured *during* review with the validator-signal column being aspirational ("validate-calibration.sh gates this"). I did not verify that `validate-calibration.sh` actually exists/runs — that is `A3 UNVERIFIED[blocked: not probed]`. The C1-C5 register content itself is `A1 FACT` — skill-design.md:116-127.

---

## Claim 7 — effect-witness gate in DF3/Workflow-4 + partial-fix/rollback — CONFIRMED (brief hedge is FALSE)

**THE BRIEF SAID THIS MAY BE ABSENT ("after the F1 fix lands"). IT IS PRESENT NOW.** Multiple, mutually reinforcing locations in the committed SKILL.md:

**Effect-witness gate — H-EFFECT-1** (`SKILL.md:226-233`):

> **H-EFFECT-1: a fix is closed by its observed EFFECT, never by a return code**
> CONDITION: an R2 fix/mitigation was applied.
> ACTION: capture the witnessable success signal for the surface — URL `curl` 200, `argocd app get` = Synced AND Healthy, pod Running/Ready, the alert cleared, the re-auth actually connects. Exit-0 / "operation succeeded" / "applied" is NOT an effect — declaring success on it is a HALT.

**Rollback / partial-fix path — H-ROLLBACK-1** (`SKILL.md:235-241`):

> **H-ROLLBACK-1: a regressed effect is an escalation event, not a retry**
> CONDITION: after H-EFFECT-1, the effect is absent OR worse than the pre-fix state.
> ACTION: STOP — do NOT re-fire blindly. Capture the new state, name the before/after effect, and escalate (R4) ... Only re-run a fix the surface ref explicitly marks retry-safe.

**DF3 close-rule** (`SKILL.md:149-151`): `Troubleshoot (R2) crosses into a fix only with authorization + a passed safety preflight, and **closes ONLY on the observed EFFECT, never on a return code** (H-EFFECT-1); R3 = blocked BEFORE acting ...; R4 = acted but the effect is absent or WORSE → escalate, never retry (H-ROLLBACK-1).`

**Phase P3** (`SKILL.md:270-277`): R2 `... → witness the EFFECT (H-EFFECT-1); regressed → R4 (H-ROLLBACK-1).`
**Golden spec** (`skill-design.md:80-81`): R2 NEAR-MISS-to-reject = `exit-0 "looks fixed"`; R3 = partial/blocked path.
**Recency echo** (`SKILL.md:350-351`): re-states H-EFFECT-1 + H-ROLLBACK-1.

The "F1 fix" referenced in `skill-design.md:37,104` is the **credential-expiry 7th surface** (SURFACE=unknown→routes), NOT the effect-gate. The brief conflated the two. The effect-witness gate has its own hypothesis ids (H-EFFECT-1 / H-ROLLBACK-1), full DF3 integration, P3 wiring, and recency echo — fully landed. `A1 FACT` — SKILL.md:149-151, 226-241, 270-277, 350-351.

---

## Claim 8 — references carry non-empty `description` frontmatter — CONFIRMED (sampled 13/13)

Sampled ALL 13 reference files (not just 4-5). Every one has a non-empty `description`:

| Reference | description present | type |
|---|---|---|
| classification-spine.md | YES | reference |
| eneco-clis-and-tools.md | YES | reference |
| eneco-important-repos.md | YES | reference |
| eneco-skills-to-use.md | YES | reference |
| mc-avd-execution-boundary.md | YES | reference |
| obsidian-eneco-assets.md | YES | reference |
| slack-channels.md | YES | reference |
| troubleshooting/surface-azure-resource-alert.md | YES | reference |
| troubleshooting/surface-gitops-argocd.md | YES | reference |
| troubleshooting/surface-identity-credential-expiry.md | YES | reference |
| troubleshooting/surface-messaging-servicebus.md | YES | reference |
| troubleshooting/surface-openshift-runtime.md | YES | reference |
| troubleshooting/surface-pipeline-ado.md | YES | reference |
| troubleshooting/surface-terraform-iac-apply.md | YES | reference |

`A1 FACT` — frontmatter extracted from each file, lines 1-5.

---

## Schema consistency (the builder-template question)

**All 14 reference frontmatters follow ONE consistent schema:** `title` (quoted string) + `description` (quoted string) + `type: reference`. No inconsistencies that would complicate a builder template. Specifically:

- Field order identical across all files: `title` → `description` → `type`.
- `type` is uniformly `reference` (never `surface`, `troubleshooting`, etc. — even the 7 surface refs use `type: reference`).
- All descriptions follow a "WHEN/WHAT-it-gives" register (e.g. "Failure-surface reference for … : <contents>"), consistent with C1's `load WHEN → gives` heuristic.
- **One schema divergence to note (NOT a problem, but builder-relevant):** `skill-design.md` (the sibling design doc, NOT a reference) uses a DIFFERENT frontmatter schema — `task_id / agent / status / summary` (`skill-design.md:1-6`). This is correct (it is a harness artifact, not a reference), but a naive builder template that globs all `*.md` frontmatter would see two schemas. Reference files = `title/description/type`; design/provenance file = `task_id/agent/status/summary`.

**Builder-template verdict:** the reference schema is clean and uniform — safe to encode as `title:str, description:str, type:"reference"` for the meta-skill's reference-builder heuristic.

---

## Evidence summary

- STRUCTURAL-FACT (A1, file:line + quoted body): claims 1,2,3,4,5,6,7,8 — all eight.
- INTENT-SPECULATED: none load-bearing; the brief's "after F1 fix lands" hedge for #7 is disproven by structural fact, not speculation.
- A3 UNVERIFIED[blocked]: existence/behavior of `validate-calibration.sh` (referenced in skill-design.md:116) — not probed; not load-bearing for the 8 claims.

## Catch-the-overclaim verdict

The brief is accurate on 7 claims and **over-cautious (not over-claiming)** on claim #7 — it hedged that the effect-gate might be absent when it is in fact fully present and well-integrated. For the meta-skill encoding: **trust claim #7's pattern — the effect-witness gate is real and is the strongest single template in the exhibit** (H-EFFECT-1 + H-ROLLBACK-1 + DF3 close-rule + R4 escalation). The only correction a builder must carry: claim #4's "verified commands" provenance lives in the design-doc evidence ledger, not inline in the reference, and claim #1's Reference Map is a *grouped linked inventory* (group=trigger-class, entry-tail=value, some inline WHEN) rather than a strict uniform `load WHEN→gives` per line.
