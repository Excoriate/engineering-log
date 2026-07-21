---
title: "Toil removal — stop VPP Terraform CI from installing TFLint as 'latest'"
type: sre-toil-removal-proposal
incident_id: 2026_07_18_003_tflint_attestation_pgp_workaround
task_id: 2026-07-19-001
status: complete
timestamp: 2026-07-19T17:28:00Z
---

# SRE Toil Removal Proposal

The incident was not bad Terraform — it was an **unpinned toolchain** silently adopting an upstream regression. Before proposing automation, the first question is whether the *work* (chasing recurring `latest`-driven breakage) should exist at all. It should not. The systemic move is to make "which tool version runs" a **reviewed, deliberate decision** instead of a runtime lottery.

## Toil Removal Knowledge Contract

After reading this, a platform lead can name the recurring toil this incident revealed, choose between the org-wide and per-repo fixes with their tradeoffs, and identify the one thing that should *not* be automated (the `signature = "pgp"` rollout).

## RCA Evidence Base

| Toil | Evidence (RCA row) | Why it recurs |
|---|---|---|
| Firefighting CI that broke with no repo change | Build 1721100 failed on `tflint --init`; installed TFLint was resolved from `releases/latest` (RCA E2/E11) | Every consumer inherits every upstream TFLint release at runtime |
| Hand-applying `signature = "pgp"` across repos under pressure | Same one-line commit landed in `Eneco.Infrastructure` (PR 188066) and `Dispatching.Infrastructure` (PR 188112) within a day (RCA E9/E10) | No shared, pinned default; each repo fends for itself |
| Re-triaging "is this our Terraform?" for a tooling panic | Panic stack in `VerifyAttestations`, not a lint rule (RCA E2) | No recognition signal that this class is upstream |

## Options Considered

**Option 1 — Remove `'latest'` as the CCoE default (owner: CCoE). Highest leverage.**
- *Change:* in `CCoE/azure-devops-templates` `steps/test/tflint/install.yaml`, change `tflintVersion` default from `'latest'` to a pinned version (e.g. `v0.64.0`), bumped on a schedule or via Renovate.
- *Removes:* the runtime lottery for **all** consumers, not just VPP (RCA E11).
- *New failure mode:* a stale pin lags security/rule fixes → mitigate with a scheduled bump PR.
- *Smallest reversible step:* one-line default change + a Renovate rule; revertible by restoring `'latest'`.

**Option 2 — Pin per-repo now (owner: VPP/Platform). Immediate, VPP-owned.**
- *Change:* pass `tflintVersion: "v0.64.0"` in each VPP Terraform pipeline (see `fix.md`).
- *Removes:* VPP's exposure without waiting on CCoE.
- *New failure mode:* per-repo pins drift → track them until Option 1 lands, then delete them.

**Option 3 — Shift recognition left with a build annotation (owner: Platform). Cheap detector.**
- *Change:* wrap the `tflint --init` step so a panic containing `VerifyAttestations`/`sigstore` emits a build warning: "TFLint plugin verification crashed — likely upstream (see incident 2026_07_18_003), not your Terraform."
- *Removes:* the repeated "is it us?" triage (RCA L10 lesson 1).
- *New failure mode:* a misfiring matcher annotates unrelated failures → scope the grep tightly to the two frames.

## Recommendation

Do **Option 2 now** (VPP-owned, unblocks this repo and its siblings immediately) and **drive Option 1** with CCoE as the durable org-wide fix; add **Option 3** as a cheap detector while the pins propagate. Once Option 1 lands, delete the per-repo pins from Option 2 so there is a single source of truth for the TFLint version.

## Systemic Rationale

Option 1 converts an unbounded, org-wide, recurring firefight into a single scheduled bump PR. The net effect is to **remove the judgment "which TFLint version am I getting?" from the CI hot path** and make it a reviewed change with a diff — the definition of turning toil into engineering.

## Non-Goals

- **Do NOT automate the `signature = "pgp"` rollout.** Once tool versions are pinned, the per-repo workaround should be **removed**, not scripted across repos. Automating its rollout would preserve a deprecated verification path (legacy PGP key on 0.28.0, RCA E5/E7) at machine speed — the opposite of the goal.
- Not in scope: changing the pre-commit hook framework, or the Terraform version pinning (already pinned at `1.14.3`).
