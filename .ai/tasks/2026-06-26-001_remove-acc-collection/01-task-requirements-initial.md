---
task_id: 2026-06-26-001
slug: remove-acc-collection
agent: claude-opus-4-8
phase: 1
status: partial
timestamp: 2026-06-26
summary: Remove the service-created ACC Cosmos collection AssetMonitor_FlexReservation so the Terraform rollout can recreate it under IaC; one-way-door delete with read-only discovery + explicit authorization gates.
---

# Task — Remove ACC Cosmos collection `AssetMonitor_FlexReservation`

## Source authority (intake.md, verbatim)

- `[ACC] Terraform: AssetMonitor_FlexReservation already exists`
- ADO build 1688616 (Myriad - VPP) blocked by the "already exists" error.
- "`AssetMonitor_FlexReservation` collection has been created **from the service**
  instead of Infrastructure rollout."
- Slack-Lists record: `Rec0BCL8CQXK3` (ref `Rec0B7GSLKXRR`).

## Accepted end-state

The single collection `AssetMonitor_FlexReservation` (service-created, out-of-band)
is removed from the **ACC** Cosmos account so the Infrastructure (Terraform) rollout
can recreate it under IaC management. **Exactly one** collection removed; no sibling
collection, database, or account touched.

## Classification

- ORIGIN = raw (a direct on-call ask referencing a Slack-Lists filing).
- SURFACE = **terraform-iac-apply** (the "already exists" = Terraform-state-vs-Azure
  reality drift). The ADO pipeline is the messenger, not the surface
  (`surface-pipeline-ado` near-miss → route to terraform-iac-apply).
- MUTATION class = **one-way-door Azure resource delete** (Cosmos collection delete
  destroys the collection's data; irreversible on an on-call timescale).

## ACC identity (from eneco-clis-and-tools.md)

- subscription = `b524d084-edf5-449d-8e92-999ebbaf485e`
- login alias `enecotfvppmcloginacc` | suffix `acc`
- Whitelist `enecoazwhitelistaccon/off` — **NOT required** (collection delete is ARM
  control-plane, not bootstrap-SA data-plane). Whitelist avoided ⇒ wrong-sub
  whitelist trap N/A, but `az account show == b524d084…` still verified pre-mutation.

## Safety gates (binding)

- H-SAFETY-1: one-way door → HALT for explicit user authorization (AskUserQuestion
  citing exact resource id + reversibility) BEFORE delete.
- sre-safety-preflight.sh acc MUST pass (ambient sub == target) before mutation.
- H-EFFECT-1: close on observed effect (collection NotFound), never exit-0.
- H-ROLLBACK-1: regressed/over-deleted → escalate, never blind-retry.
- finally: `az logout` of the SP at task end. (No whitelist toggled ⇒ no
  whitelist-off needed, but verify none was left on.)

## Success criteria (externally witnessable)

1. Exact target identified: Cosmos account + database + collection resource id in ACC.
2. User authorizes that exact id.
3. `az cosmosdb mongodb collection show` (or matching API) → NotFound after delete.
4. Sibling collections list before == after minus the one target (no collateral).

## Open unknowns (probe live, read-only, before any delete)

- U1: Cosmos API kind (Mongo `collection` vs other) and the exact account/db names.
- U2: Whether the MC login alias also `az login`s the SP (needed for `az cosmosdb`).
- U3: IaC source location confirming the Terraform resource address + name.
