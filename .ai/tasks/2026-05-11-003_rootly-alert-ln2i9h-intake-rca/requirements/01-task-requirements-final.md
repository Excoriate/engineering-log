---
task_id: 2026-05-11-003
agent: claude-code
status: pending_review
summary: Rootly alert ln2I9h intake (eneco-oncall-intake-rootly) + holistic RCA artifact (rca-holistic) at named external path — final requirements
---

# Task Requirements — Final (P3 Confirm)

> **Diff vs initial**: H3 (workspace mismatch) downgraded from probe-required to
> probe-resolvable (script will succeed or surface specific error); Success
> Criteria 5 now binds to rca-holistic's contract clauses verbatim; Verification
> Strategy section added per brain protocol; falsifier set expanded with two
> P4-resolvable falsifiers below.

## 🎯 Request (unchanged)

Intake Rootly alert short ID `ln2I9h` (URL `https://rootly.com/account/alerts/ln2I9h`)
via `eneco-oncall-intake-rootly`, then produce a holistic RCA via `rca-holistic`
at:

```
/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_05_11_rootly_alert_cpu_throtling/
```

Destination folder slug `cpu_throtling` (sic) is a derived-surface hint — NOT
a verified diagnosis. The diagnosis comes from the canonical Rootly alert
payload after L-ROOTLY-ALERT fetch.

## 🔁 Socrates pass on P2 conclusions

| Claim from P2 | Challenge | Status after challenge |
|---------------|-----------|------------------------|
| "Folder slug hints CPU throttling" | What if the slug is a placeholder typed in haste? What if it's a generic "throttling" theme regardless of resource? | UNVERIFIED — held; falsifier L-ROOTLY-ALERT.metric ≠ CPU-like |
| "MC-VPP-Infra repo at memorized path is reusable" | Has the repo path moved? Has the branch convention changed (main vs master)? | Confirmed by `ls -d`; main branch present |
| "rca-holistic skill enforces adversarial review pre-complete" | Have I actually read rca-holistic to confirm this is part of its contract, or am I assuming from the skill description? | UNVERIFIED — must read skill before invoking in P7; will load via Skill tool |
| "Pattern of structural conventions mirrored from prior on-call shifts" | Does my chosen mirror (gurobi 2026-03-27 / stefan-redis 2026-04-21) actually fit a CPU/compute throttling alert, or am I shape-matching? | Provisional — final structure decided by rca-holistic contract, not my pattern guess |

## ✅ Success Criteria (refined, externally-witnessable)

1. **Alert resolved**: `rootly-alert-decode.sh --short-id ln2I9h` returns a
   non-empty JSON payload (HTTP 200 + payload schema fields present). Witness =
   external CLI output preserved in `context/`.
2. **Eight triage fields populated**: WHAT, SEVERITY, WHERE, WHEN, CONDITION,
   STATUS, INVESTIGATE, ESCALATION extracted from the payload (the 8-field
   triage of `eneco-oncall-intake-rootly` Phase 0). Witness = `context/alert-decoded.md`.
3. **Mode reasoned, stated, applied**: one-line rationale citing the firing
   condition that selected the mode; user directive ("write the RCA") fixes
   the route to deep-enrich (terminal in personal log — see Phase 6D below).
4. **Mechanism chain ≥ depth 2** with cited evidence per causal hop (file:line
   OR cmd:output OR doc URL). Witness = `outcome/rca.md` (or named per
   rca-holistic) with A1/A2/A3 claim classifications.
5. **rca-holistic contract honored**: load the skill; populate every required
   section (business purpose, repo/service architecture, runtime topology, IaC,
   pipeline, timeline, fix, verification, lessons, command playbook, on-call
   recognition path); pass the skill's adversarial review gate before
   status=complete. Witness = adversarial review artifact under
   `verification/` or per rca-holistic's spec.
6. **manifest.gate_witnesses populated** at delivery with ≥1
   external-agent-artifact OR external-runtime-output per load-bearing claim.
7. **Phase 6D route stated**: which condition fired (terminal vs handover);
   decision recorded in `context/`.

## 🔬 Hypotheses (refined post-Socrates pass)

| H | Statement | Falsifier (P4-resolvable) |
|---|-----------|----------------------------|
| H1 | Recurring CPU-throttling on a VPP compute resource (matches folder slug) | L-ROOTLY-ALERT.metric ∉ {Percentage CPU, CPU Throttled, ContainerCpuThrottled, NodeCpuThrottled, max_cpu_percent} |
| H2 | Folder slug `cpu_throtling` is a quick-typed working name; actual class differs (SQL DTU, Cosmos 429, request throttling, throttled-requests) | L-ROOTLY-ALERT.metric ∈ CPU-family set above |
| H3 | Alert is from Eneco workspace and short ID resolves cleanly | Script returns HTTP 401/403/404 or "alert not found" |
| H4 | Same rule has fired before (Known pattern; auto-resolves) | L-ROOTLY-HISTORY returns <2 same-rule firings in last 30 days |
| H5 | Threshold for this metric is IaC-declared in MC-VPP-Infrastructure | Rule's `targetResourceType` doesn't correspond to anything in MC-VPP repo OR rule was created via portal (no Terraform owner tag) |

Hypotheses are mutually informative — H1 and H2 are exclusive; H4 and H5 may
co-vary with H1/H2.

## 🧪 Verification Strategy [REQUIRED for P3 gate-out]

| Concern | Acceptance shape | Witness (≠ producer) | Truth surface |
|---------|------------------|----------------------|---------------|
| Canonical alert resolved | JSON payload with non-empty `data` field + `attributes.title` + `payload`; HTTP 200 | `rootly-alert-decode.sh` stdout — script ≠ coordinator; verified by `jq` on saved JSON | External Rootly API |
| Diagnosis depth ≥ 2 | RCA includes proximate cause + enabling cause + (if HIGH) design cause, each with cited evidence line | rca-holistic adversarial reviewer (typed subagent ≠ coordinator) reads and grades | Reviewer artifact under `verification/` |
| Threshold rationality observed (not recommended) | Section in RCA explicitly states observation + halts before recommending change | Socrates-contrarian challenge on observation-vs-recommendation boundary | `verification/socrates-threshold-discipline.md` |
| External path write authorized | `manifest.allowed_external_paths` contains exact destination prefix; PostToolUse hook does not block | Hook return code = 0 on writes to destination | Runtime hook |
| Skill chain honored | rca-holistic Skill tool invocation logged + skill output gates fired | rca-holistic produces its own adversarial-review artifact | rca-holistic skill internal contract |

## 🔁 Verify Strategy Delta vs P1

| P1 Implicit | P3 Explicit | Reason for Δ |
|-------------|-------------|--------------|
| "≥1 witness per load-bearing claim" generic | Witnesses ENUMERATED per concern in table above | Brain protocol requires `## Verification Strategy` with acceptance/witness/truth-surface |
| "Adversarial review (rca-holistic requires it)" assumed | Adversarial review delegated to rca-holistic's internal contract + tracked in `verification/` | Need to honor rca-holistic's spec, not invent my own |
| Phase 6D "decision STATED" generic | Phase 6D = TERMINAL because user explicitly directed RCA artifact at named path (not handover to enrich for a fix PR); decision = "write the RCA, don't escalate to enrich" | User-bounded scope makes this auto-terminal regardless of mechanism class |

## 🚦 Compression Mode confirmed: Normal

CRUBVG = 5; investigation route; multi-source synthesis; load-bearing deliverable.

## ⛔ What this task is NOT

- Not an action on the alert (no ack, no resolve — read-only).
- Not a recommendation to change thresholds (per `references/threshold-sanity.md` discipline — observe, don't recommend).
- Not a handover to enrich — destination is the RCA artifact in personal log.
- Not a fix or PR — pure RCA + on-call recognition playbook.
