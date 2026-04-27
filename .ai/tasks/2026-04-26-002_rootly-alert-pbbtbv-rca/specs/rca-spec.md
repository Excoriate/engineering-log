---
task_id: 2026-04-26-002
agent: claude-opus-4-7
status: complete
summary: Spec for the on-call RCA artifact — sections, frontmatter, evidence anchors, FACT/INFER labelling.
---

# Spec — RCA Artifact for Rootly alert pbbtBV

## File

- Path: `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/shift_alerts_summary/2026-April (20-26)/2026-04-26_pbbtBV_kv-vppagg-bootstrap-d-latency.md`
- Encoding: UTF-8 markdown.
- Front-matter (mandatory; aligned with engineering-log frontmatter validator):
  ```yaml
  ---
  title: <human title>
  type: oncall-alert-rca
  alert_short_id: pbbtBV
  alert_source: azure
  alert_status: <state at write time>
  environment: development
  severity: Sev2
  fired_at_utc: 2026-04-26T03:56:24Z
  status: complete
  created: 2026-04-26
  tags: [oncall, rootly, key-vault, ccoe, vppagg, bootstrap]
  ---
  ```

## Sections (ordered, top-to-bottom)

1. **TL;DR** — 3 lines max. Verdict (false-positive / real / unknown), recommended action, follow-up.
2. **Identity** — table of alert + resource + subscription + action group.
3. **Mechanism (Why it fired)** — prose: condition crossed + Azure-side mechanics.
4. **Recommended Action** — explicit ack/resolve/escalate guidance for the on-call engineer. **Must be readable in <30 seconds without scrolling past Mechanism.**
5. **Upstream Recommendation** — module-owner work (file an issue / PR template).
6. **Evidence** — inline tables and cmd outputs anchored to `$T_DIR/context/02-evidence-summary.md`.
7. **Hypothesis Ledger** — H1/H2/H3 with status + evidence ref.
8. **Residual Risk** — list of things this RCA does NOT prove.
9. **References** — links to IaC files, evidence dump, sibling alert.

## FACT / INFER / UNVERIFIED

Every load-bearing claim labelled with `(FACT)`, `(INFER)`, `(UNVERIFIED[assumption: …])`, or `(UNVERIFIED[unknown: no probe])`. No silent FACT promotion.

## Evidence anchors

- Inline-quote key cmd output (so file is self-contained even if `$T_DIR` is rotated).
- Cross-link to evidence dump at `../../../.ai/tasks/2026-04-26-002_rootly-alert-pbbtbv-rca/context/02-evidence-summary.md` for raw payload.

## What the RCA must NOT contain

- No remediation IaC (no PR-ready code).
- No Slack message draft (user hasn't asked).
- No incident-creation guidance (the alert is benign, no need to create an incident).
- No paging changes.
- No git commands, no `az` commands the on-call would not run themselves.
- No emojis.

## Voice

- Terse, on-call style. Active voice. No hedging filler.
- "It fired because X" not "It is hypothesized that X may have caused Y".
- Sibling style reference: `2026_04_21_stefan_redis_alerts/` artifacts in engineering-log.
