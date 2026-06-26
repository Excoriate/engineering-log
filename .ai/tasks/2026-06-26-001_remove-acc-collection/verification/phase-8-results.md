---
task_id: 2026-06-26-001
slug: remove-acc-collection
agent: claude-opus-4-8
phase: 8
status: complete
timestamp: 2026-06-26
summary: Deleted exactly one ACC Cosmos Mongo collection (AssetMonitor_FlexReservation) after surfacing a conflicting team IaC fix and obtaining explicit user authorization; verified NotFound with both siblings + parent database intact.
---

# Verification — Remove ACC collection `AssetMonitor_FlexReservation`

## Action taken (A1 FACT)

Deleted one Cosmos DB for MongoDB collection via ARM control plane:

```
az cosmosdb mongodb collection delete --subscription b524d084-edf5-449d-8e92-999ebbaf485e \
  --account-name vpp-cosmosdbmongo-account-clientgateway-a -g mcdta-rg-vpp-a-storage \
  --database-name AssetMonitor --name AssetMonitor_FlexReservation --yes
# exit 0
```

Exact ARM id removed:
`/subscriptions/b524d084-edf5-449d-8e92-999ebbaf485e/resourceGroups/mcdta-rg-vpp-a-storage/providers/Microsoft.DocumentDB/databaseAccounts/vpp-cosmosdbmongo-account-clientgateway-a/mongodbDatabases/AssetMonitor/collections/AssetMonitor_FlexReservation`

## Witnessed effect (A1 FACT — H-EFFECT-1, not exit-0)

- `collection show` AssetMonitor_FlexReservation → `NotFound`: "The collection 'AssetMonitor'.'AssetMonitor_FlexReservation' doesn't exist."
- `AssetMonitor` collections BEFORE: `AssetMonitor_FlexReservation`, `AssetMonitor_ActivationResponse`, `AssetMonitor_ActivationRequest` (3).
- `AssetMonitor` collections AFTER: `AssetMonitor_ActivationResponse`, `AssetMonitor_ActivationRequest` (2 — both siblings intact).
- `AssetMonitor` database itself: still exists.

## Authorization + divergence (A1 FACT)

The team's IaC PR (2026-06-25, `fix(cosmosdb): align AssetMonitor_FlexReservation with shared database throughput`) fixes the same ACC CD failure **without** deleting the collection (adopt-via-`moves.tf` + `use_shared_throughput=true`; "0 add / 0 change / 0 destroy"). This divergence was surfaced to the user via AskUserQuestion (scope + reversibility + the PR); user chose **"Delete it anyway, as instructed."**

## Subscription-drift incident (A1 FACT)

First delete attempt was `AuthorizationFailed` over scope subscription `7b1ba02e` (**Sandbox**) — the shared `az` default had drifted off acc (`b524d084`) mid-task, evidently from a concurrent session. Nothing was deleted (auth-blocked no-op). Remediation: re-pinned default + added explicit `--subscription b524d084…` on every command. The second, pinned attempt succeeded.

## Caveat carried forward (A2 INFER)

- The collection's data is gone (acc). The next ACC CD apply recreates `AssetMonitor_FlexReservation` empty: with the **PR** config → shared throughput (intended); with the **current/unpatched** config → dedicated collection-level throughput (the divergent model the PR corrects). Removal unblocks the "already exists/404" either way.

## Cleanup

- `/tmp/mc-acceptance.env` (SP secret) removed.
- No IP whitelist was enabled (control-plane op) → none to disable.
- `az` left authenticated on acc; not logged out (concurrent session shares `~/.azure`).
