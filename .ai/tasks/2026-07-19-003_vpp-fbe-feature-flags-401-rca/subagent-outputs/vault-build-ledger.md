---
task_id: 2026-07-19-003
agent: 2ndbrain-knowledge-build (socrates-gated subagent)
summary: "Corrected vault F22 + LL-036 from transient/self-heals to permanent frozen-snapshot credential drift; 3 notes updated, 2 backlinked, 1 deliberate no-create; adversarially gated."
description: "Build ledger for VPP FBE feature-flag 401 -> frozen-snapshot credential drift correction on 2026-07-19 20:01:07"
total_sources: 13
total_decisions: 6
created: 0
updated: 3
merged: 0
split: 0
linked_only: 2
skipped: 1
status: complete
---

# Mutation Ledger — VPP FBE feature-flag 401 = frozen-snapshot credential drift (vault build)

Second brain: `/Users/alextorresruiz/Documents/obsidian`. Skill: `2ndbrain-knowledge-build` (transport via `2ndbrain-obsidian` MCP `patch_note` / `update_frontmatter`). All writes are EXTERNAL to the engineering-log repo (vault). Goal: correct the vault's stale "transient / self-heals / NONE needed" framing (F22, LL-036) to the RCA-proven **permanent frozen-snapshot credential drift**, without swapping one overconfidence for another, and ripple the graph. Adversarially gated by a `socrates-contrarian` reviewer (receipt: `subagent-outputs/socrates-vault-build-challenge.md`) BEFORE any write.

## Source Inventory

| # | Path | Type | Status |
|---|------|------|--------|
| 1 | engineering-log `.../2026_07_18_001_vpp_frontend_fbe_feature_flags_401/output/rca.md` | RCA (source of record) | consulted |
| 2 | `.../output/how-to-fix.md` | fix ladder + one-way-doors | consulted |
| 3 | `.ai/tasks/2026-07-19-003_.../context/live-probe-findings.md` | A1 evidence ledger | consulted |
| 4 | `.ai/tasks/2026-07-19-003_.../context/obsidian-vault-extract.md` | prior neighborhood map (N1-N6) | consulted |
| 5 | vault `2-areas/work-eneco/eneco-vpp-platform/fbe/fbe-failure-modes-catalog.md` (F22) | existing note | UPDATED |
| 6 | vault `llm-wiki/learnings/lessons/fbe-feature-flags-browser-direct-appconfig-per-slot-store.md` (LL-036) | existing note | UPDATED |
| 7 | vault `llm-wiki/learnings/lessons/eneco-appconfig-401-vs-403-caller-discrimination.md` | existing note | UPDATED |
| 8 | vault `llm-wiki/learnings/lessons/green-status-is-not-realized-effect.md` | existing note | LINKED |
| 9 | vault `llm-wiki/learnings/lessons/kubernetes-running-ready-does-not-imply-functional.md` | existing note | LINKED |
| 10 | vault `llm-wiki/patterns/debugging/_index.md` + `http-status-localizes-the-failing-layer.md` | placement precedent | consulted |
| 11 | vault `llm-wiki/patterns/workflows/argocd-...-three-layer-config-stack.md` | contrast pattern | consulted |
| 12 | vault `2-areas/.../fbe/_index.md` + `llm-wiki/learnings/lessons/_index.md` | folder contracts | consulted |
| 13 | `subagent-outputs/socrates-vault-build-challenge.md` | adversarial receipt (9 MUST-FIX) | consumed |

## Operation Decisions

| # | Op | Target (vault-relative) | Rejected alternative | Why + what changed |
|---|----|--------------------------|----------------------|--------------------|
| 1 | updated | 2-areas/work-eneco/eneco-vpp-platform/fbe/fbe-failure-modes-catalog.md | leave F22 as "transient/self-heals" | RCA A1 fleet evidence (5/6 slots stale, restarts=0) falsifies "transient"; changed F22 title, mechanism-class label, `recurrence_status: active_inherent`, mechanism-class index row (F8, F22), Symptom→F# matrix split into 401 + HTTP 000 rows, frontmatter description + dates |
| 2 | updated | llm-wiki/learnings/lessons/fbe-feature-flags-browser-direct-appconfig-per-slot-store.md | silently overwrite the "Self-resolved" root cause | A9/A10: added Correction section (mechanism, 2 surface variants, drift recipe, permanent-fix ladder, Reloader-gap generalization), re-labeled June root cause superseded (text + meta-lesson kept), primary-WRITE-key fidelity, RCA + backlinks, frontmatter dates+tags |
| 3 | updated | llm-wiki/learnings/lessons/eneco-appconfig-401-vs-403-caller-discrimination.md | leave unconnected | added fourth-caller (frontend browser HMAC) trap: frozen-snapshot 401 = pod restart NOT re-run IaC, plus HTTP 000 variant; Related link; frontmatter date |
| 4 | linked_only | llm-wiki/learnings/lessons/green-status-is-not-realized-effect.md | none | bidirectional backlink to LL-036 (ArgoCD Synced ≠ rolled is the parent principle) |
| 5 | linked_only | llm-wiki/learnings/lessons/kubernetes-running-ready-does-not-imply-functional.md | none | bidirectional backlink to LL-036 (healthz ≠ functional parent) |
| 6 | skipped | llm-wiki/patterns/debugging/frozen-snapshot-credential-drift.md | create the standalone pattern note | NO-CREATE — adversarial Lanes C+D: one-system evidence + placement-boundary violation (see "Note NOT created" below) |

`created(0) + updated(3) + merged(0) + split(0) + linked_only(2) + skipped(1) = 6 = total_decisions`.

## Note NOT created (and why) — the deliberate no-create

**Proposed:** a new canonical note `frozen-snapshot-credential-drift.md` generalizing the mechanism.
**Decision: DEFER (do not create now).** Two adversarial findings, both accepted:

- **Lane C (sprawl):** the mechanism has 2 incidents (June + July) but **ONE system** (the VPP FBE frontend `appconfig.js`) — one system observed twice, not a cross-system pattern. `patterns/debugging/_index` bar is "confirmed in ≥2 occurrences" as a repeatable cross-context pattern. It also substantially overlaps two existing parents (`green-status-is-not-realized-effect`, `kubernetes-running-ready-does-not-imply-functional`); the unique increment (the "Reloader gap") is now captured as a labeled section inside LL-036 + backlinked from both parents, so the reusable knowledge is findable without a thin new node.
- **Lane D (placement):** a generic K8s/Azure credential-drift heuristic is technology-specific, which BOTH contracts route to `3-resources/` (`fbe/_index` line 116; `patterns/debugging/_index` line 22), NOT `llm-wiki/patterns/debugging/`. The `http-status-localizes-the-failing-layer` sibling is a stretched de-facto exception, weaker precedent than a stated contract.

**Reopen trigger:** create the note (in `3-resources/`, not llm-wiki) when a SECOND distinct system exhibits the frozen-snapshot / Reloader gap, or when a deliberate generic 3-resources K8s note is warranted. Recorded so future-me does not re-derive.

## Filename Decisions

No new file created, so no filename chosen. Candidates that were ranked (for the reopen trigger): `frozen-snapshot-credential-drift.md` (concept-first, matches RCA term) > `csi-rotates-the-secret-but-nothing-rolls-the-consumer.md` (slogan, matches sibling naming style) > `rotated-credential-does-not-roll-a-pod-that-baked-it-once.md`. Winner deferred with the note itself.

## Socrates Findings

Receipt: `socrates-vault-build-challenge.md` — 9 MUST-FIX, all ACCEPTED.

- **A (overconfidence swap) — ACCEPTED:** wrote the destroy→recreate regeneration as `[A2 INFER]` (RCA claim-table line 219) and kept the `[A3]` "per-slot ordering not reconstructable; `application-secret` can lag; verify vs live Azure store" caveat (RCA L7 line 141). "Permanent" = standing architectural gap, not "never recovers".
- **B (self-heal semantics) — ACCEPTED:** replaced "self-heals"/"does NOT self-heal" with "cannot self-refresh; recovers only on a pod restart (June's was incidental)"; set `recurrence_status: active_inherent`; named BOTH surface variants (401 store-resolves vs HTTP 000 store-deleted) in F22 symptom + added the HTTP 000 row to the Symptom→F# matrix.
- **C (new-note sprawl) — ACCEPTED:** no standalone note; strengthened LL-036 + bidirectional backlinks to the two parent lessons.
- **D (placement boundary) — ACCEPTED:** did not place in llm-wiki/patterns/debugging.
- **Silence audit — ACCEPTED:** retained the "do NOT rotate keys / re-run IaC / destroy the store / touch dev-mc" guardrails (destroying the store regenerates the drift); marked LL-036's old root cause superseded (not overwritten) + kept the meta-lesson; Reloader stated as `[A2 — not installed today]` with the 13-key side-effect caveat; "5 of 6 slots" written as a dated 2026-07-19 snapshot; F22 metadata (title, mechanism-class label, recurrence_status) changed, not just prose.

Zero findings Rebutted, zero Deferred-improperly. Plan materially changed from the pre-review draft (which would have written "PERMANENT ... on slot recreate" as fact and created a new llm-wiki pattern note).

## Claim Provenance

| Claim in the notes | Class | Verification | Evidence |
|--------------------|-------|--------------|----------|
| Frontend bakes HMAC conn string once into emptyDir `appconfig.js` (init `init-myservice`); no Reloader/checksum; healthz-only probe; CSI keeps `application-secret` current | extraction | tool-verified (live probes 2026-07-19) | RCA L4/L5, live-probe-findings §"NO refresh mechanism" |
| 5 of 6 active slots serve a since-deleted store (frozen-snapshot drift) on 2026-07-19 | extraction | tool-verified | RCA L7 drift table; live-probe-findings drift table |
| Store name regenerates (new name + new HMAC keys) on slot destroy→recreate (random_string ForceNew) | inference `[A2]` | source-asserted (RCA labels A2; not re-probed) | RCA claim 3 (line 219) |
| Per-slot recreation ordering not reconstructable; `application-secret` can lag live store | extraction `[A3]` | source-asserted | RCA L7 "Timeline honesty A3" (line 141) |
| Permanent fix = pipeline rollout-restart + Stakater Reloader (NOT installed) + read-only key + dynamic appconfig.js | inference `[A2]` | source-asserted; Reloader absence tool-verified | RCA L8 / how-to-fix P1-P4; live-probe (Reloader absent) |
| Browser gets the **primary WRITE** key (`app_configuration_primary_write_key_connection_string`) | extraction | tool-verified (TF source) | RCA L5 line 104/114 |
| "Reloader gap" generalization (out-of-band secret rotated, consumer baked once, nothing rolls it) | synthesis | n/a (cross-note) | derived from RCA + parent lessons; labeled as generalization in LL-036 |

## Coherence and Temporal Checks

- **A8:** the corrected F22/LL-036 no longer contradict the RCA; they now agree with `green-status`/`running-ready` (parents) and are cross-linked. The old contradiction (vault said "transient/self-heals" vs RCA "permanent drift") is resolved by supersession, not silent overwrite.
- **A9:** June "self-resolved" framing preserved but explicitly superseded + dated; "5 of 6 slots" marked as a 2026-07-19 snapshot; `recurrence_status: active_inherent`; `last_validated`/`updated` bumped to 2026-07-19 on all three content-updated notes.
- **A10:** original June root-cause text retained verbatim under a "superseded framing" heading with the conclusion corrected to "incidental pod rebuild".
- No new subfolders created; no `_index.md` mutated; PARA boundaries respected (Eneco specifics stayed in fbe/ + llm-wiki lessons; no generic note pushed into llm-wiki).

## Verification

- All 15 `patch_note` calls returned `matchCount: 1` (no multi-match, no silent overwrite).
- Read-back greps confirm: F22 corrected heading/mechanism-class/recurrence present; stale "self-heals" framing GONE from F22; LL-036 Correction + "Reloader gap" + "superseded framing" + primary-WRITE-key + Superseding-RCA present; 401-vs-403 fourth-caller trap + Related link present; both parent backlinks present.
- `get_frontmatter` parses cleanly on catalog (updated/last_validated=2026-07-19) and LL-036 (last_validated=2026-07-19, new tags).
- LL-036 code fences balanced (4 = 2 blocks).
- Dead-link check: every added `[[wikilink]]` target exists on disk (fbe-feature-flags-browser-direct-appconfig-per-slot-store, fbe-failure-modes-catalog, eneco-appconfig-401-vs-403-caller-discrimination, green-status-is-not-realized-effect, kubernetes-running-ready-does-not-imply-functional, argocd-...-three-layer-config-stack). No dead links introduced.
- `scripts/verify-mutation-ledger.sh`: ALL format / accounting / required-section checks PASS. Its final `status: complete` filesystem link pass exits 1 on **3 PRE-EXISTING catalog wikilinks outside this build** — `[[_index|fbe folder index]]` (ambiguous: 119 `_index.md` folder-notes) and two `[[../fbe-errors/...]]` relative-path F21 cross-links — which the verifier's flat basename resolver cannot handle (Obsidian resolves them fine). These predate this build and were not edited; fixing them is out of scope. Every wikilink THIS build added resolves to exactly one note (independently confirmed by a per-link vault match count).
- Source of record linked from F22 + LL-036: `engineering-log:log/employer/eneco/02_on_call_shift/2026_july/2026_07_18_001_vpp_frontend_fbe_feature_flags_401/output/rca.md`.

## Closure summary

- **Now answerable:** "Does the FBE feature-flag 401 self-resolve?" → No; permanent frozen-snapshot drift, recovers only on a frontend pod restart. "Why doesn't CSI rotation fix the stale pod?" → out-of-band credential + no Reloader/checksum + healthz-only probe (the Reloader gap). "What are the two surface variants?" → 401 (store resolves, rotated key) vs HTTP 000 (store deleted). "What is the permanent fix?" → pipeline rollout-restart + Reloader (+ read-only key + dynamic appconfig.js). "How do I detect drift?" → compare baked appconfig.js endpoint vs application-secret vs live Azure store.
- **Mastery delta:** the FBE failure catalog now status-routes BOTH the 401 and the HTTP 000 surface to F22; the credential-drift class is bridged to its two generic parents; the stale "wait it out" remediation is retired.
- **Still open:** a generic `3-resources/` "Reloader gap" note (deferred until a 2nd system or a deliberate generic write).
