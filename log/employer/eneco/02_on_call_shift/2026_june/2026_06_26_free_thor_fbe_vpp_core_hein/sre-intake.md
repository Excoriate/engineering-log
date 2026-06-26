# SRE Intake — free the `thor` FBE (slot stuck `used`; two pipeline walls)

> **Origin:** raw on-call ask (`intake.md`). **Surface:** gitops-argocd → FBE lifecycle (delete pipeline `2629` + slot-tracking table).
> **This is act 2 of [2026-06-22-008](../2026_06_22_004_tiago_thor_fbe_failed_deletion/rca.md)** — same `thor` slot, same partial teardown. This intake adds *live, log-verified* evidence and the two answers Hein asked for.
> **Confidence:** ~95%. Build logs + live Azure state directly read this session; only the table-row value is inferred (read perm blocked).

---

## 1. Identity ledger (resolved)

| Thing | Value | How resolved |
|---|---|---|
| Slot | `thor` (FBE) | intake + prior RCA |
| Reporter | **Hein.Leslie@eneco.com** | `intake.md`; build `requestedFor` |
| Original owner | **Tiago** (on leave) | `intake.md`; prior RCA |
| Subscription | Sandbox `7b1ba02e-bac6-4c45-83a0-7f0d3104922e` | A1 `az account show` |
| Resource group | `rg-vpp-app-sb-401` | A1 |
| Per-FBE Key Vault | `vpp-fbe-thor-vuo` — **STILL EXISTS** | A1 `az keyvault show` |
| Slot-tracking table | `featurebranchenvdetails` (acct `featurebranchdeployment`) | prior RCA |
| Delete pipeline | **2629** "Feature Branch Environment - Delete" | A1 `az pipelines build definition` |
| New failed build | **1693625** (manual, Hein) | A1 |
| Auto-evict | Logic App `vpp-fbe-autodelete-trigger` — **Enabled**, runs daily ~12:30 UTC | A1 `az resource show` + run history |

## 2. Live state — verified this session (2026-06-26)

| Probe | Result | Label |
|---|---|---|
| `az resource list -g rg-vpp-app-sb-401 [?contains(name,'thor')]` | **only** KV `vpp-fbe-thor-vuo` + smart-detector `Failure Anomalies - vpp-insights-fbe-thor` | A1 |
| `az keyvault show vpp-fbe-thor-vuo` | **EXISTS**, not soft-deleted | A1 |
| `certificate list` / `secret list [?managed]` | both empty → 403 `SecretManagedByKeyVault` class dead | A1 |
| `terraform.thor` state blob | **313 KB, FULL**, mtime 2026-06-18T07:36 | A1 |
| `thor.appconfig.tfstate` | 184 B, empty | A1 |
| table row `env eq 'thor'` | read BLOCKED (no Storage Table Data Reader); inferred `active=used`, `createdby=Tiago` | A3 |

**⚠️ Hein's "no -thor resources in Azure" is wrong** — the Key Vault `vpp-fbe-thor-vuo` is still live. Teardown is frozen at the 06-18 partial state.

## 3. Mechanism — the two walls (log-verified), and why the slot stays `used`

`thor` has had **4+ failed delete runs over a week** (06-19 → 06-26), dying at one of two stages — the slot-release step is downstream of both, so it is never reached:

| Build | Who | Failing stage / task | Literal cause | Label |
|---|---|---|---|---|
| 1693625, 1692465 | Hein | **Preparation → DetermineEnvironment** | `bypassEnvironmentOwnerValidation: [false]` → query `env='thor' AND active='used' AND createdby='Hein.Leslie@eneco.com'` → **"No rows found"** → exit 1 (slot is Tiago's, not Hein's) | A1 (read log 6) |
| 1692721, 1690999 | Roel | **DestroyAppConfiguration → Get Feature Flags** | `az appconfig feature list -n ""` (App Config store already destroyed in Tiago's run 1) → exit 1 — the **06-22 non-idempotency bug, still unmerged** | A1 (read timeline) |

- **Wall 1 (owner):** `DetermineEnvironment` scopes the slot lookup to the runner's email when `bypassEnvironmentOwnerValidation=false`. A non-owner (Hein) finds no row → fail. Cleared by `bypassEnvironmentOwnerValidation=true`. **A1.**
- **Wall 2 (idempotency):** even past wall 1, the pipeline dies at `DestroyAppConfiguration` on the empty App-Config name. The 06-22 guard was never merged (Roel's 06-19/06-25 runs prove it live). **A1.**
- **Slot release** (sets the row `unused`) is the last step of `DestroyInfra`, downstream of both walls → never reached → row stays `used`/Tiago. **A2.**

## 4. The two answers (for the Slack reply)

- **"Can I just remove the table row?"** YES — updating the row to `active=unused`/empty `createdby` frees the slot (that *is* the pipeline's release step), independent of the KV. But (a) **update**, don't delete the row (shared slot-pool table; pipeline merges); (b) the KV `vpp-fbe-thor-vuo` is still live + state is stale → tidy those too or the next `thor` create breaks.
- **"Why didn't auto-cleanup remove it?"** The Logic App is enabled and runs daily (verified) — it's not broken. But freeing the slot needs the delete pipeline to reach its release step, and for `thor` that pipeline can't (the two walls above). So neither manual retries nor the auto-evict ever clear the row. *(Scope note: I verified the manual runs + the Logic App's enabled/daily state; I did not trace a specific auto-queued thor build — all observed thor builds were manual.)*

## 5. Recommended route (bypass ALONE is insufficient — it only clears wall 1)

- **A — durable:** merge the 06-22 idempotency guard (skip `DestroyAppConfiguration` when the store is gone) → re-run `2629` for `thor` with **`bypassEnvironmentOwnerValidation=true`**. Clears both walls, finishes the KV destroy + releases the slot, and restores auto-cleanup for every future slot.
- **B — break-glass (fastest certain):** pre-flight (§6) → `az keyvault delete`+`purge vpp-fbe-thor-vuo` → release row (`az storage entity merge … active=unused createdby=''`, needs Storage Table Data Contributor) → delete `terraform.thor` blob → delete orphan smart-detector. Full commands: 06-22 [quick-fix.md](../2026_06_22_004_tiago_thor_fbe_failed_deletion/quick-fix.md).

**Success signal (witness, not a green build):** `featurebranchenvdetails` row for `env='thor'` reads `active='unused'` + empty `createdby`, AND `az keyvault show vpp-fbe-thor-vuo` → NotFound.

## 6. Read-only pre-flight (run immediately before any unblock)

```bash
az account set --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e   # Sandbox — never trust default
az keyvault certificate list --vault-name vpp-fbe-thor-vuo -o tsv                       # expect empty (403 class dead)
az resource list -g rg-vpp-app-sb-401 --query "[?contains(name,'thor')].{n:name,t:type}" -o table   # KV + smart-detector
az storage entity query --account-name featurebranchdeployment --auth-mode login \
  --table-name featurebranchenvdetails --filter "env eq 'thor'" --query "items[0].{active:active,createdby:createdby}"
```

## 7. One-way-door gates (HALT for authorization)

- **KV `vpp-fbe-thor-vuo` delete + purge** = irreversible (purge protection OFF). Safe — per-FBE vault is a copy *sink* from shared `vpp-aks-d`; nothing reads from it (06-22 L3). Never touch the shared `vpp-aks-d`.
- **Table row** = shared slot-pool → **UPDATE** (`unused`/empty), never DELETE; needs Storage Table Data Contributor (agent lacks it).
- **`terraform.thor` blob delete** = needed so the next `thor` create starts clean.
