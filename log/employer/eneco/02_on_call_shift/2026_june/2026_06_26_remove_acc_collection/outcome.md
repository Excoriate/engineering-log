# Outcome — Remove ACC collection `AssetMonitor_FlexReservation`

**Date:** 2026-06-26 · **Env:** MC Acceptance (`b524d084-edf5-449d-8e92-999ebbaf485e`) · **Action:** one Cosmos Mongo collection deleted (control plane)

## What was requested

Intake: `AssetMonitor_FlexReservation` collection "created from the service instead of Infrastructure rollout"; ACC Terraform/CD (build 1688616) blocked by "already exists". Asked to remove that one collection.

## What I found before acting (A1 FACT)

The team's IaC PR (2026-06-25, `fix(cosmosdb): align AssetMonitor_FlexReservation with shared database throughput`) fixes this exact failure **without deleting** the collection — it adopts the existing shared-throughput collection via `moves.tf` (`mongodb_collection` → `mongodb_collection_shared_throughput`) + `use_shared_throughput=true`, expecting "Plan: 0 to add, 0 to change, 0 to destroy". The real failure is a throughput-model mismatch: the collection has **shared** database throughput; Terraform declared **collection-level** `autoscale_settings`, so AzureRM called `UpdateMongoDBCollectionThroughput` and got `404 NotFound`.

This conflict (delete = data loss + opposite of the team fix) was surfaced. Decision: **delete anyway, as instructed.**

## What was done (A1 FACT)

- Account `vpp-cosmosdbmongo-account-clientgateway-a` / RG `mcdta-rg-vpp-a-storage` / DB `AssetMonitor`.
- Live read-only probe confirmed the target was a **shared-throughput** collection (dedicated-throughput show → NotFound), matching the PR diagnosis.
- Deleted exactly `AssetMonitor_FlexReservation` (`az cosmosdb mongodb collection delete`, exit 0).

## Verification (A1 FACT)

- `show` target → `NotFound` ("collection … doesn't exist").
- `AssetMonitor` collections before → after: `{FlexReservation, ActivationResponse, ActivationRequest}` → `{ActivationResponse, ActivationRequest}`. Both siblings + the `AssetMonitor` database untouched.

## Caveats / next steps

1. The collection's ACC data is gone (irreversible).
2. Removal unblocks the "already exists / 404". On the next ACC CD apply the collection is recreated **empty** — with the team PR it returns as shared throughput (intended); with current main it would return as **dedicated** collection-level throughput (the model the PR corrects). Landing the PR is still the correct durable fix.
3. **Subscription-drift safety note:** the shared `az` default flipped to Sandbox mid-task (concurrent session); the first unpinned delete was safely `AuthorizationFailed` against the wrong sub. Always pin `--subscription` for destructive `az` ops on this machine.
