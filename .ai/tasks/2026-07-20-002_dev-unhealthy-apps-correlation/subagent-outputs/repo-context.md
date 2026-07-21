---
task_id: 2026-07-20-002
agent: archeologist
timestamp: 2026-07-20T12:01:56+02:00
status: complete

summary: |
  Live Azure DevOps history identifies a single automated configuration commit,
  b219de782de8ad12c234fd809b964ca4d11514af, as the source of both DEV image
  regressions. Successful One-For-All build 20260720.1 read two undefined release
  variables as Bash command substitutions, logged command-not-found, converted each
  prior 0.158.0 tag to an empty string, and pushed main anyway. Both charts default
  an empty tag to appVersion latest, explaining why Argo rendered :latest even
  though VPP-Configuration contains no literal latest value.

key_findings:
  - finding_1: Commit b219de changed both DEV image tags from 0.158.0 to an empty string.
  - finding_2: Build 1723565 logged command-not-found for both missing service variables and still succeeded.
  - finding_3: Helm's empty-tag fallback deterministically renders latest for both applications.
  - finding_4: VPP-Configuration main still contains both empty tags at the time of this investigation.
---

# Repository and source-history context

## Bottom line

**CONFIRMED — GIT-VERIFIED + live pipeline evidence:** both failures share one
upstream generator, not merely one Argo sync window.

On 2026-07-20, Azure Pipeline **One-For-All** run
[20260720.1 / build 1723565](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1723565)
successfully pushed
[commit b219de782de8ad12c234fd809b964ca4d11514af](https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/VPP-Configuration/commit/b219de782de8ad12c234fd809b964ca4d11514af)
to the `VPP-Configuration` main branch. That commit changed:

```diff
 Helm/espmessageproducer/dev/values-override.yaml
-  tag: "0.158.0"
+  tag: ""

 Helm/marketinteraction/dev/values-override.yaml
-  tag: "0.158.0"
+  tag: ""
```

The chart templates interpret an empty tag as `.Chart.AppVersion`, and both chart
versions set `appVersion: latest`. Therefore the causal chain is:

```text
missing Release-0.159 variables
  -> Azure macro remains as $(service-name)
  -> Bash treats it as command substitution
  -> command not found yields an empty substitution
  -> yq writes image.tag = ""
  -> pipeline commits and pushes main successfully
  -> Helm's default operator selects appVersion: latest
  -> Argo applies an image reference ending in :latest
```

The coordinator's live-runtime observation that both Applications synchronized
revision `b219de...` around 11:16 CEST matches this repository event: the commit
was authored at 11:12:34 CEST. Runtime/registry behavior was not independently
re-probed in this lane; this report establishes the source-history half of the
correlation.

## Evidence ledger

### 1. Exact configuration commit

The Azure DevOps Git API returned:

- repository: `Myriad - VPP / VPP-Configuration`
- branch: `refs/heads/main`
- commit: `b219de782de8ad12c234fd809b964ca4d11514af`
- parent: `651db79e380464250d32bee6287eed676b915880`
- author/committer: `azurepipelines <azurepipeline@eneco-myriad.com>`
- authored/committed: `2026-07-20T09:12:34Z` (11:12:34 CEST)
- message: `build 20260720.1`

Fetching both target files from the parent commit and from `b219de...`
produced the exact `0.158.0 -> ""` diffs above. A fresh item query against
`main` showed that both target files still resolve to `b219de...` and still
contain `image.tag: ""`; this is not only an old transient commit in local
history.

The local `VPP-Configuration` clone is not a current truth surface: its origin
tracking ref is still `25d008a143a240d7b254582c803a9a096237bd11`, last pulled
2026-04-13, where the same files contain `0.145.0`. That stale snapshot initially
looked internally coherent but was falsified by the live ADO query.

### 2. Pipeline run and missing variables

Live ADO build metadata ties the commit to this run:

- pipeline definition: `One-For-All`
- build ID: `1723565`
- build number: `20260720.1`
- source branch: `refs/heads/release/0.159`
- source version: `1da43a7d5c4dadaa2675e7dd889be7cd4360e08c`
- queued: `2026-07-20T09:12:19.344336Z`
- started: `2026-07-20T09:12:25.944826Z`
- finished: `2026-07-20T09:12:38.988657Z`
- result: `succeeded`

The run used variable group `Release-0.159` (group ID 5820). A live variable
query established:

| Variable | Value |
|---|---:|
| `test-env` | `true` |
| `acc-env` | `true` |
| `prod-env` | `false` |
| `espmessageproducer` | absent |
| `marketinteraction` | absent |

The build log for task **Update values-override.yaml** is the discriminating
behavioral evidence. It recorded:

```text
...sh: line 24: espmessageproducer: command not found
...sh: line 24: marketinteraction: command not found
Updated image tag for espmessageproducer to  in Helm/espmessageproducer/dev/values-override.yaml
Updated image tag for marketinteraction to  in Helm/marketinteraction/dev/values-override.yaml
Updated image tag for marketinteraction to  in Helm/marketinteraction/acc/values-override.yaml
[main b219de782] build 20260720.1
```

This eliminates two plausible alternatives:

- **Not a hand edit:** commit author, message, build number, build time, and log
  all bind the change to the automated run.
- **Not Helm independently choosing latest while a valid tag remained:** the
  parent/current item diff proves the explicit tag was emptied first.

### 3. Failure mechanism in the exact run source

The live pipeline definition fetched at source commit `1da43...` matches the
local source file
`Myriad%20-%20VPP/development/azure-pipeline/pipelines/oneforallmsv2.yaml`.
The relevant mechanics are:

- variable group selected from the release branch name at line 5;
- both service macros interpolated into a Bash array at lines 45 and 47;
- DEV/ACC selection at lines 59-64;
- extracted tag written without a non-empty guard at lines 70-76;
- all changes committed and pushed at lines 84-93.

There is no `set -e`, undefined-variable guard, or `[[ -n "$imagetag" ]]`
precondition. Azure leaves an undefined `$(name)` token in the generated Bash
script; Bash then parses it as command substitution. The missing executable emits
`command not found`, substitutes an empty value, and the surrounding script
continues because the task's final commands succeed. This is why ADO marks the
step and build green while the produced configuration is invalid for these
services.

Local source citation:

- `.../azure-pipeline/pipelines/oneforallmsv2.yaml:5`
- `.../azure-pipeline/pipelines/oneforallmsv2.yaml:40-54`
- `.../azure-pipeline/pipelines/oneforallmsv2.yaml:55-80`
- `.../azure-pipeline/pipelines/oneforallmsv2.yaml:84-93`

### 4. Why an empty string becomes `:latest`

The service charts do not fail closed on an absent tag:

- espmessageproducer chart version `0.2.0` has `appVersion: latest` at
  `azure-pipeline/Helm/espmessageproducer/Chart.yaml:18-24`;
- its Deployment uses
  `.Values.image.tag | default .Chart.AppVersion` at
  `azure-pipeline/Helm/espmessageproducer/templates/deployment.yaml:34`;
- marketinteraction chart version `0.3.0` has `appVersion: latest` at
  `azure-pipeline/Helm/marketinteraction/Chart.yaml:18-24`;
- its Deployment uses the same fallback at
  `azure-pipeline/Helm/marketinteraction/templates/deployment.yaml:52`.

These chart versions match the coordinator's live Argo source observations.
Consequently, `latest` is a derived value. Searching only for a literal
`tag: latest` in VPP-Configuration would miss the failure generator.

## Temporal reconstruction

| Time (CEST) | Event | Evidence class |
|---|---|---|
| Before 11:12 | parent `651db...` pins both DEV services to `0.158.0` | GIT-VERIFIED |
| 11:12:19 | One-For-All build 1723565 queued from `release/0.159` | PIPELINE-VERIFIED |
| 11:12:34 | log records both command-not-found errors and empty updates | PIPELINE-VERIFIED |
| 11:12:34 | automated commit `b219de...` created | GIT-VERIFIED |
| 11:12:38 | build finishes green after pushing main | PIPELINE-VERIFIED |
| ~11:16 | Argo syncs both DEV apps to `b219de...` | COORDINATOR-PROVIDED RUNTIME EVIDENCE |

This ordering supports direct causality: configuration corruption precedes the
shared sync revision by roughly four minutes. The earlier replica maintenance may
have changed when the failure became visible, but it is not needed to explain why
both desired image references became `:latest`.

## Desired state and remaining gap

**Confirmed last known-good repository state:** both DEV files pinned
`0.158.0` at parent `651db...`.

**Confirmed current desired state in Git:** both files contain an empty tag at
`b219de...`, so Helm derives `latest`.

**Not established by repository history alone:** whether the intended recovery
tag should be restored to `0.158.0` or advanced to a specific published 0.159
service tag. The most discriminating next evidence is the registry/service-build
inventory for each repository. A valid tag must be proven to exist before changing
desired state; this lane made no repository or cluster mutation.

There is also a collateral finding: the same run wrote an empty tag into
`Helm/marketinteraction/acc/values-override.yaml`, because `acc-env=true`.
The DEV incident scope does not prove whether ACC has already consumed it, but
the configuration defect exists and merits a separate runtime check.

The log also contains command-not-found for `gatewaynl`, `alarmengine`, and
`alarmpreprocessing`. This demonstrates a recurrence class wider than the two
reported apps: any enabled environment file for a service absent from the release
variable group can be blanked by the same generator.

## Brain scan and falsifiers

- **Dangerous assumption tested:** the matching revision was only a temporal
  coincidence. Falsifier: fetch the parent/current blobs and pipeline log. A
  coincidence would preserve valid tags or show unrelated edits; instead both
  tags changed identically inside the build bound to that commit.
- **Opposite conclusion prediction:** if Argo/Helm had independently selected
  `latest` while Git still specified `0.158.0`, the current blobs would retain
  `0.158.0` and the build log would lack empty updates. Both predictions are
  contradicted.
- **Likely false-green path:** the pipeline's success result reflects the final
  shell command, not semantic validity of every generated tag. The explicit
  command-not-found lines and empty-update messages prove that a green build did
  not validate the configuration it pushed.

## Confidence and proof ceiling

- **High (source-history mechanism):** exact parent/current blobs, commit metadata,
  run metadata, variable-group state, exact-source script, and task log converge.
- **Medium (full incident end-to-end):** the coordinator supplied the live Argo
  revision/sync evidence; this lane did not independently inspect Argo, Kubernetes,
  or ACR.
- **Unverified:** the correct replacement tag for each service and whether the
  collateral ACC configuration has been consumed.

Teaching test: an engineer can safely identify the generator and the two defensive
control points—validate every release variable before writing, and remove the
chart's fail-open `latest` fallback—but must still query published image tags
before selecting a recovery version.
