---
title: "SRE adversarial review — thor FBE slot teardown on shared infra (concurrency / wrong-target / blast-radius)"
task_id: 2026-06-26-002
agent: sre-maniac
status: complete
summary: "Operator-frame attack on the live thor FBE teardown. Five vectors graded. The plan's single largest unguarded hole: az storage entity merge is addressed by the PK/RK embedded in --entity (Azure docs, A1), NOT by the env eq 'thor' query that READ the row — so the skill's 'query by env not PartitionKey' rule does NOT protect the WRITE, and --if-match defaults to * (no optimistic concurrency). On a SHARED table this is a wrong-target + lost-update race. Leased state-blob delete is self-protecting (412 LeaseIdMissing, A1) but that 412 is also the build-running signal you must probe FIRST. State-blob deletes are the only irreversible step and must be guarded with a download-to-disk backup. The ONE mandatory guard: an ETag-pinned, env-reconfirmed merge (show by env→capture etag+PK+RK→merge with --if-match <etag>) gated behind an active-build/lease probe."
timestamp: 2026-06-26T00:00:00Z
---

# SRE Adversarial Review — thor FBE Slot Teardown

Operator frame (sre-maniac). Win condition: find the operational failure mode, race, or wrong-target that makes this go wrong in production. Target is **destructive ops on SHARED state** (the `featurebranchenvdetails` table and the `tfstatevpp/tfstate` container are shared across all FBE slots). That sharing is what turns every "small" mutation into a potential multi-slot incident.

Two load-bearing Azure facts established before grading (both A1, Microsoft Learn):

- **F-LEASE (A1):** `Delete Blob` requires header `x-ms-lease-id` *"if the blob has an active lease"*; absent it → **412 `LeaseIdMissing`**. A properly-formatted-but-wrong lease id → **412 `LeaseIdMismatchWithBlobOperation`**. Source: REST `Delete Blob` Remarks + Request-headers table.
- **F-MERGE (A1):** `az storage entity merge --entity` is *"Space-separated list of key=value pairs. Must contain a PartitionKey and a RowKey."* The entity is addressed by the **PK/RK you pass in `--entity`**, not by any query. `--if-match` **defaults to `*`** (matches any ETag = no optimistic-concurrency guard). `merge` updates only the supplied properties (does not blank unsupplied columns); `replace` overwrites the whole entity. Source: `az storage entity` CLI reference.

---

## Vector 1 — CONCURRENCY (entity-merge race + leased-blob delete)

### 1a. State-blob delete vs terraform state lease — **NOT A RISK (self-protecting), but a required SIGNAL**

The terraform azurerm backend takes a **blob lease** on `terraform.thor` for the duration of any apply/destroy. By F-LEASE, `az storage blob delete` on a leased blob **fails with 412 `LeaseIdMissing`** — it CANNOT silently delete a blob another process is actively writing. So the catastrophic outcome ("I deleted state mid-apply and corrupted a running build") is **blocked by the platform**, not by the plan.

But invert it: that same 412 is the **canary**. If the delete 412s, a build IS running on thor right now and the whole teardown must abort. The plan currently treats the blob delete as fire-and-forget (step 4) with no pre-check.

- **Verdict: NOT A RISK for corruption; REAL RISK for "proceeding while a build runs."**
- **Pre-flight probe (run before step 4, and treat 412/`Locked` as ABORT):**

  ```bash
  az storage blob show \
    --account-name tfstatevpp --container-name tfstate --auth-mode login \
    --name terraform.thor \
    --query "{lease:properties.lease, lastMod:properties.lastModified}" -o jsonc
  # properties.lease.status == 'locked'  OR  state == 'leased'  => a build holds it => ABORT
  ```

  Do NOT break the lease (`az storage blob lease break`) to force the delete — breaking a live terraform lease corrupts a running apply's state. A locked lease means "wait / abort", never "break".

### 1b. `entity merge` races a concurrent pipeline / Logic-App write to the same row — **REAL RISK**

`--if-match` defaults to `*` (F-MERGE). With the default, your merge is an **unconditional last-writer-wins** write. Interleaving that loses data:

```
T0  You: show row thor -> active=used, createdby=Tiago        (read)
T1  Logic App vpp-fbe-autodelete-trigger (daily ~12:30 UTC) OR pipeline 2629 (run by many)
    writes the thor row as part of its own release (active=unused, branch="")
T2  You: merge active=unused createdby='' branch=''            (write, --if-match *)
```

Here the outcomes happen to converge (both want `unused`), so 1b on the *thor* row is low-harm — UNLESS the concurrent actor is a **re-CREATE** (someone re-using the freed slot for a new branch) between your read and your write. Then:

```
T0  You read thor -> used/Tiago
T1  Create pipeline assigns the now-free thor slot to NEW branch (active=used, createdby=NewDev)
T2  Your merge stamps active=unused createdby='' branch=''  -> you just evicted a live new tenant
```

`--if-match *` cannot detect that the row changed under you. This is a classic lost-update / TOCTOU on shared state.

- **Verdict: REAL RISK (lost update on a shared row).**
- **Guard:** capture the **ETag at read time** and pass it as `--if-match <etag>`. If the row changed, the merge fails `412 PreconditionFailed` and you re-evaluate instead of clobbering. See the mandatory guard at the end.

### 1c. Timing-window minimization

The daily Logic App fires ~12:30 UTC. Do not execute the merge inside a ±a-few-minutes window around 12:30 UTC. This is cheap insurance, not a substitute for the ETag guard.

---

## Vector 2 — WRONG-TARGET (does PK=3/RK=3 actually mean thor at write time?)

This is the highest-severity finding and the plan does **not** close it.

The skill warns: *"query by `env eq 'thor'`, NOT `PartitionKey eq 'thor'`."* The agent honored that for the **READ** — the plan says the row was read via `env=thor` and *reports* PK=3/RK=3. But F-MERGE proves the **WRITE is forced to address by PK/RK** (`--entity` must contain PartitionKey and RowKey; there is no `--filter` on merge). So:

1. The skill's safety rule protects the read but **structurally cannot protect the merge** — the merge is positional by construction.
2. The plan hard-codes `PK=3/RK=3` as a literal. PK/RK in this limiter table is a **slot index/identity**, and `env` is a **mutable attribute column** on that row. The binding "PK 3 == thor" is only true **at the instant of the read**. If any concurrent actor (1b) reassigns or rewrites row PK3 between read and write, `env` on PK3 may no longer be `thor` — yet your merge still lands on PK3.
3. Therefore "the merge targets only thor" is an **assumption, not a fact**, and it decays the moment you look away from the row.

A second, quieter wrong-target mode: if the merge is ever fat-fingered to a wrong RowKey that does not exist, `merge` with default `--if-match *` against a non-existent PK/RK does **not** silently create-or-skip in a safe way you can rely on — you must not depend on "it'll just no-op." Always read-back (Vector 4).

- **Verdict: REAL RISK (wrong-target via positional PK/RK + stale env binding).**
- **Certainty probe (immediately before the merge, same command whose ETag you pin):**

  ```bash
  az storage entity show \
    --table-name featurebranchenvdetails --auth-mode login \
    --account-name <featurebranchdeployment-acct> \
    --partition-key 3 --row-key 3 \
    --query "{pk:PartitionKey, rk:RowKey, env:env, createdby:createdby, branch:branch, etag:etag}" -o jsonc
  # REQUIRE: env == 'thor' AND createdby == 'Tiago.Rios@eneco.com'.
  # If env != 'thor' (slot was reassigned) => ABORT. The PK=3 literal is stale.
  ```

  Belt-and-suspenders: re-run the `env eq 'thor'` query and assert it returns **exactly one** row whose PK/RK == 3/3. Two rows, zero rows, or a different PK ⇒ ABORT.

---

## Vector 3 — BLAST RADIUS (can a fat-fingered merge damage other rows / the table?)

`merge` (not `replace`) only touches the entity at the supplied PK/RK and only the properties you name (F-MERGE). It **cannot** reach into other rows — a typo'd PK/RK lands on / misses a *different single row*, it does not spray the table. And because it is `merge`, a missing property name leaves that column untouched (it won't blank `branch` if you forget `branch`) — which is why the plan's choice of **merge over replace is correct** and should be preserved. (If anyone "simplifies" this to `entity replace`, that DOES overwrite the whole entity and can drop limiter columns the pipeline expects — the plan's open question #2. Keep it as merge.)

Residual blast modes that ARE real:
- **Type drift:** `active`, `createdby`, `branch` are strings. If a value is passed with an `@odata.type` mismatch (e.g. `active` written as `Edm.Boolean` when the pipeline reads `Edm.String`), the pipeline's later `atomic-replace` or read may break for the **whole limiter mechanism**, not just thor. Pass plain strings; do not add `@odata.type` overrides. The plan's `active=unused` (string) mirrors the pipeline's `atomic-replace branch="" active=unused`, so match that exactly.
- **Wrong-row single-write:** covered by Vector 2; not a table-wide event but on a SHARED table a single wrong row IS another tenant's slot.

- **Verdict: NOT A RISK for table-wide damage (merge is single-entity, property-scoped); REAL RISK only at the single-row level (folds into Vector 2) and via type drift.**
- **Guard:** named-property string-only merge, mirroring the pipeline's exact column set/values; mandatory read-back (Vector 4).

---

## Vector 4 — IDEMPOTENCY / WITNESS (is "row reads unused" the right close condition?)

The plan closes on "row reads `active=unused`" (witness H-EFFECT-1). That witness is **necessary but not sufficient and not durable**:

1. **Not durable / re-flippable:** the row is shared and written by the create pipeline and the Logic App. "unused" can be re-flipped to "used" seconds later by a legitimate new tenant. So a one-shot read of `unused` proves "my write landed," not "thor is released and stays released." That is fine **as long as** the witness asserts the right thing: *the write I made is the write that's there.* Read-back must check **all three** fields I set (`active=unused`, `createdby=''`, `branch=''`) AND `env=='thor'` AND that the ETag advanced from my pinned write — not just `active`.
2. **Smart-detector alert is a SEPARATE control plane:** it is an `Microsoft.AlertsManagement/smartDetectorAlertRules` (or classic Failure-Anomalies) resource, NOT in the resource-group sweep semantics the plan leans on, and its deletion does NOT show up in the table row. It must be verified **independently** by name, not inferred from "resource list is empty." (This mirrors the repo lesson that Rootly/Azure live on different planes and each must be driven to terminal state.)
3. **State-blob deletion** must be witnessed by `az storage blob show ... -> 404 BlobNotFound`, not assumed from a 202.

- **Verdict: REAL RISK (witness too weak / single-plane).**
- **Witness set (all must pass):**

  ```bash
  # a) slot row: my exact write is present AND still thor
  az storage entity show --table-name featurebranchenvdetails --auth-mode login \
    --account-name <acct> --partition-key 3 --row-key 3 \
    --query "{env:env, active:active, createdby:createdby, branch:branch}" -o jsonc
  #   REQUIRE env==thor, active==unused, createdby=='', branch==''

  # b) smart-detector alert gone (separate plane, by name)
  az resource list --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e \
    --query "[?contains(name,'fbe-thor') && contains(type,'SmartDetector')]" -o jsonc   # expect []
  # (or the classic: az monitor metrics alert / scheduled-query list filtered by name)

  # c) state blobs gone
  for b in terraform.thor thor.appconfig.tfstate; do
    az storage blob show --account-name tfstatevpp --container-name tfstate \
      --auth-mode login --name "$b" -o none 2>&1 | grep -q "BlobNotFound\|ErrorCode" \
      && echo "$b: gone" || echo "$b: STILL PRESENT"
  done
  # tfstate.thor (2024 legacy) must remain — do NOT touch it.
  ```

---

## Vector 5 — ROLLBACK (what is and is not reversible)

| Step | Reversible? | Recovery |
|---|---|---|
| Slot-row merge (active/createdby/branch) | **YES** | Re-merge `active=used createdby=Tiago.Rios@eneco.com branch=fbe-new-mfrr` — but ONLY meaningful if no other tenant took the slot in between. Once released + reassigned, "rollback" would itself be a wrong-target write. So reversibility is **time-boxed**. |
| Smart-detector alert delete | **YES (recreatable)** | Re-create from IaC; it's cosmetic. Low concern. |
| `terraform.thor` state blob delete | **NO** | **One-way door.** 313 KB of state, gone. Soft-delete on the container *may* allow `az storage blob undelete` within the retention window — but the plan has NOT verified soft-delete/versioning is enabled on `tfstatevpp/tfstate`. Treat as irreversible until proven otherwise. |
| `thor.appconfig.tfstate` delete (184 B, empty) | **NO** (but trivial) | Empty; negligible loss. |

The plan's claim "Steps 2-5 are NOT irreversible one-way doors" is **WRONG for step 4**. Deleting the `terraform.thor` state blob is irreversible unless container soft-delete/versioning is enabled AND within retention. This must be called out and de-risked, not assumed away.

- **Verdict: REAL RISK (plan asserts reversibility it has not earned for the state-blob delete).**
- **Guards:**
  1. **Backup-to-disk before delete** (cheap, makes it reversible regardless of soft-delete):
     ```bash
     az storage blob download --account-name tfstatevpp --container-name tfstate \
       --auth-mode login --name terraform.thor --file ./thor-state-backup-$(date +%s).json
     ```
     Keep the backup off the shared account (local task dir). This converts a one-way door into a recoverable step.
  2. Confirm soft-delete posture for awareness:
     ```bash
     az storage account blob-service-properties show --account-name tfstatevpp \
       --query "{softDelete:deleteRetentionPolicy, versioning:isVersioningEnabled}" -o jsonc
     ```

---

## THE ONE OPERATIONAL GUARD THAT MUST BE ADDED BEFORE EXECUTING

**ETag-pinned, env-reconfirmed slot-row merge, gated behind an active-build/lease probe.** This single guard closes Vectors 1b, 2, and the durable half of 4 at once. Without it the teardown is an unconditional last-writer-wins write to a shared, concurrently-mutated row addressed by a stale positional key.

```bash
# STEP 0 — ABORT if a build holds the state lease (Vector 1a canary)
az storage blob show --account-name tfstatevpp --container-name tfstate \
  --auth-mode login --name terraform.thor \
  --query "properties.lease" -o jsonc
# lease.status == 'locked' / state == 'leased'  => a build is running => ABORT, do nothing.

# STEP 1 — read the row by IDENTITY and capture ETag + reconfirm it is thor (Vector 2)
ROW=$(az storage entity show --table-name featurebranchenvdetails --auth-mode login \
  --account-name <featurebranchdeployment-acct> --partition-key 3 --row-key 3 -o json)
echo "$ROW" | jq '{env, createdby, branch, etag}'
# REQUIRE env=="thor" AND createdby=="Tiago.Rios@eneco.com". Else ABORT (PK=3 binding is stale).
ETAG=$(echo "$ROW" | jq -r '.etag')

# STEP 2 — merge ONLY if the row has not changed since the read (Vectors 1b + 2)
az storage entity merge --table-name featurebranchenvdetails --auth-mode login \
  --account-name <featurebranchdeployment-acct> \
  --entity PartitionKey=3 RowKey=3 active=unused createdby='' branch='' \
  --if-match "$ETAG"
# 412 PreconditionFailed => the row changed under you (concurrent create/release) => STOP, re-read, re-decide.
# Do NOT retry with --if-match '*'.

# STEP 3 — read-back witness (Vector 4): env still thor, all three fields are my values.
az storage entity show --table-name featurebranchenvdetails --auth-mode login \
  --account-name <featurebranchdeployment-acct> --partition-key 3 --row-key 3 \
  --query "{env, active, createdby, branch}" -o jsonc
```

Order of the whole teardown stays as the plan has it (residue-zero gate FIRST, release LAST), with two insertions: **(i)** the lease canary + state-blob backup-to-disk immediately before the state-blob delete (step 4), and **(ii)** the ETag-pinned merge above replacing the bare `entity merge` (step 5). The smart-detector alert deletion gets its own by-name verification, not inferred from the resource sweep.

---

## Verdict summary

| Vector | Verdict | Settling guard |
|---|---|---|
| 1a leased-blob delete | NOT A RISK (412 self-protects) / canary | `blob show -> lease.status` before delete; never `lease break` |
| 1b entity-merge race | **REAL RISK** | `--if-match <etag>` |
| 2 wrong-target PK/RK | **REAL RISK** | re-`show`, assert `env=='thor'`, pin ETag |
| 3 blast radius | NOT A RISK table-wide / REAL at single row | keep `merge` (not `replace`), string-only, read-back |
| 4 witness | **REAL RISK** (too weak/single-plane) | 3-plane witness incl. ETag advance + alert-by-name |
| 5 rollback | **REAL RISK** (state delete is one-way) | download-to-disk backup before delete |

**FIX FIRST.** Do not execute the bare `az storage entity merge PK=3/RK=3` as written. Add the ETag-pinned, env-reconfirmed, lease-gated guard above first.
