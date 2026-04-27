---
task_id: 2026-04-26-001
agent: coordinator
status: complete
summary: Documentation map — what already exists in the on-call shift folder for this incident
---

# Docs map — on-call shift folder

Source: `engineering-log/log/employer/eneco/02_on_call_shift/2026_04_21_stefan_vpp_infrastructure_mfrr/`

| File | Lines | Status | Role for this task |
|---|---|---|---|
| `slack-antecedents.txt` | 9 | reference | Original Slack ticket from Stefan + permalinks. **Input only.** |
| `diagnosis-and-fix-spec.md` | 46 | reference | Spec for the prior diagnosis deliverable (acceptance criteria for the *prior* author). |
| `diagnosis.md` | 307 | superseded | First-pass diagnosis — content of this is rolled into `systemic-diagram-and-verified-diagnosis.md`. Re-read only if needed for evidence cross-checking. |
| `systemic-diagram-and-verified-diagnosis.md` | 247 | input | **Primary input** — author claims A1 FACT verification on every load-bearing claim. User opened this in IDE. Must verify representative subset before committing fix. |
| `systemic-diagram-mermaid.md` | 146 | reference | Mermaid alternative to the ASCII diagram in `systemic-diagram-and-verified-diagnosis.md` §1; same content, different render. |
| `slack-reply-draft.md` | 51 | reference / draft | Author's earlier reply draft. Will be **superseded** by `slack-response.md` deliverable; uses the drafting voice already validated. |

## Deliverable target paths (per user request, in this same folder)

- `explanation-of-fix-and-issue-holistic.md` — NEW
- `pr-description.md` — NEW
- `slack-response.md` — NEW (replaces the older draft)

## Authorship continuity

All prior docs are by the same agent (`claude-code`, prior task `2026-04-21-001`). Per the brain's *Agent Laundering* rule, those FACT classifications are INFER for the current task until I independently re-probe a representative subset of load-bearing claims (Phase 4).
