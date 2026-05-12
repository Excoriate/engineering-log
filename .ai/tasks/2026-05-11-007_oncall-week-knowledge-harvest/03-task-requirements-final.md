---
task_id: 2026-05-11-007
agent: claude-code
status: complete
summary: P3 final requirements — scope confirmed, universe attack done, deltas vs initial recorded, verification strategy hardened.
---

# 03 — Final Task Requirements (P3)

## Scope (CONFIRMED — differs from initial)

| Surface | Initial belief | Final | Change driver |
|---------|---------------|-------|---------------|
| Log range | 1-week dirs under `02_on_call_shift/` | **Today only** (4 dirs); week range collapses for LOGS | `find` returned 0 dirs for 2026-05-04..05-10 |
| Slack range | 1 week, both channels | **Unchanged**: 2026-05-04 → 2026-05-11 inclusive, both `#myriad-platform` + `#team-platform` | None |
| Vault zone routing | Single dump zone | **Per-topic**: `episodes/`, `learnings/{lessons,gotchas,feedback}/`, possibly `patterns/`, possibly `context/`. Technical "how-to" content → NOT llm-wiki (vault routing rule) | P2 read of `learnings/_index.md` |
| Note action mix | Bulk create | **Mixed**: STRENGTHEN ArgoCD (9 existing hits), STRENGTHEN FBE (2 existing), CREATE CPU-throttling (0 hits), CREATE secret-rotation lesson (0 hits), NEW EPISODE per major incident | P2 vault grep |
| Adversarial frame | One evaluator | **Two**: `simplicity-maniac` (Hickey) on synthesis-plan pre-build + `/2ndbrain-knowledge-check` post-build evaluator | Control-plane=y rule + composition rule |

## Universe-Fit Attacks (P3)

1. **Underfetch?** Are 4 on-call dirs the only "today's issues"? Searched `02_on_call_shift/` only — user explicitly named this path. Other dirs (`00_incident_sre/`, `01_trade_platform_team/`) are out of scope per user wording. SKIP-RISK: low.
2. **Overfetch?** Reading all 4 RCAs fully would hit ~500k bytes. Mitigation: targeted offset reads of L1/L8/L10/L11 sections plus `context.md` + `slack-intake.txt`. Falsifier: if extraction is shallow, P5 plan reflects it and triggers expanded reads.
3. **Wrong/stale identity?** "Duncan" is the FBE slot identifier (per dir naming). "CPU throttling" target service unknown until P4 read. "CMC alert" — `CMC` not in ubiquitous language; pending P4 confirmation.
4. **Missing route-flip lane?** Could a missed lane change the route? Candidate: `.ai/memory/lessons-learned.json` entries beyond LL-001..LL-005 — confirmed all 5 entries are in scope and reviewed. Candidate: `3-resources/` for existing technical Eneco notes — pending P4 probe.
5. **Verify-strategy delta?** Unchanged from P1 — `/2ndbrain-knowledge-check` post-build is mandatory for control-plane=y; `simplicity-maniac` on synthesis plan is mandatory because the synthesis decision is itself a complecting risk (Slack/log/vault state braid).

## Verification Strategy (final)

- **Truth surfaces**: filesystem (`ls`, `find`), vault structure (`_index.md`), `lessons-learned.json` schema validity (jq), `/2ndbrain-knowledge-check` audit output (P0/P1/P2 grading), sample-read 30%+ of new notes for citation integrity.
- **Adversarial frames (typed)**:
  - `simplicity-maniac` after P5 plan — attack note-boundary complecting (one note per *concept* vs per *incident*?), state-derived-from-Slack vs state-derived-from-log distinction.
  - `/2ndbrain-knowledge-check` after P7 — vault audit on newly-created surfaces; must report 0 P0 findings.
- **Witness ≠ producer**: knowledge-build skill writes; knowledge-check skill audits; coordinator orchestrates; simplicity-maniac attacks the plan.

## Updated Load-Bearing Assumptions

| # | Assumption | Class | Falsifier |
|---|------------|-------|-----------|
| LBA-1 | Today = 2026-05-11 | A1 FACT | n/a (anchored by CLAUDE.md currentDate + filesystem mtime alignment) |
| LBA-2 | 4 on-call dirs is the complete set for today | A1 FACT (probed) | `find` re-run differs |
| LBA-3 | Vault at `/Users/alextorresruiz/Documents/obsidian` is valid | A1 FACT (probed) | `_index.md` exists |
| LBA-4 | `/eneco-context-slack` will return non-trivial harvest for both channels | A2 INFER | Skill returns empty → continue with logs-only |
| LBA-5 | `/2ndbrain-knowledge-build` is the correct skill name (user said "create") | A1 FACT (only build exists; semantic match) | n/a |
| LBA-6 | Stray `.env.tmp` is NOT secret material related to my task | A3 UNVERIFIED[blocked: do not open file] | Surface to user as security flag |

## Update Manifest

- `allowed_external_paths`: add `/Users/alextorresruiz/Documents/obsidian/llm-wiki/**` once P5 names exact target files.
- `pending_adversarial_dispatches`: will populate before P5/P7 dispatch of `simplicity-maniac` and `2ndbrain-knowledge-check`.

## Phase Transition (2→3 narrative)

Phase 2 revealed: (a) week range collapses to today for LOGS; (b) vault has substantial ArgoCD coverage already → strengthen-mode dominant for ArgoCD; (c) CPU-throttling + secret-rotation are vault-empty → full create-mode; (d) routing rule forbids dumping technical "how-to" into llm-wiki. What I was most wrong about going in: assumed the week range would dominate the log harvest — it dominates the SLACK harvest only. Most dangerous remaining unknown: whether `#team-platform` carries unique decisions distinct from `#myriad-platform`; H2 unverified.
