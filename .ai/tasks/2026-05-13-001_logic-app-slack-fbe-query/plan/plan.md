---
task_id: 2026-05-13-001
agent: pi
status: active
summary: Plan for read-only Azure Logic App inspection.
---
# Plan

## Adversarial Challenge
Companion surface exists as files, but no PI dispatch tool is exposed in this runtime. External typed-frame dispatch is `[UNVERIFIED[blocked]: no executable companion dispatch tool visible]`. Internal adversarial frame: Sherlock falsifies candidate selection by requiring workflow definition evidence, not resource name semantics.

## 6Qs
1. Assumption/fail-mode: active subscription may be wrong -> verify `az account show` after `az account set`.
2. Simplest alternative: resource names may identify role directly -> rejected until definition search confirms Slack prompt.
3. Disproving evidence: no Slack/keep/enable terms in selected app -> report no match.
4. Hidden complexity: Logic App Consumption vs Standard resource shape may require `az logic workflow show` vs `az resource show`.
5. Version probe: record `az version`; already mapped as 2.86.0.
6. Silent fail: redacted/parameterized Slack text may live in connections/parameters -> search full exported JSON and action names.
7. Orthogonal: inspect all three exports symmetrically before choosing.

## Steps
1. `az account set --subscription <Sandbox>`; acceptance: account id matches.
2. `az resource list` filtered by three names; acceptance: each found with id/type/resourceGroup.
3. Export each resource JSON; for Logic workflows also export definition if available.
4. Search JSON with `jq`/`rg` for `slack|keep|enabled|enable|delete|response`.
5. Save matching JSON to `outcome/selected-logic-app.json`; write verification results.

## Spec: direct read-only investigation
- Change: no external product/config changes.
- Acceptance: selected JSON is from Azure CLI output, not inferred from name.
- Verification: Azure CLI output files + term search evidence.
- Rollback: none needed; read-only.
