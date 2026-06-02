---
task_id: 2026-06-02-001
agent: coordinator
status: complete
summary: Plan to author Feynman-style RCA package for the vpp-agg Sandbox keys-secret incident + P8 adversarial strategy.
timestamp: 2026-06-02T09:35:00Z
---

# Plan — Author Feynman-style RCA package

## Deliverables (authored to $T_DIR/outcome/, then duplicated to the user incident folder)

1. `context.md` — zero-context reader ledger (every term defined before use) + system overview.
2. `rca.md` — holistic L1–L12 RCA, Feynman-first (Knowledge Contract → first-principles ladder → mechanism), A1/A2/A3 labels, Mermaid + ASCII visual aids.
3. `fix.md` — stop-gap (already done by Johnson) vs durable fix (wire 4 Kafka cert objects into the CSI SecretProviderClass), each step with WHY + replayable verification.
4. `how-to-feynman-explainer.md` — standalone teach-doc with falsifiable Knowledge Contract, ladder, self-tests, challenge defense, evidence ledger. (UAC requirement; named skill invoked.)

User folder: `log/employer/eneco/02_on_call_shift/2026_june/2026_06_02_vpp_aggregation_layer_sandbox_broken_jhonson/`

## The answer (one line)

The `keys` Secret (Kafka/ESP mTLS certs) is dead-code inline-Helm (committed certs, no Sandbox branch, `common` chart never deployed, CSI SPC excludes it) → it is created in NO environment's CD → Sandbox never had it → Johnson hand-created it. Durable fix: project the (already-present) KV `vpp-agg-sb` Kafka certs into a `keys` secret via the existing CSI SecretProviderClass.

## 6 adversarial questions (attacked before authoring)

- **Q1 (assumption):** Is `keys` truly never created by CD, or did I miss a cross-repo deploy (Flux/app-of-apps/Eneco.Infrastructure)? → R1 found `Helm/common` zero refs; live shows no `common` Helm release + no ArgoCD app for vpp-agg. Residual: a non-ArgoCD external installer outside scanned repos (A3, low). Mitigation: state scope bound in RCA.
- **Q2 (alternative):** Could the secret have existed and been DELETED (not never-created)? → Live provenance (no managedFields, manual create 2026-06-01) + Johnson's own statement + "never deployed by CD" make never-created-in-Sandbox the strongest reading; deletion is unfalsifiable now (events aged out) → present as "missing", not "deleted".
- **Q3 (disprove the fix):** Will wiring certs into CSI actually work? → CSI SPC `secret-provider-agg-kv` already projects 3 secrets from `vpp-agg-sb` and works (live); KV already holds kafka-cacert/clientcert/sslkey. Risk: CSI projects a single combined secret; key-name mapping (`ca-cert.pem` etc.) must match the chart's `keys` data keys + the pfx may need assembling. Flag as design caveat, not a blind "just add it".
- **Q4 (hidden complexity):** The pfx (`ssl-key.pfx`) — KV has `kafka-sslkey` (PEM key) + `kafkasslkeystorepassword`; is there a pfx in KV? → Not seen in KV list. The pfx may need to be generated (openssl pkcs12) from cert+key. Durable fix must address pfx assembly, not assume it exists.
- **Q5 (version/temporal):** "Broken >6 months" vs live cert valid to 2027 + KV refreshed 2026-05-29 — reconcile. → The PREVIOUS cert expired ~6mo ago; a new eet-vpp-dt cert (issued 2025-12-09) was loaded to KV 2026-05-29 and to the K8s secret 2026-06-01. Timeline must distinguish these.
- **Q6 (silent failure / looks-correct-while-wrong):** Pods Running now could mask that the cert identity is wrong/borrowed. → Live client-cert CN = esp-eet-vpp-dt (own identity), valid → identity is correct now. The "VPP Core certs" Slack note is either superseded or loose phrasing — report the discrepancy, do not assume.
- **Q7 (class):** Is this a one-off or the credential-expiry class ([LL-006])? → Class: no rotation owner (docs: "tech lead"), expiry pipeline checks KV cert objects not secrets, no alarm on this secret. Add class linkage + a class-level recommendation.

## P8 verification strategy (externalized, typed, distinct win conditions)

- **sherlock-holmes** — investigation rigor: attack whether the root cause is proven vs a surviving alternative; demand the discriminator for never-created-vs-deleted and for the fix mechanism. (Different win condition: "is the diagnosis falsified by any evidence?")
- **sre-maniac (Operator)** — failure-path: attack the durable fix (CSI pfx assembly, rotation, blast radius of changing prod `vpp-agg` cert path, what breaks on next redeploy). (Win condition: "does the fix create a new failure mode?")
- **goal-fidelity (separate typed adversarial)** — does the package answer Johnson's 4 verbatim questions + satisfy Alex's how-to-feynman UAC (deeply comprehensible + replicable)? Uses the verbatim intake corpus. (Win condition: ask↔deliverable divergence.)
- Each writes a receipt to `$T_DIR/adversarial/<name>.md`, returns path only; coordinator `test -s` + reads before synthesis; receipts graded; findings → RESOLVE/REBUT/DEFER with evidence.

## Verification of the docs themselves

- Every load-bearing claim carries A1 (file:line / cmd output / KV+kubectl probe) or A2/A3.
- Context-ledger zero-reader test.
- Anti-slop pass before status=complete.
- Frontmatter: `.ai/**` uses `timestamp` (not `date`), status ∈ {complete,partial,blocked,pending_review,draft}.
