---
title: "Plan — finish thor FBE teardown (residue-zero-first), grounded in fbe-errors orphan pattern"
task_id: 2026-06-26-002
agent: claude-opus-4-8
status: draft
summary: "Grounded remaining-steps plan to free the thor slot. KV already deleted this session. Remaining: confirm zero residue → delete stale state blobs → release slot row. Ordered residue-zero-FIRST per pattern-azure-resource-orphan-on-slot-reuse (slot release without residue verification is the recurring orphan defect)."
timestamp: 2026-06-26T00:00:00Z
---

# Plan — finish thor FBE teardown (residue-zero first)

## Where we are (verified live, 2026-06-26)

| Item | State | Label |
|---|---|---|
| KV `vpp-fbe-thor-vuo` | **GONE** — `az keyvault show`=NotFound, `list-deleted`=empty (delete ran; purge race-errored but vault is neither active nor soft-deleted) | A1 |
| Smart-detector alert `Failure Anomalies - vpp-insights-fbe-thor` | **present** | A1 |
| state blob `terraform.thor` | **present, 313 KB (stale — references already-destroyed infra incl. the now-deleted KV)** | A1 |
| state blob `thor.appconfig.tfstate` | present, 184 B (empty) | A1 |
| state blob `tfstate.thor` | present, 13 KB, 2024 legacy — UNRELATED, leave it | A1 |
| slot row `featurebranchenvdetails` env=thor | **`used`, createdby=Tiago.Rios@eneco.com, branch=fbe-new-mfrr, PK=3/RK=3** (NOT yet released) | A1 |

## The governing lesson (pattern-azure-resource-orphan-on-slot-reuse)

> "Slot release without residue verification is a recurring defect. The destroy pipeline ends with `atomic-replace branch="" active=unused` regardless of cloud-side success. Every release creates the opportunity for [the orphan] pattern to fire on the next tenant."

⇒ I MUST drive Azure residue to **zero** AND clear the stale state **before** releasing the slot. My earlier ad-hoc order (KV first, then state, then release) was roughly right but I had not verified residue-zero as a gate. New order makes residue-zero an explicit gate.

## KV anomaly — scrutiny

`az keyvault delete` returned; `az keyvault purge` errored "No deleted Vault found"; now `show`=NotFound AND `list-deleted`=empty. Two readings, neither blocks the goal:
- (A) fully gone → name reusable now.
- (B) soft-deleted but not surfacing in `list-deleted` → name locked 7d. **Does NOT block the next thor create** — the KV name carries a RANDOM suffix (`-vuo`); the next create generates a NEW suffix, so a lock on `vpp-fbe-thor-vuo` is irrelevant.
Either way: no thor KV is active, nothing references the per-FBE KV (it is a copy SINK from shared `vpp-aks-d`, never a source — 06-22 L3). Safe.

## Remaining steps (ordered: residue-zero gate FIRST, release LAST)

1. **Cross-dependency residue scan** (orphan-pattern signatures 4-5): confirm no role assignments / private endpoints / event-grid subs reference any thor resource; confirm the only thor resource left is the cosmetic smart-detector alert.
2. **Delete the smart-detector alert** → Azure residue now ZERO.
3. **GATE: re-list** `az resource list -g rg-vpp-app-sb-401 [?contains(name,'thor')]` → MUST be empty before proceeding.
4. **Delete stale state blobs** `terraform.thor` + `thor.appconfig.tfstate` (safe ONLY because residue is zero — nothing in cloud to orphan; leave legacy `tfstate.thor`).
5. **Release the slot** — `az storage entity merge` PK=3/RK=3 `active=unused createdby='' branch=''` (mirrors the pipeline's `atomic-replace branch="" active=unused`; UPDATE not DELETE — preserves the limiter row).
6. **Witness (H-EFFECT-1):** row reads `active=unused`; zero thor resources; state blobs gone.

## Reversibility / safety

- Steps 2-5 are NOT irreversible one-way doors (the KV — the only one-way door — is already done). The slot row merge is reversible (could be set back to used/Tiago).
- Authorization: user explicitly authorized "release that FBE slot, and delete thiago's one" + "do it on his behalf."
- Per orphan-pattern anti-patterns: I am NOT triggering destroy pipeline 2629, NOT doing `terraform state rm`, NOT patching IaC.

## Residue verification (done — the orphan-pattern gate)

`terraform.thor` = 64 managed blocks but only **13 have live instances, ALL KV-tied**: `azurerm_key_vault`×1 (`vpp-fbe-thor-vuo`, deleted), `key_vault_access_policy`×10 (on that KV), `key_vault_secret`×1 (on that KV), `random_string`×1 (`vuo`, not a cloud resource). The other **51 blocks have empty instances = destroyed in run 1**. [A1, jq on downloaded state]

Blind-spot closure (types NOT shown by `az resource list`):
- custom role definitions w/ thor → **none** (`az role definition list --custom-role-only`). [A1]
- user-assigned managed identities w/ thor (federated-cred parents) → **none** (`az identity list`). [A1]
- role assignments at thor scope → **none** (`az role assignment list --all`). [A1]
- whole-sub resource sweep → **only** the cosmetic smart-detector alert. [A1]

⇒ **Cloud residue is zero** once the smart-detector alert is deleted. State is fully stale (its only live entries were the now-deleted KV). Deleting the state blob orphans nothing.

## Open questions for adversarial review

- Could a Cosmos **database inside a SHARED account** (named `thor`, not surfacing in a resource-name sweep) still exist despite the state instance being empty?
- Could the slot-row `merge` corrupt the limiter (missing a column the pipeline expects)?
- Is the KV anomaly (gone but purge-errored) truly harmless?
- Is force-deleting the state blob the right call vs. simply leaving the slot release to a (now-unblocked, KV-gone) pipeline re-run?
