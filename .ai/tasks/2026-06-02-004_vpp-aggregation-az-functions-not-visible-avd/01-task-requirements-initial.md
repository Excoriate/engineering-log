---
task_id: 2026-06-02-004
agent: claude-opus-4-8
status: draft
summary: Initial requirements mirror for on-call incident "vpp aggregation az functions not visible avd" — pre-intake-read state.
---

# 01 — Task Requirements (Initial, Pre-Intake)

## Request (verbatim intent)

Handle an Eneco VPP on-call operational incident/request located at:
`log/employer/eneco/02_on_call_shift/2026_june/2026_06_02_vpp_aggregation_az_functions_not_visible_avd/`

User constraints (verbatim):

- "Ensure max. verification. No space for assumptions."
- "Ensure max. quality, and reliability."
- "Ensure you're discovering and using other /eneco-* skills if needed, besides the one indicated in the .md on the folder of the task."

Output contract (verbatim): outcomes/output documents must be generated for the user; duplicating
from `.ai/...` into the user's log folder is acceptable for quick study access.

## Preflight Mirror (NN-3)

- Phase: 1 | task_id: 2026-06-02-004
- DOMAIN-CLASS: investigation | CONTROL-PLANE-ARTIFACT: no
- CRUBVG: 2/0/2/2/1/2 = 9 → FULL mode, external adversarial mandatory
- Compression Mode: FULL

## Success Criteria (externally witnessable)

1. Incident understood from the ACTUAL intake artifact (`slack-intake.md`), not the folder name.
2. RCA with A1/A2/A3 evidence labels; every load-bearing claim probed or marked `A3 UNVERIFIED[blocked]`.
3. Fix + verification steps that the next on-call engineer can execute.
4. Reader-facing outputs present in BOTH `$T_DIR` and the named log folder.
5. Passed external adversarial review + anti-slop gate before status=complete.

## Open Unknowns (to resolve in P2/P4)

- What "not visible" means (Azure portal vs AVD desktop vs aggregation output vs alert).
- Which environment (dev / acc / prd / sandbox).
- Whether "AVD" = Azure Virtual Desktop or an internal acronym.
- Which Azure Functions / which VPP aggregation component.

## Context note

Multiple parallel on-call tasks exist today (btm-pipeline-failed-git-error,
vpp-aggregation-layer-sandbox-broken, vpp-aggregation-layer-kafka-certs-dev-test). This task is a
DISTINCT incident — verify it is not a duplicate of those during mapping.
