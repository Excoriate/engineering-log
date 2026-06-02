---
task_id: 2026-05-13-001
agent: codex
status: working
summary: Final requirements after source and vault-neighborhood inspection.
---

# Final Requirements

## Accepted End-State

The vault has one new BTM note for the missing Hermes/AAD consent mechanism, one May 12 on-call synthesis hub, targeted freshness updates to the Rootly and Service Bus notes, and a verified build ledger plus focused knowledge-check report.

## Explicit Non-Goals

- Do not duplicate the FBE Jupiter incident note because `fbe-errors/2026-05-12-jupiter-source1-credential-gap.md` already owns it.
- Do not claim live Eneco runtime state beyond what the engineering-log sources observed on 2026-05-12.
- Do not import raw Slack text or credentials.

## Route Premises

- FACT: The target vault exists and passed the `2ndbrain-obsidian`, build, and check environment validators.
- FACT: Existing FBE, Rootly, Service Bus, and how-to notes exist in `work-eneco`.
- INFER: BTM/Hermes delegated consent deserves a standalone note because search did not find a canonical owner and the mechanism recurs for new local E2E users.

## Verification Strategy

- Read back all changed files from disk.
- Run `verify-mutation-ledger.sh` on the build ledger.
- Run `verify-check-report.sh` on the focused knowledge-check report.
- Use Obsidian CLI read-back for created notes if available.
- Use targeted `rg` checks for the new retrieval anchors and May 12 freshness markers.

## Remaining Risk

Git history inspection was blocked by the current runtime policy, so history+precedent remains partial. This does not block vault mutation because the source evidence and current vault neighborhood are sufficient for the requested knowledge enrichment.

