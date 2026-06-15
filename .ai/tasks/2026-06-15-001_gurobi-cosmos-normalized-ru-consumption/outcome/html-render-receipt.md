---
task_id: 2026-06-15-001
agent: frontend-magician
status: complete
summary: >-
  Rendered the two outcome markdown sources (rca.md, how-to-feynman.md) into two self-contained
  dark-mode HTML5 documents with embedded CSS, sticky/collapsible auto-built TOC, theme toggle
  (localStorage, default dark), styled tables, code blocks, blockquote callouts, evidence-label
  badges (A1=green, A2=amber, A3/UNVERIFIED/blocked=red), severity styling, Mermaid via CDN with
  offline try/catch fallback, and a print stylesheet. Faithful render — source markdown embedded
  verbatim and parsed client-side; no claims, numbers, or evidence labels altered. Two parser
  defects were found and fixed during runtime verification (see Self-check).
timestamp: 2026-06-15T17:17:37Z
---

# HTML render receipt

## Deliverables

| File | Absolute path | Bytes |
|------|---------------|-------|
| RCA | `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/.ai/tasks/2026-06-15-001_gurobi-cosmos-normalized-ru-consumption/outcome/rca.html` | 48176 |
| How-to (Feynman) | `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/.ai/tasks/2026-06-15-001_gurobi-cosmos-normalized-ru-consumption/outcome/how-to-feynman.html` | 33786 |

## Design contract compliance

- Single self-contained `.html` each; all CSS in a `<style>` block; no external CSS/JS except Mermaid 11 from `cdn.jsdelivr.net`.
- Mermaid wrapped in try/catch; on CDN block or render error the raw diagram source is shown in a `<pre>` fallback.
- Dark theme default (`#0d1117` bg, `#e6edf3` text, `#58a6ff` accent); fixed top-right Dark/Light toggle via `<html>` class + `localStorage` (key `rca-theme`).
- Reading column max-width 860px, line-height 1.6, system sans body, monospace code.
- Sticky left-sidebar TOC auto-built from H2/H3 with smooth-scroll + scrollspy; collapses to top on `<900px` (single column, mobile menu toggle).
- GFM rendered: bordered zebra tables with sticky header, fenced ```mermaid via Mermaid.js, other fenced code in scrollable `<pre><code>`, blockquotes as accent callouts.
- Evidence labels as inline badges: `A1`/`A1 FACT` green, `A2`/`A2 INFER` amber, `A3`/`UNVERIFIED`/`blocked` red; severity words (HIGH/MEDIUM/MINOR/LOW) subtly colored. Surrounding text unchanged; `429`/`16500`/`20`/`High` (mixed-case) deliberately left plain.
- Header block per doc: title + status pill + timestamp + task_id from frontmatter. No invented facts.
- Print stylesheet: light background, TOC expanded, page-break-avoid on blocks.

## Self-check — every source H2 present in each HTML

Source markdown is embedded verbatim in a `<script type="text/markdown">` block and verified byte-identical to the source file; it is rendered client-side by an embedded deterministic parser. Verification exercised the actual shipped parser code (not just the embedded text).

### rca.html — 14 / 14 H2 sections present

Context Ledger; L1 — Business — Why the Gurobi platform exists; L2 — Repo system; L3 — Runtime architecture; L4 — Application code flow (the burst path); L5 — IaC / state / Azure — the three truths; L6 — The pipeline and how it actually runs; L7 — Timeline; L8 — Fix; L9 — Verification; L10 — Lessons; L11 — End-to-end command playbook (reproduce from cold); L12 — One-page on-call playbook (5-minute triage); Evidence index.

Also rendered: 5 tables (= 5 source table separators), 1 Mermaid diagram, 2 fenced code blocks; all container tags balanced.

### how-to-feynman.html — 9 / 9 H2 sections present

1. First principles; 2. What this system is; 3. The trap — I was wrong twice; 4. The investigation, step by step; 5. The "aha" moments; 6. The mechanism, in one picture; 7. Replicate it yourself — the decision tree; 8. Meta-lessons; 9. Self-test.

Also rendered: 1 table, 0 Mermaid (the two ```text blocks render as styled `<pre>`), 2 fenced code blocks; all container tags balanced.

### Defects found and fixed during runtime verification

1. **Heading branch infinite loop** — the parser's `# heading` case reached `continue` without advancing the line index `i`, causing a hard infinite loop (Node OOM; would freeze any browser on the first H1). Fixed by adding `i++` to the heading branch. Re-verified: parser terminates and emits every H2 as `<h2 id=...>`.
2. **Nested evidence badges** — the multi-rule badge replacement re-matched `A1` inside an already-emitted `A1 FACT` badge, producing badge-in-badge markup (worst case triple-nested for `A3 UNVERIFIED[blocked]`). Fixed by switching to a single-pass alternation regex (longest alternatives first) so each position is consumed once. Re-verified: 0 nested-badge defects; `429`/`16500`/mixed-case `High`/lowercase `minor` correctly remain plain text.

Both fixes confirmed present in both shipped HTML files. Verified offline (file://-compatible: only Mermaid is external and degrades to a `<pre>` source view if blocked).
