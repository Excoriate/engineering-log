---
task_id: 2026-06-02-004
agent: claude-opus-4-8
status: complete
summary: "Receipt classification for sherlock + socrates adversarial reviews of the telemetryfunctiontestsfn 404 RCA. Each finding RESOLVE/REBUT/DEFER with the concrete change made."
---

# Adversarial Receipts

Reviewers (typed, non-overlapping win conditions): `sherlock-holmes` (causal/technical),
`socrates-contrarian` (assumptions/goal-fidelity). Raw sidecars: `sherlock-receipt.md`, `socrates-receipt.md`.

## Verdict roll-up

- **Core root cause: HOLDS** — independently re-confirmed by sherlock via the **nginx access log** (failing
  request routed to upstream `10.0.1.167:8080` = telemetryfunctiontestsfn pod, which returned the 404). This is a
  5th independent confirmation on top of edge-404/control/port-forward/helm-decode.
- Net effect of review: the diagnosis is unchanged; **two claims were over-scoped or weakly-argued and are now
  corrected**, and the deliverable now gives the reporter an immediate unblock.

## Findings

| # | Reviewer | Finding | Sev | Disposition | Change made |
|---|----------|---------|-----|-------------|-------------|
| S1 | sherlock | Backend serves ONLY `/healthz`; `/api/*`=404, `/admin/*`=401 → rewrite fixes healthz, not function invocation; "proven by composition" over-scoped | BLOCKING | **RESOLVE** | rca.md L8/L4 + fix.md scoped to `/healthz`; added explanation that these are non-HTTP (timer/Kafka-triggered) QA test functions per ADR AL006, so `/healthz` reachability IS the goal; removed the `/api/<fn>` optimism |
| S2 | sherlock | "empty body + no Server header ⇒ backend" reasoning unsound (Server header absent even on 200) | HIGH | **RESOLVE** | evidence-ledger.md + rca.md L4: origin now proven by nginx access log + port-forward; header-based inference removed |
| S3 | sherlock | bare-prefix 301 redirects to `http://` on a TLS edge (latent) | MED | **DEFER** | documented as a secondary latent gap (L10/known-issues); not part of this incident; revisit when hardening the legacy ingress |
| S4 | sherlock | post-fix 200 never executed = INFER | — | **RESOLVE** | post-fix 200 explicitly labelled A2 (inference by composition for `/healthz`), not A1 |
| O1 | socrates | No immediate unblock for the reporter | HIGH | **RESOLVE** | added "Immediate workaround (today)" = port-forward to reach `/healthz` now; fix.md + rca.md L8 |
| O2 | socrates | Optimizes a literal URL; didn't ask what he's doing | HIGH | **RESOLVE** | reframed around the real goal (verify the test-function host is reachable); S1 resolution makes this precise |
| O3 | socrates | "agg.dev abandoned" reconciliation too soft | HIGH | **RESOLVE** | rca.md L6: state plainly agg.dev is actively maintained (live chart 0.1.27 + Slack A1 refute "abandoned"); Option A primary, Option B strategic-only |
| O4 | socrates | "skip whitelist" over-generalized | MED | **RESOLVE** | added public-vs-internal caveat to L12 + context.md |
| O5 | socrates | UAC: certs item silently ignored; feynman not a named artifact | — | **RESOLVE** | certs: explicit note added (no client cert needed; public endpoint; certs belong to sibling kafka-certs task). Feynman: `feynman-explainer.md` exists (was omitted from socrates' read-set); `how-to-feynman` skill invoked to validate/upgrade it |

## REBUT (none)

No finding was rebutted without action; the core technical claim was independently strengthened, not weakened.

## Residual / honest gaps

- Post-fix `/healthz`=200 is **A2 inference** (rewrite ∘ backend-200), not executed — the fix is delivered as a PR,
  not applied (GitOps-managed surface; no cluster mutation performed).
- Whether `agg.dev` is *officially* deprecated vs `agg.dev-mc` is an ownership/wiki question — **A3[blocked]**.
- OCI chart `helm-agg` contents not pulled — **A3[blocked]** (does not affect the legacy-AKS fix).
