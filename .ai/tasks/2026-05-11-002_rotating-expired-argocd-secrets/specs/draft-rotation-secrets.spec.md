---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: draft
summary: Spec — draft-rotation-secrets.md (harvest doc)
phase: 6
---

# Spec — `draft-rotation-secrets.md`

## Purpose

Single-document harvest of every claim about the 4 ArgoCD PAT secrets, with explicit provenance and `[UNVERIFIED]` markers for gaps. The reader (Alex) can use this as the EVIDENCE BASE behind `how-to-rotate.md`.

## Target path

`/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_05_11_rotating_expired_argocd_secrets/draft-rotation-secrets.md`

## Required sections

1. **Header + scope** — purpose, what the doc is, what it is NOT (it is NOT a runbook)
2. **The 4 PATs (verbatim from intake)** — table + Slack message URL citation
3. **Cross-source convergence matrix** — for each load-bearing claim: vault / Slack / wiki / IaC / probe result / FACT-INFER-UNVERIFIED label
4. **Vault citations** — list of vault notes with their role
5. **Slack citations** — verbatim short quotes (Fabrizio, Roel) with permalinks
6. **Wiki citations** — wiki pages + URLs
7. **IaC citations** — file:line citations
8. **Source coverage matrix** — per claim, which sources corroborate
9. **The 4 PATs — current understanding** — per PAT: identity, cluster, KV (if any), sync mechanism (if known), owner, rotation status
10. **Adjacent classes** — F4 / ESP / TF SP (referenced, not detailed)
11. **Open questions to Fabrizio** — full list, grouped, NUMBERED for easy reference; each Q states: question + why it's load-bearing + probe-or-asker-action

## Hard requirements

| Falsifier | Test |
|---|---|
| Every load-bearing claim has either source citation OR `[UNVERIFIED[<class>: <reason>]]` | grep for unflagged factual sentences; sample-review 10 random claims |
| Slack message permalinks are present and verbatim | grep for `eneco-online.slack.com/archives/` URLs |
| Vault note links use `[[note-name]]` form | grep |
| The Q list is grouped (A/B/C/D/E from P2 discovery-map) and >= 10 questions | count |
| Adjacent classes section names F4 (AAD SP), ESP cert, TF SP — and explicitly says OUT OF SCOPE for this task | grep |

## Non-requirements

- NOT executable (no commands)
- NOT a procedure
- NOT a proposal
