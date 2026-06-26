---
title: "Synthesis — free thor FBE (act 2 of the 2026-06-22-008 saga)"
task_id: 2026-06-26-002
agent: claude-opus-4-8
status: draft
summary: "Hein cannot delete the thor FBE: build 1693625 fails owner-validation (createdby=Tiago, not Hein). Live probes show the KV vpp-fbe-thor-vuo still exists (Hein's 'no resources' is wrong) and infra state is frozen at the 06-18 partial teardown. Auto-cleanup never clears the row because it fires the same non-idempotent delete pipeline that dies before the release step."
timestamp: 2026-06-26T00:00:00Z
---

# Synthesis — free thor FBE (act 2 of the 2026-06-22-008 saga)

## Reporter & ask
- Reporter: **Hein.Leslie** (NOT Tiago, the original owner who is on leave).
- Ask 1: "Can I just remove the entry in the table?"
- Ask 2: "Why didn't the auto-cleanup of FBEs remove the entry from the table?"
- New build: 1693625. Fails on table query `env eq 'thor' and active eq 'used' and createdby eq 'Hein.Leslie@eneco.com'`.

## Prior incident (same slot)
`log/.../2026_06_22_004_tiago_thor_fbe_failed_deletion/` (task 2026-06-22-008), triple-adversarially reviewed:
- Run 1 (1683298): DestroyInfra → cert-captured-secret `403 SecretManagedByKeyVault`.
- Run 2 (1683370): DestroyAppConfiguration → `az appconfig feature list -n ""` (non-idempotent).
- Left ~90% torn down: KV `vpp-fbe-thor-vuo` + smart-detector alert remain; slot still `used`/createdby=Tiago because the final "Release environment" table step was never reached.

## LIVE verification this session (2026-06-26, Sandbox 7b1ba02e)
- P1 `az resource list -g rg-vpp-app-sb-401 [?contains(name,'thor')]` → **only** `vpp-fbe-thor-vuo` (KV) + `Failure Anomalies - vpp-insights-fbe-thor` (smart-detector). [A1]
- P2 `az keyvault show vpp-fbe-thor-vuo` → **EXISTS** in rg-vpp-app-sb-401; not soft-deleted. [A1]
- P4 state blobs: `terraform.thor`=313885 B (FULL, mtime 2026-06-18T07:36 = run-1 403); `thor.appconfig.tfstate`=184 B (empty, 07:12); `tfstate.thor`=13739 B (2024 legacy, unrelated). [A1]
- P5 `az keyvault certificate list` = empty; `secret list [?managed]` = empty → **403 class still dead**. [A1]
- P3 table row: **BLOCKED** — I lack Storage Table Data Reader on `featurebranchdeployment`. Row state INFER. [A3-blocked]

## Key contradiction
Hein says "no -thor resources in Azure." **FALSE** — the Key Vault `vpp-fbe-thor-vuo` is still live (verified P1/P2). Teardown has NOT progressed since 06-18; state is frozen in the same partial state the 06-22 RCA captured. So "just remove the table entry" frees the *slot bookkeeping* but **orphans the KV + leaves a stale 313 KB infra state**.

## Answers
### Q1 — Can I just remove the table entry?
- Removing the row frees the slot, BUT leaves the KV `vpp-fbe-thor-vuo` orphaned + `terraform.thor` (313 KB) stale → next `thor` create inits against dead state.
- If done manually, it MUST be an **UPDATE** (`active=unused`, `createdby=''`) not a row DELETE — the table is shared slot-pool state; the release pipeline step does `az storage entity merge/replace`, never a delete.
- Complete unblock = release row **+** delete/purge KV **+** clean `terraform.thor` blob (break-glass), OR fix the pipeline and re-run.

### Q2 — Why didn't auto-cleanup remove the entry?
- Auto-evict = Logic App `vpp-fbe-autodelete-trigger` (weekdays 14:30 W.Europe, 4-day-stale) → fires the SAME "Feature Branch Environment - Delete" pipeline with `bypassEnvironmentOwnerValidation=true`.
- That pipeline is **non-idempotent** (06-22 mechanism 2): on a partial teardown it dies at DestroyAppConfiguration (`feature list -n ""`) BEFORE the final "Release environment in the Storage table" step. So every auto run fails mid-pipeline and never clears the row.
- The release is the LAST step of the LAST stage (DestroyInfra `:319-358`), gated behind a stage that can't pass on a partial teardown → neither manual nor auto delete can clear the row until the idempotency bug is fixed.
- Hein's manual run (1693625) fails even EARLIER — Preparation owner-validation — because createdby=Tiago≠Hein. Fix that one layer with `bypassEnvironmentOwnerValidation=true`.

## Recommendation
Two routes; both finish the job (slot + KV + state), unlike a bare table edit:
- **A (durable):** merge the 06-22 idempotency guard PR → re-run delete pipeline with `bypassEnvironmentOwnerValidation=true`. Fixes auto-cleanup for ALL future slots too.
- **B (break-glass, fastest):** pre-flight read-only checks → `az keyvault delete`+`purge vpp-fbe-thor-vuo` → release row (`entity merge active=unused createdby=''`, needs Storage Table Data Contributor — I LACK it) → delete `terraform.thor` blob → delete orphan smart-detector.

## One-way-door / safety
- KV delete+purge = irreversible (purge protection OFF). HALT for explicit authorization.
- Table edit = shared slot-pool state; UPDATE not DELETE; I lack write perms → whoever runs needs Storage Table Data Contributor.
- This is an R1 (advise) deliverable, not R2 (execute): I do not hold table-write and the destructive steps need Hein/owner authorization.
