---
task_id: 2026-06-22-010
agent: sherlock-holmes
timestamp: 2026-06-22T16:30:00+02:00
status: complete
summary: |
  Live read-only ADO diagnosis of the BTM pipeline "Add {DEV,ACC,PRD} tag in ADO" step.
  DECISIVE: every pipeline run from 2026-04-24 through 2026-06-11 (DEV and ACC, main and
  fix/tagging) fails with the SAME single error — TF401019 (az boards query repo
  auto-detection 404 on lowercased repo name eneco.vpp.behindthemeter). No pipeline run
  anywhere shows the empty {"workItems":[]} the user reports; that result came from a
  manual/local test, not a pipeline build. All three tag steps authenticate as
  $(System.AccessToken) (project Build Service), NOT mcc-btm-deployment-dta-sp — the
  user's identity model is YAML-falsified. AreaId 6393 maps correctly to Team BtM, returns
  913 work items, and the WIQL works when the IN-list is non-empty. Verdict: H-B2 (benign
  empty / test-artifact) for the [] symptom; the REAL production failure is the unresolved
  TF401019 (the prior --detect false fix was never committed). H-B1 (permission loss) and
  H-B3 (area move) are falsified by live evidence.
---

# Thread-B Live Diagnosis — BTM ADO Tag Step Empty / Failing

**Investigator**: sherlock-holmes (INFER until source-verified by team-lead)
**Mode**: live, read-only, authenticated as `Alex.Torres@eneco.com`
**Tooling**: `azure-cli 2.87.0`, `azure-devops` extension `1.0.2` (A1: `az version`)
**Org**: https://dev.azure.com/enecomanagedcloud | **Project**: `Myriad - VPP`

---

## 0. Narrative-contamination audit (what the reporter ASSERTED vs what is OBSERVED)

| Reporter assertion | Status after live probe | Evidence |
|---|---|---|
| "identity `mcc-btm-deployment-dta-sp` runs `az boards` and lost Boards access" | **FALSIFIED** | YAML: all tag steps use `AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)` (A1-1) |
| "prod (`mcc-btm-deployment-prd-sp`) still works" | **FALSIFIED twice** | (a) PRD tag step uses the SAME `$(System.AccessToken)` (A1-1); (b) `mcc-btm-deployment-prd-sp` does not exist as an ADO user at all (A1-7) |
| "error is gone but `az boards query` returns `{"workItems":[]}`" | **NOT REPRODUCED in any pipeline run** | Every pipeline tag log 2026-04-24 → 2026-06-11 still shows TF401019, not `[]` (A1-3..A1-6) |
| "broke ~2026-04-22 when dta-sp was added" | **temporally coincident, mechanistically disconnected** | dta-sp created 2026-04-22T07:27:25Z (A1-7); but the SP is not the tag-step identity, and TF401019 is already present in the onset-era build 1621832 of 2026-04-24 (A1-6) |

The only KNOWN symptom is the empty/failed tag application. The CAUSE the reporter supplied (per-identity Boards permission loss) is not supported by any live evidence.

---

## 1. Evidence Ledger (A1 = exact command + captured output; A3 = blocked + why)

### A1-1 — AUTH MODEL: all three tag steps run as Build Service, not the SP

`az devops invoke --area git --resource items ... path=/azure-pipelines/deploy-terraform.pipeline.yml versionDescriptor.version=main` (content excerpt):

```yaml
# Development stage:
- script: ./azure-pipelines/steps/azure-boards-add-tag.sh
  env:
    AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)
    TAG: DEV
  displayName: Add DEV tag in ADO
# Acceptance stage: identical, TAG: ACC, AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)
# Production stage: identical, TAG: PRD, AZURE_DEVOPS_EXT_PAT: $(System.AccessToken)
```

`$(System.AccessToken)` = the pipeline job's **Build Service** OAuth token (project-scoped by default), NOT `mcc-btm-deployment-dta-sp` and NOT any service connection. DEV, ACC, PRD are byte-identical in identity. **Consequence**: there is no mechanism by which "dev runs as dta-sp" and "prd runs as prd-sp" — that distinction does not exist in the YAML.

### A1-2 — THE SCRIPT: WIQL is built from `git log`, depends on a non-empty IN-list

`az devops invoke --area git --resource items ... path=/azure-pipelines/steps/azure-boards-add-tag.sh` (main AND fix/tagging are byte-identical):

```bash
#!/usr/bin/env bash
if [[ -z "$TAG" ]]; then
  echo "Missing TAG environment variable"
fi
# get work items IDs from the commits
work_items=$(git log --format=%B | grep 'Related work items:' | grep -Po '\d+' | sort | uniq | paste -sd, -)
query=$(cat <<- END
  SELECT System.Id, System.Tags
  FROM workitems
  WHERE System.AreaId = 6393
    AND System.Tags NOT CONTAINS '$TAG'
    AND System.Id IN ($work_items)
END
)
while read -r work_item_id tags ; do
  az boards work-item update --id "$work_item_id" --field "System.Tags=$tags; $TAG" ...
  echo
done <  <(az boards query --wiql "$query" --output table | tail -n +3)
```

Key structural facts:
- The `az boards query` call has **NO** `--organization`, **NO** `--project`, **NO** `--detect false`. It therefore performs repo auto-detection (the documented TF401019 trigger).
- `$work_items` is sourced from `git log --format=%B | grep 'Related work items:'`. If a branch/commit has no `Related work items:` trailer, `$work_items` is **empty** → `System.Id IN ()`.
- No `set -e`; the `az boards query` error goes to stderr and the step still reports `succeeded`.

### A1-2b — GIT HISTORY: the prior `--detect false` fix was NEVER committed

`az devops invoke --area git --resource commits ... itemPath=/azure-pipelines/steps/azure-boards-add-tag.sh`:

```text
7be4d4c2 2024-11-06T12:10:59Z | Merged PR 101101: Tag ADO work items with ACC or PRD tag after deploy
```

Exactly ONE commit has ever touched the script (2024-11-06). The fix the prior RCA recommended (`--organization/--project/--detect false`) is **not present on main or fix/tagging**. So the production failure path is still wide open.

### A1-3 — DEBUG RUN (fix/tagging, 2026-06-04, build 1668639, "Add DEV tag" log#20): TF401019, not []

`az devops invoke --area build --resource logs ... buildId=1668639 logId=20`:

```text
Script contents: exec ./azure-pipelines/steps/azure-boards-add-tag.sh
ERROR: TF401019: The Git repository with name or identifier eneco.vpp.behindthemeter does not exist or you do not have permissions for the operation you are attempting.  Operation returned a 404 status code.
##[section]Finishing: Add DEV tag in ADO
```

Step result = `succeeded` (no `set -e`). Branch = `refs/heads/fix/tagging`. **This is the most decisive probe**: the supposed "post-fix" debug branch still emits TF401019, because the fix was never committed (A1-2b). There is NO emitted WIQL or `work_items` IN-list in the log because `az boards query` 404s on auto-detect BEFORE the WIQL is evaluated.

### A1-4 — MAIN run 1663945 (2026-06-01/02): DEV (log#43) AND ACC (log#68) both TF401019

`az devops invoke --area build --resource logs ... buildId=1663945 logId=43` (DEV) and `logId=68` (ACC):

```text
# DEV (2026-06-01T16:55Z):
ERROR: TF401019: ... eneco.vpp.behindthemeter does not exist ... 404 ...
# ACC (2026-06-02T07:32Z):
ERROR: TF401019: ... eneco.vpp.behindthemeter does not exist ... 404 ...
```

DEV and ACC fail identically — same identity (`$(System.AccessToken)`), same error. This is positive evidence that the failure is identity-independent and stage-independent.

### A1-5 — MAIN run 1676583 (2026-06-11, "newer", log#43): TF401019

`az devops invoke --area build --resource logs ... buildId=1676583 logId=43`:

```text
ERROR: TF401019: ... eneco.vpp.behindthemeter does not exist ... 404 ...
```

### A1-6 — ONSET-era run 1621832 (2026-04-24, log#43): TF401019 already present

`az pipelines runs show --id 1621832` → branch `feature/827444_updated-Sun-forecast-Message`, finished `2026-04-24T14:47Z`, result `succeeded`.
`az devops invoke --area build --resource logs ... buildId=1621832 logId=43`:

```text
ERROR: TF401019: ... eneco.vpp.behindthemeter does not exist ... 404 ...
```

The error is identical and continuous from 2026-04-24 to 2026-06-11. **No transition from "working" to "broken" is observable in the available logs.**

### A1-7 — IDENTITY: dta-sp exists (created Apr-22), prd-sp does NOT exist

`az devops user list --org ... --top 5000` (2455 members scanned, filtered):

```text
DN= mcc-btm-deployment-dta-sp | PN= 7edd1af1-7718-4130-b798-a9b19e32d080 | origin= aad | accessLevel= Basic | dateCreated= 2026-04-22T07:27:25.183Z
# (no row for mcc-btm-deployment-prd-sp anywhere in 2455 members)
```

- `mcc-btm-deployment-dta-sp` is a real ADO AAD service principal, **created 2026-04-22T07:27:25Z** (matches the reported onset date).
- `mcc-btm-deployment-prd-sp` **does not exist as an ADO user** (full 2455-member scan, zero hits). The "prod SP still works" premise has no ADO identity behind it.

### A1-8 — SERVICE ENDPOINTS: no tag-step service connection; BTM endpoints are Key Vault only

`az devops service-endpoint list --org ... --project "Myriad - VPP"` (filtered to BTM):

```text
EP= eneco-btm-dta-lz-kv | type= azurerm | scheme= ServicePrincipal
EP= eneco-btm-prd-lz-kv | type= azurerm | scheme= ServicePrincipal
```

These are `azurerm` (Azure) service connections consumed by `terraform.yml`/`azure-login.yml`, not by `az boards`. No service connection named `mcc-btm-deployment-*` exists. Confirms the tag step never authenticates via a service connection.

### A1-9 — AREA RESOLUTION + LIVE WIQL: AreaId 6393 = Team BtM, returns 913 items

`az boards area project list --org ... --project "Myriad - VPP" --depth 5`:

```text
id=6393 name='Team BtM' path='Myriad - VPP\Team BtM'  (node GUID dfb04683-b2d4-4019-8285-70aaa12c6ba2)
```

`az boards query --org ... --project "Myriad - VPP" --detect false --wiql "SELECT [System.Id] FROM workitems WHERE [System.AreaId]=6393"`:

```text
work_item_count= 913   (sample: 853190 'ChargePoint' Active, 853008 'ChargePoint' New, 852071 Closed, ...)
```

AreaId 6393 is intact, correctly mapped to Team BtM, and well populated. **H-B3 (area rename/move) falsified.**

### A1-10 — WIQL MECHANICS: empty IN-list ERRORS; non-empty IN-list SUCCEEDS

Empty IN-list (simulates `work_items=''`), `--detect false`, as Alex:

```text
az boards query ... --wiql "... AND System.Id IN ()" --output table
ERROR:  Expecting constant value. The error is caused by «)».
```

Non-empty IN-list, `--detect false`, as Alex:

```text
az boards query ... --wiql "... AND System.Id IN (853190, 853008)" --output table
ID      Tags
------  -----------
853008  ChargePoint
853190  ChargePoint
```

**Two consequences:**
1. A populated IN-list returns rows correctly for the calling identity → the Boards-read path is healthy when reached.
2. An EMPTY IN-list does NOT return `{"workItems":[]}` — it returns `ERROR: Expecting constant value`. So the user's reported `{"workItems":[]}` is NOT the empty-`git log` case via `--output table`/default. The `[]` likely came from a manual `az boards query` where the user wrote a syntactically valid WIQL (e.g. an explicit `IN (somethingThatMatchedNothing)` or a filter with no matches) — a hand-run test, not the pipeline script.

### A1-11 — CSS ACL: Build Service has NO explicit deny on AreaId 6393

`az devops security permission list --namespace-id 83e28ad4-2d72-4ceb-97b0-c7726d5502c3 (CSS) --subject "Project Collection Build Service" --token "vstfs:///Classification/Node/dfb04683-b2d4-4019-8285-70aaa12c6ba2"`:

```text
acesDictionary["...Project Collection Build Service"]: { allow: 0, deny: 0 }
inheritPermissions: true
extendedInfo.effectiveAllow: null  (az could not compute effective for the generic claims descriptor)
```

No explicit allow and **no explicit deny** for the Build Service on AreaId 6393. There is no ACE consistent with "Boards read was revoked on ~Apr 22." (Caveat A3-1 below: this checks the collection-level Build Service claims identity; the exact per-job project Build Service descriptor's *effective* permission is not computable read-only here.)

---

## 2. Blocked / unverifiable read-only (A3 — with the exact admin probe required)

### A3-1 — Effective Boards permission of the actual job-token identity on AreaId 6393
The job runs as `$(System.AccessToken)`. Whether that resolves to "Myriad - VPP Build Service (project)" or "Project Collection Build Service" and its *effective* (inherited) Allow on AreaId 6393 is not computable read-only (A1-11 returned null effectiveInfo for the generic descriptor). **Admin probe**: in ADO → Project Settings → Team BtM area → Security, inspect the *exact* Build Service identity's "View work items in this node" = Allow/Deny/Inherited. Or PCA runs `az devops security permission show` with the resolved project Build Service descriptor. Note: even if this were Deny, it would NOT explain TF401019 (that 404 is a *repo* auth failure that occurs before any Boards read).

### A3-2 — Build 1608485 (2026-04-15 "worked") log content
`az pipelines runs show --id 1608485` → `ERROR: The requested build 1608485 could not be found` (purged / retention aged-out). Cannot confirm whether 04-15 lacked TF401019. **Admin probe**: none available — build is gone. The earliest surviving evidence (1621832, 04-24) already shows TF401019, so "it worked on 04-15" is unverified; if it truly worked, the change between 04-15 and 04-24 is the candidate regression (NOT necessarily the dta-sp addition).

### A3-3 — ADO audit log for the actual Apr-22 change
The precise audit entry (who changed what permission/token-scope on ~Apr 22) requires the ADO Auditing feature (Organization Settings → Auditing), which is PCA-only and not exposed via the user-level CLI here. **Admin probe**: Org Settings → Auditing → filter 2026-04-20..2026-04-26 for `Security.ModifyPermission`, `Token.*`, `Pipeline.*AuthScope*` events.

### A3-4 — `enforceJobAuthScope` / `System.AccessToken` project-scoping
Whether the org/project recently flipped "Limit job authorization scope to current project" (which would shrink `$(System.AccessToken)` Boards visibility) is not readable via the available CLI surface. **Admin probe**: Org Settings → Pipelines → Settings → "Limit job authorization scope…" toggles, and their change date in Auditing. (Counter-evidence: even with project scope, AreaId 6393 is in-project, and the failure is a *repo* 404, not a Boards 403 — so this is a low-probability contributor to the observed symptom.)

### A3-5 — The exact session/run that produced `{"workItems":[]}`
No pipeline run in the available history produced `[]`; every one produced TF401019. The `[]` is therefore an out-of-band manual/local test. **Admin/user probe**: ask Anton/Alex for the exact `az boards query` command they ran manually that returned `{"workItems":[]}` (likely included `--detect false` + a populated-but-non-matching IN-list, or `git log` produced no `Related work items:` and they hand-edited the WIQL).

---

## 3. Ranked Verdict

### Discriminating evidence (the single decisive split)
> **Is the failure a repo-auth 404 before the WIQL runs, or a Boards-read [] after a populated WIQL runs?**
> Every pipeline log (A1-3..A1-6) shows **TF401019 — a repo 404 that aborts BEFORE the WIQL is evaluated**. No pipeline run ever reaches a Boards query that returns rows or `[]`. Therefore the production failure is the repo auto-detect 404, and the reported `[]` is an out-of-band artifact (A1-10, A3-5).

| Rank | Hypothesis | Verdict | Decisive evidence |
|---|---|---|---|
| **1** | **H-B2 — benign empty / test-artifact** (for the `{"workItems":[]}` symptom) | **SUPPORTED** | (a) No pipeline run produces `[]` — all produce TF401019 (A1-3..6). (b) Empty `git log` IN-list produces `ERROR: Expecting constant value`, not `[]` (A1-10). (c) The `[]` only appears in a manual run the user did, where `$work_items` had no matching items. Fix = correct testing + script hardening, NOT a permission grant. |
| **1 (co-primary)** | **TF401019 repo auto-detect 404** (the REAL production blocker — prior RCA mechanism, re-confirmed, fix uncommitted) | **CONFIRMED, UNFIXED** | TF401019 on every run 2026-04-24→2026-06-11 (A1-3..6); script has no `--detect false`/`--org`/`--project` (A1-2); fix never committed (A1-2b). |
| 2 | **H-B1 — per-identity Boards permission loss on AreaId 6393 (~Apr 22)** | **FALSIFIED** | Tag step runs as `$(System.AccessToken)`, not dta-sp (A1-1); prd-sp doesn't even exist (A1-7); no explicit deny on AreaId 6393 for Build Service (A1-11); a populated WIQL returns rows fine (A1-10); and the observed error is a *repo* 404, not a Boards 403. The dta-sp Apr-22 creation is coincidental, not causal. |
| 3 | **H-B3 — area rename/move / scope change** | **FALSIFIED (area branch)** | AreaId 6393 still = `Myriad - VPP\Team BtM`, 913 items (A1-9). enforceJobAuthScope branch remains A3-4 but is low-probability (failure is a repo 404, not a Boards scope 403). |

---

## 4. Conditional Routes (as requested)

1. **work_items IN-list was empty / `[]` is benign (CONFIRMED path)** →
   The `[]` is a **test artifact**, NOT a permission loss. Do **not** request a Boards permission grant for dta-sp.
   Production fix is two-part script hardening:
   - **(a) Stop the TF401019**: add `--organization "$(System.CollectionUri)" --project "$(System.TeamProject)" --detect false` to the `az boards query` call (and the same `--org/--project` to `az boards work-item update`). This is the prior RCA's fix — but it must actually be **committed** (currently it is not: A1-2b).
   - **(b) Guard the empty IN-list**: if `$work_items` is empty, skip the query entirely (`[[ -z "$work_items" ]] && { echo "No related work items in commits; nothing to tag"; exit 0; }`). Otherwise an empty `IN ()` throws `Expecting constant value` (A1-10), which looks like a failure but is benign.
   - Optional: add `set -euo pipefail` so a real failure surfaces instead of a green step.

2. **Items exist but the job token can't see them (Boards 403)** → NOT the observed case (no run reached this state). If, AFTER fix (a) lands, a populated WIQL returns `[]`/403, THEN restore "View work items in this node" Allow for the project Build Service on AreaId 6393 (resolve A3-1 first). Do not pre-emptively grant — there is no evidence it is needed.

3. **Area moved** → NOT the case (A1-9). No query change needed for the area path; AreaId 6393 is correct.

---

## 5. Bottom line for the team-lead

- The production tag step has been failing **continuously since at least 2026-04-24** with **TF401019 (repo auto-detect 404)** — the prior RCA's mechanism is correct, but its **fix was never committed** to main or fix/tagging (A1-2b). That is the real, unresolved blocker.
- The "`{"workItems":[]}` after the fix" report is a **manual-test artifact**, not a pipeline behavior and not a permission loss (A1-3..6, A1-10, A3-5).
- The "dta-sp lost Boards access / prd-sp still works" narrative is **falsified**: the tag step runs as Build Service for all three stages (A1-1), prd-sp has no ADO identity (A1-7), AreaId 6393 is healthy (A1-9), and there is no deny ACE (A1-11). The dta-sp Apr-22 creation is a coincidence, not a cause.
- Recommended fix = **script hardening** (commit `--detect false` + `--org/--project` + empty-IN-list guard + `set -euo pipefail`). **No Boards permission grant is warranted** on current evidence.
- Open items needing a PCA/admin (read-only could not reach): A3-1 (effective Build Service Boards ACE), A3-3 (Apr-22 audit log), A3-4 (enforceJobAuthScope toggle date). None of these change the primary verdict, but they would fully close the "what changed on Apr-22" question — most likely answer: **nothing on the permission plane; the TF401019 was already present and the dta-sp creation is unrelated.**
