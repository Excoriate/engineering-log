---
task_id: 2026-05-11-001
agent: claude-code
status: partial
summary: Initial requirements mirror of NN-3 pre-flight for the on-call week knowledge harvest task.
---

# 01 — Initial Task Requirements

## Verbatim User Request

> Today, I've worked on these issues; check the issues opened with today's date on `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift`. You will check my knowledge in my vault's second brain (`/2ndbrain-obsidian`).
>
> The range is 1 week, from today inclusive.
>
> 1. Go through `/eneco-context-slack` to get all what occurred today in Myriad Platform Slack channel, for the request, and issues reported, and extract the knowledge that's valuable, to be built on my 2nd brain.
> 2. Go through our private channel (`#team-platform`), to do the same as point 1.
> 3. From these issues tackled today, extract the knowledge to precisely, enrich connections, and create/update add more knowledge into my brain (use `/2ndbrain-knowledge-create` and `/2ndbrain-knowledge-check` after all these steps).
>
> I'm not going to babysit you, you have all the skills required, so you can proceed autonomously. Knowledge is the key! the brain is being used by me, and my agents; so KNOWLEDGE IS GOLD!

## Pre-Flight Mirror

- **Phase**: 1 / **task_id**: 2026-05-11-001 / **slug**: oncall-week-knowledge-harvest
- **Today**: 2026-05-11 (from CLAUDE.md currentDate block)
- **1-week window**: 2026-05-04 → 2026-05-11 inclusive
- **Domain-class**: knowledge (investigation + build + review composite)
- **Control-plane**: y (vault is durable agent-consumed memory)
- **CRUBVG**: 2/1/2/2/1/1 = 9 → Full mode + external adversarial mandatory
- **Slack-skill availability**: `/eneco-context-slack` (skill file lists workspace and channel patterns)
- **Vault-build skill**: `/2ndbrain-knowledge-build` (user said "create" — closest semantic skill; no route-flipping ambiguity)
- **Audit skill**: `/2ndbrain-knowledge-check`

## Success Criteria (USER-witnessable)

1. New/strengthened notes in `$SECOND_BRAIN_PATH/llm-wiki/` zones for every durable insight from today's logs + 1w Slack — semantic English filenames + bidirectional links + Knowledge-DNA frontmatter.
2. Lessons promoted to `.ai/memory/lessons-learned.json` via dual-path protocol (markdown FIRST, then JSON).
3. `/2ndbrain-knowledge-check` reports 0 P0 findings on newly-created surfaces.
4. Coverage manifest: today's incident set → vault notes mapping.
5. Handoff entry written for next session.

## Load-Bearing Assumptions (NN-3 surface)

| # | Assumption | Class | Falsifier | Route impact if false |
|---|------------|-------|-----------|-----------------------|
| LBA-1 | Today's date is 2026-05-11 per CLAUDE.md currentDate | A1 FACT | Different date in fresh `date` probe | Slack window + log-dir glob shift |
| LBA-2 | At least one `2026_05_11_*` dir exists in `02_on_call_shift/` | A3 UNVERIFIED | `find` returns 0 results | Ask user — no source to harvest |
| LBA-3 | `$SECOND_BRAIN_PATH` points to a valid vault | A2 INFER (from CLAUDE.md memory) | `ls $SECOND_BRAIN_PATH/llm-wiki/_index.md` fails | HALT vault writes → `[UNVERIFIED[blocked]]` |
| LBA-4 | `eneco-context-slack` can reach both #myriad-platform and #team-platform | A2 INFER | Skill returns 0 results from both | Document & continue with logs-only path |
| LBA-5 | "1 week, today inclusive" = 2026-05-04 → 2026-05-11 | A1 FACT (linguistic) | User clarifies otherwise | Window shifts |
| LBA-6 | User's `/2ndbrain-knowledge-create` resolves to `/2ndbrain-knowledge-build` | A2 INFER | Semantic mismatch surfaces during build | Re-route per available skills |

## Verification Strategy (filled later, P3)

- Truth surfaces: filesystem (`ls`, `find`), vault structure (`_index.md`), `lessons-learned.json` validity, `/2ndbrain-knowledge-check` output, sample-read.
- Adversarial frame: `simplicity-maniac` (Hickey) on synthesis plan + `/2ndbrain-knowledge-check` as final evaluator (control-plane → second frame typed adversarial).
- Witness ≠ producer: knowledge-check skill ≠ knowledge-build skill ≠ coordinator.

## Context Universe (initial)

See pre-flight L1..L7 lanes — to be enumerated with identity + first-proof-surface in `phase-2-map.md`.
