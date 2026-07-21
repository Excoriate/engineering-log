---
task_id: 2026-07-19-003
agent: eneco-sre (coordinator)
status: complete
summary: Adversarial receipt ledger — disposition of every finding from 5 reviewers (3 typed Claude + 2 codex).
timestamp: 2026-07-19T00:00:00Z
---

# Adversarial Receipts Ledger

Rule: every finding classified RESOLVE / REBUT / DEFER with evidence. Reviewers = sre-maniac,
socrates-contrarian, terraform-oraculum (typed Claude-family), + codex-mechanism, codex-fix (cross-family).

## sre-maniac (reliability / fix viability)

| # | Finding | Disposition | Action / evidence |
|---|---------|-------------|-------------------|
| S1 | P1 pipeline effect-check compares `baked == application-secret` only; if CSI/KV lag, both match the OLD store → false green | **RESOLVE** | how-to-fix P1: add an Azure-store existence assertion to the gate; wait for application-secret to reflect a LIVE store before restart |
| S2 | "job may lack cluster credentials" is OVERSTATED — sibling `Infra_tests` stage already auth's AKS via `$(azureSubscription)` | **RESOLVE** | how-to-fix P1: correct the prereq note (creds exist; P1 more viable) |
| S3 | Reloader viability SURVIVES (live proof CSI mutates the Secret object, restarts=0) | REBUT n/a (confirms) | keep P2; reframe argument off "2s freshness" onto "rolls when secret reaches final value" |
| S4 | "Tennet NL" indicator↔App-Config binding is INFER, not code-proven | **RESOLVE** | attribute to filer's empirical correlation (A1 filer); DoD = observe 200 AND indicator |
| S5 | Cascading risk (shared 13-key secret flaps frontend; P1+P2 double-restart) LOW, disclosed | DEFER | already disclosed as LOW; no change |

## socrates-contrarian (goal fidelity / assumptions / fabrication)

| # | Finding | Disposition | Action / evidence |
|---|---------|-------------|-------------------|
| C1 | Goal fidelity SURVIVES, but RCA silently reframes Duncan's "when creating" into "recreate" without the finite-slot-pool bridge | **RESOLVE** | RCA: state the reused planet-name slot pool bridge explicitly |
| C2 | **Over-claim**: "reproduced Duncan's 401 across 5/7 slots" — those slots bake DELETED stores → HTTP 000, not Duncan's resolving-store 401 | **RESOLVE** | RCA Summary/L7/L10/claims: reword to "live proof of the frozen-snapshot drift MECHANISM + recurrence"; 401 is the store-still-resolves variant |
| C3 | **Timing contradiction**: pods started AFTER their current store existed yet baked an older deleted store → falsifies "froze current at birth, store recreated later" | **RESOLVE** | RCA L7: drop the "recreated after pod" A2 temporal claim; keep only A1 (baked store deleted, differs, no restart); note KV secret can lag the store |
| C4 | Fabrication sweep: all identifiers/paths/line-refs verified REAL; only imprecision "5 of 7" (live = 6 FBE frontend slots) | **RESOLVE** | RCA: correct to "5 of 6 FBE frontend slots (jupiter healthy)" |

## terraform-oraculum (IaC correctness)

| # | Finding | Disposition | Action / evidence |
|---|---------|-------------|-------------------|
| T1 | Claims 1-4 (random keeper stable; name ForceNew; module outputs write-key only; read-key switch = value update not ForceNew) all CONFIRMED against pinned v0.1.0 | REBUT n/a (confirms) | no change; strengthens RCA L5 + fix P3 |
| T2 | Module HEAD drifted from v0.1.0 (dropped ignore_changes=[tags], added tags/data_owners, provider pinning) → cutting v0.2.0 from HEAD bundles unrelated changes | **RESOLVE** | how-to-fix P3: cut the new tag MINIMAL off v0.1.0, not HEAD |
| T3 | `local_auth_enabled` unset (defaults true); disabling later kills read AND write HMAC keys, defeating P3 | **RESOLVE** | how-to-fix P3: add the note |
| T4 | "30-day purge lockout" for the App Config store is imprecise (App Config soft-delete 1-7 days, purge protection off by default; 90-day is Key Vault) | **RESOLVE** | RCA L12 + how-to-fix one-way-door list: correct the figure |
| T5 | Provider facets PROVIDER-DOCUMENTED not PLAN-VERIFIED (no `terraform plan` runnable this session) | **RESOLVE** | how-to-fix P3: add "run one `terraform plan` on a throwaway slot before shipping P3" |

## codex-mechanism / codex-fix (cross-family)

| # | Finding | Disposition | Action / evidence |
|---|---------|-------------|-------------------|
| X1 | Reviewers launched in cmux (workspace:10/11), sandbox workspace-write | **BLOCKED** (tool failure) | Both codex procs EXITED without writing their pre-bound receipts (H-OM-4: exit ≠ completion). Cause: codex-cli internal `models_manager` cache error (`missing field supports_reasoning_summaries`) + the fix-reviewer derailed into a terraform-provider setup rabbit hole. NOT retried (H-OM-5). Cross-family layer reported BLOCKED honestly; the 3 typed adversaries fully satisfy the adversarial requirement. Note: the mechanism reviewer's last visible reasoning ("clarifying RCA verdict on fleet drift and error reproduction") was independently converging on socrates' C2 fleet-drift-vs-401 correction — cross-family corroboration, treated as INFER (no receipt landed). |

## Systematic check

- Total findings: 14 substantive. RESOLVE = 11, DEFER = 1, confirm/no-change = 2. Defer ratio well under 50%.
- No BLOCKING/HIGH finding deferred. No prose-only rebut. All RESOLVE items map to a concrete doc edit below.
