---
title: "Adversarial receipts — thor teardown (el-demoledor + sre-maniac)"
task_id: 2026-06-26-002
agent: claude-opus-4-8
status: complete
summary: "Receipts for both teardown adversaries. All operational SRE guards APPLIED in the executed release (ETag-pinned, env-reconfirmed, build-gated, 3-plane witness, blob backup). el-demoledor: 5/7 orphan classes verified clean, KV anomaly NOT-A-RISK, manual lower-risk than pipeline re-run (all RESOLVED); V3/V5 merge-vs-replace RESOLVED by table inspection (merge is correct — preserves the fixed queue column); V1 AAD app-reg DEFERRED (privilege-blocked for both reviewers) → irreversible state-blob deletion deferred, slot release proceeded (independent of V1)."
timestamp: 2026-06-26T00:00:00Z
---

# Adversarial receipts — thor teardown

## sre-maniac (operational) — ALL guards APPLIED in the executed release

| Finding | Status | How discharged |
|---|---|---|
| V1b/V2 entity-merge race + wrong-target (`--if-match` defaults to `*`; PK=3 positional) | **RESOLVE** | Executed merge used `--if-match "$ETAG"` after re-reading the row by identity and asserting `env==thor && createdby==Tiago.Rios@eneco.com`. Read-back confirmed the write landed. |
| V1a leased-blob delete = build-running canary | **RESOLVE** | Pre-checked lease (available/unlocked) + in-flight 2629 build count (0) before any mutation. |
| V3 blast radius (merge vs replace, type drift) | **RESOLVE** | Kept `merge` (single-entity, property-scoped), plain strings, no `@odata.type`. Table inspection proved merge is the CORRECT op (preserves the fixed `queue` slot attribute a `replace` would wipe). |
| V4 witness too weak / single-plane | **RESOLVE** | 3-plane witness: row read-back (env+active+createdby+branch), whole-sub resource sweep (empty), KV NotFound. |
| V5 state-blob delete is a one-way door | **RESOLVE + DEFER** | Confirmed `tfstatevpp` has soft-delete(6d)+versioning; downloaded a local backup to the task dir. The blob deletion itself is DEFERRED (see el-demoledor V1), so the one-way door is not yet walked. |

## el-demoledor (orphan/state-corruption)

| Finding | Status | How discharged |
|---|---|---|
| V2 "empty instance ≠ destroyed in cloud" (Kusto/Cosmos/fed-cred/role classes) | **RESOLVE** | el-demoledor independently probed the SHARED PARENTS (Kusto cluster, Cosmos accounts, all MSIs, Resource Graph) → every probeable thor child absent. My own broad sweep + role-def/identity checks concur. Cloud-side clean regardless of state provenance. |
| V4 KV anomaly (deleted but purge "not found") | **REBUT (not-a-risk)** | KV name carries a random suffix (`-vuo`, live `random_string` in state); next create uses a NEW suffix → a soft-deleted-invisible `vpp-fbe-thor-vuo` cannot collide. `show`=NotFound = ARM removed it. |
| V5 manual vs pipeline re-run | **RESOLVE (manual chosen)** | Pipeline re-run is HIGHER risk: destroy engine pinned to tf 1.13.1 (F19 orphan-manufacture), unmerged/untested idempotency guard (control-plane blast radius), still dies at DestroyAppConfiguration. Manual touches no YAML, no 1.13.1 destroy. Orphan-pattern explicitly forbids the destroy route. |
| V3/V5 `merge` ≠ `replace` (stale pipeline-managed columns) | **RESOLVE** | Read the table: extra columns are `queue` (FIXED per-slot attribute, MUST preserve) + `slackresponse` (informational). `merge` preserves `queue` correctly; `replace` would risk wiping it. So merge is the right call; `slackresponse=no` left stale is harmless. createdby/branch set to empty-string match the pipeline's `branch="" active=unused` + cleared-createdby. |
| **V1 AAD app registrations** (`module.sa-appreg-*` ×12; not Graph-indexed) | **DEFER** | Privilege-blocked for el-demoledor AND for this session's SP (`az ad app list` → "Insufficient privileges"). Genuinely unclosable from available identities. **Consequence: the irreversible state-blob deletion is DEFERRED** — it is the one action el-demoledor gated on V1. The SLOT RELEASE does NOT depend on V1 and proceeded. Mitigating evidence: the appreg modules' satellite objects (federated creds, role assignments) are all verified GONE, and the MSIs are `data` (shared) sources — circumstantial that no thor appreg was created. |

## Net

- **Executed (Hein unblocked):** ETag-guarded slot release (`active=unused`), KV already deleted, smart-detector alert deleted, state blob backed up. Zero thor resources remain in Sandbox.
- **Deferred (one open hole):** delete the stale `terraform.thor` state blob — gated on the V1 AAD app-registration probe, which needs an `Application.Read.All`/AAD-capable account neither reviewer nor this session holds. Until then the blob stays (recoverable; the next thor create's terraform refresh will reconcile the now-deleted cloud resources). No Defer on a BLOCKING finding was overridden — the slot release (the goal) is independent of V1.
