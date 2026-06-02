---
task_id: 2026-06-02-001
agent: coordinator
status: complete
summary: Receipt classification for the 3 adversarial reviews (sherlock, sre-maniac, goal-fidelity). All findings RESOLVE; load-bearing claims source-verified first-hand before acceptance.
timestamp: 2026-06-02T12:40:00Z
---

# Adversarial receipts — classification (RESOLVE / REBUT / DEFER)

All three reviewers wrote receipts to `adversarial/`; each `test -s` + read before synthesis. Sherlock's central correction (Finding 1: `common` is OCI-published + GitOps-consumed) was **source-verified first-hand** by the coordinator (`helm-chart-push.yaml` glob push-loop; `Eneco.Vpp.Aggregation.GitOps` `common/dev` values=`DevMC` + OCI dependency) before importing as FACT — per the source-verified≠claim-safe rule.

## Sherlock (root-cause rigor) — verdict SOUND-WITH-CAVEATS

| # | Finding | Sev | Receipt | Action |
|---|---------|-----|---------|--------|
| S1 | "`common` is dead code / created by NO env CD" REFUTED — OCI-published + GitOps-consumed in MC (`container.env=DevMC`) | HIGH | RESOLVE | Rewrote TL;DR/L2/L5/L6/L10; Sandbox cause reframed as **enrollment gap** (Sandbox not in GitOps app-of-apps; legacy in-repo pipeline omits `common`). False-negative search retracted. |
| S2 | `managedFields:[]` is NOT a manual-creation discriminator (CSI secret also empty); **ownerReferences** is | MED | RESOLVE | Replaced the discriminator in rca L5 TRUTH3 + challenge-defense + evidence ledger #4 + live-sandbox-probe.md. Conclusion (manual) survives on owner-absence + no helm/csi labels + reporter statement. |
| S3 | 4 A1 labels are actually A2/refuted (common-search, managedFields, ArgoCD-overread, ESO-not-configured) | MED | RESOLVE | Corrected all 4 labels; ESO restated as "installed but no ExternalSecret targets keys". |
| S4 | Timeline: no evidence a Sandbox `keys` ever pre-existed; never-created vs created-then-lost undistinguishable | LOW | RESOLVE | Added explicit caveat to L7 + ledger #9; "expired" framed as reporter's account. |
| S5 | Strongest alt: Sandbox = enrollment gap, and **deleting `common/templates/secret.yaml` risks MC regression**; ESO is a viable provider never considered | HIGH | RESOLVE | fix.md: removed unconditional delete; gated behind MC migration; added ESO route (sidesteps CSI mount-coupling). Re-scoped the 3 rejections. |

## SRE-maniac (durable-fix failure-path) — verdict SAFE-WITH-CHANGES

| # | Finding | Sev | Receipt | Action |
|---|---------|-----|---------|--------|
| F1 | CSI secretObjects only project while a pod mounts the SPC CSI volume; the 10 `*fn` mount `secret:keys` directly (0 mount SPC) → projection anchored to `siteregistry` by accident → orphan risk | BLOCKING | RESOLVE | fix.md Layer 1 rewritten: if CSI is used, `*fn` MUST mount the SPC CSI volume directly (each consumer its own anchor); ELSE prefer ESO (no mount-coupling). Added L10 lesson. |
| F2 | pfx assembly under-specified; (b) "PEM keystore in recent versions" unverified; (a) re-introduces rotation class | HIGH | RESOLVE | Gated (b) on a named client-version probe + runtime mTLS smoke test; struck the unverified parenthetical; ranked options with costs. |
| F3 | L9 "delete manual keys, do nothing else, confirm recovery" is contradictory + outage trigger | HIGH | RESOLVE | Rewrote L9 into a gated sequence; pass/fail = driver/controller-owned label on `keys`, not "pods recover"; never delete manual secret before projection confirmed; rollback kept. |
| F4 | MC blast radius: deleting shared template is one-way; no staged-rollout guard; MC KV contents unverified | MED | RESOLVE | Split delete from Sandbox change; MC pre-flight checklist; keep template until MC migrated (compounds S5). |
| F5 | Class fix won't close alarm gap: kafka-* KV secrets `expires:null`; manual `--expires` is same class defect; no rotation trigger | MED | RESOLVE | Re-ranked: KV **certificate object** (intrinsic expiry, existing alarm) primary; named rotation **trigger** required; noted live `expires:null`. |

## Goal-fidelity (ask↔deliverable) — verdict NOT-YET-SATISFIED → resolved

| # | Finding | Sev | Receipt | Action |
|---|---------|-----|---------|--------|
| D1 | Nuno's literal "should these be via a secret provider, right?" never answered as a findable yes/no | BLOCKING | RESOLVE | Added titled subsection (rca L8.0 + fix top) quoting the question, answering **yes**, ESO-vs-CSI, Sandbox-scoped, MC-may-differ. |
| D2 | Feynman explainer not self-contained for replication (no Step 0 connect/auth; connect skill unnamed) | HIGH | RESOLVE | Added "Step 0 — get read-only Sandbox access" to explainer naming `eneco-tools-connect-mc-environments`. |
| D3 | VPP-Core wording softening (speculates Johnson's intent) | LOW | RESOLVE | Tightened to observable-only (live cert CN = eet-vpp-dt). |
| D4 | "PEM keystore in recent versions" unprobed at decision point; timeline node reads certain | MED | RESOLVE | A3-labelled at point of use (overlaps F2); timeline node marked inferred. |
| D5 | J3 answer not explicitly Sandbox-bounded | MED | RESOLVE | Folded into D1 subsection. |
| D6 | connect skill not named in consumer docs | MED | RESOLVE | Named in explainer Step 0 + context probe table. |

## Gate check

- Receipts: 16 findings, **16 RESOLVE, 0 REBUT, 0 DEFER** → no systematic-defer, no rebut-without-evidence.
- No BLOCKING/HIGH left open. Two BLOCKING (S-driven MC-regression + SRE CSI-coupling + goal D1) all resolved by behavioral changes to fix.md/rca.md, not notes.
- Reviewer independence: 3 distinct typed frames (investigation / operator / goal), non-overlapping win conditions, separate from the producer (coordinator). Receipts on disk.
