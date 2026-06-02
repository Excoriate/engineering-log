---
task_id: 2026-06-02-004
agent: claude-opus-4-8
status: partial
summary: Plan + 6Q self-attack on the proven root cause; deliverable spec for the RCA/fix/feynman package.
---

# Plan — telemetryfunctiontestsfn 404 RCA

## Diagnosis under test (to be attacked, then externally adversarially reviewed in P8)

nginx ingress `telemetryfunctiontestsfn-ingress` mounts the Azure-Functions backend at path prefix
`/telemetryfunctiontestsfn/` with **no `rewrite-target`**; the app serves `/healthz` at root and has no
matching `PathBase`, so the unstripped path 404s. `siteregistry` works only because it is mounted at `/`.

## 6-Question self-attack (each must change a step or be answered with evidence)

- **Q1 (load-bearing assumption): "The app has no PathBase for the prefix."**
  Evidence: port-forward straight to the pod → `/healthz`=200 but `/telemetryfunctiontestsfn/healthz`=404 (A1).
  → Holds. If false, backend would have answered the prefixed path.

- **Q2 (alternative cause): WAF / App Gateway / Front Door blocking the path?**
  Eliminated: AppGw `vpp-agw-d` rules are Basic, `urlPathMaps:[]`, single pool → nginx; WAF returned 404 not 403;
  nginx-direct (Host header) reproduces the 404 (A1). → Not the cause.

- **Q3 (disprove the fix): "Stripping the prefix yields 200."**
  Simulated without mutating: the backend already returns `/healthz`=200. A rewrite mapping
  `/telemetryfunctiontestsfn/healthz`→`/healthz` therefore returns 200 (A1 by composition). Falsifier would be
  backend `/healthz`≠200 — not observed.

- **Q4 (hidden complexity): "Is `vpp-agg` the environment the reporter means, and is it canonical or legacy?"**
  Serving env proven (DNS→AppGw→this cluster→`vpp-agg`). Canonical-vs-legacy: running `adhoc-0.0.1.1457` (497d) vs
  GitOps `3.18.1.dev` + not-in-ArgoCD ⇒ likely legacy. → DELEGATED to lane-a/lane-c. Fix recommendation must
  account for the answer (don't send a PR to a dead env).

- **Q5 (version): rewrite syntax for nginx-ingress v1.14.0.**
  Requires `use-regex:"true"` + path `/telemetryfunctiontestsfn(/|$)(.*)` + `rewrite-target:/$2` (A1 version pinned).

- **Q6 (silent fail): "Does the fix break the `/` siteregistry catch-all or other paths?"**
  A prefix rule with rewrite affects only `/telemetryfunctiontestsfn/*`; `/` stays with siteregistry. Must verify
  rule specificity/ordering and that `pathType` + regex don't shadow `/`.

- **Q7 (goal fidelity): "Is `/telemetryfunctiontestsfn/healthz` even the intended URL?"**
  The reporter asserts it should work. Modern convention is `/api/telemetry` (telemetry-0.4.0). The reporter's URL may
  be a legacy/incorrect expectation. → DELEGATED to lane-c (docs convention). RCA must state the intended access path,
  not just make the literal URL work.

## Context lane ledger

| Lane | Belief-change | Stop rule | Omitted-lane risk |
|------|---------------|-----------|-------------------|
| A GitOps/Helm | Where the fix lands + regression-or-gap + legacy/canonical | chart ingress template found w/ rewrite presence decided | recommend PR to a dead repo/env |
| B Slack history | Prior report/resolution + recurrence | jhonson lobos AVD history scanned | re-solve a known issue; miss recurrence pattern |
| C Docs/intent | Canonical exposure convention + AVD network path + function purpose | ADR/runbook on agg ingress found or blocked | give a fix that violates platform convention |

## Deliverable spec (all in how-to-feynman teaching style — UAC)

1. `outcome/rca.md` — holistic RCA, L1–L12 headings (on-call-incident-workflow rule), Context Ledger first,
   every load-bearing claim A1/A2/A3, Feynman first-principles ladder + Mermaid topology + self-tests.
2. `outcome/fix.md` — exact fix options (ingress rewrite vs app PathBase vs re-sync), GitOps location, verification
   commands (incl. the laptop curl + port-forward repro), rollback, and a note on whether to fix legacy vs use canonical.
3. `outcome/context.md` — Context Ledger + network topology (Mermaid) + AVD probe instructions (whitelist note).
4. `outcome/feynman-explainer.md` — the deep teaching doc: "how ingress path routing works, why prefix-without-rewrite
   404s, how to reason about it yourself," with ASCII request-flow trace and a replication recipe.
5. Duplicate 1–4 into the user log folder for quick study.

## Verification strategy (witness ≠ producer)

- Technical adversarial: `sherlock-holmes` (attack the causal chain / alternative hypotheses).
- Assumption adversarial: `socrates-contrarian` (attack load-bearing assumptions incl. legacy/canonical + goal fidelity).
- Goal-fidelity: deliverable answers the reporter's literal ask AND the correct intended-access path.
- `/anti-slop` gate before status=complete.
- Receipts → `verification/`; each finding RESOLVE/REBUT/DEFER with evidence.
