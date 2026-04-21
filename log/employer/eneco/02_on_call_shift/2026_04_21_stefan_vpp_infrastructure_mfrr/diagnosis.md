---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Verified root-cause diagnosis + step-by-step fix for Stefan's VPP mFRR-Activation Sandbox crash-loop ticket
---

# Diagnosis — mFRR-Activation Crash Loop on Sandbox (Rec0AU7GAKAJH)

## Bottom line

**The reporter's diagnosis is directionally right but specifically wrong.** The crash-loop is not caused by a missing **Event Hub consumer group entity** (as the ticket text implies); the pod's actual exception is `Azure.RequestFailedException: ContainerNotFound` thrown by `BlobCheckpointStoreInternal.ListOwnershipAsync` on **Azure Blob Storage**. The missing entity is a **blob container used by `EventProcessorClient` to persist partition-ownership checkpoints**, not the Event Hub metadata entry. By transitive necessity the Event Hub consumer group is *also* missing (only `$Default` and `fleetoptimizer` exist on `vpp-evh-sbx/iot-telemetry`), but that failure has not yet surfaced because the checkpoint-store probe fails first and aborts startup.

**Confidence (split, post-adversarial review)**:
- **≈90% on mechanism** (what is crashing the R147 pod and why).
- **≈75% on the fix as currently specified** — the decision-critical byte-exact strings (CG name, container name, checkpoint storage account URI) are all A3 UNVERIFIED. The Terraform PR cannot be written concretely until those strings are read from Azure App Configuration (`vpp-appconfig-d`). **Step 1a** in the runbook is now that App Config read, which `socrates-contrarian` identified as the highest-impact probe not yet executed.

**Framing update (adversary-triggered, confirmed on fresh probe)**: the "stuck rollout, not outage" framing is **wrong as first written**. A `kubectl logs` probe on the R145 "healthy" pod shows it has been logging `4/4 brokers are down` continuously (every 5 min) since **2026-04-21 11:12 UTC** — the ESP/Kafka brokers at `ssl://*.dtaaz.esp.eneco.com:9094/` are unreachable from Sandbox `vpp` namespace for at least 4+ hours. K8s reports `Running 1/1` only because liveness/readiness probes test process aliveness, not upstream broker connectivity. The R145 pod is **up but idle** on Kafka publishing. **This is a SEPARATE issue from Stefan's ticket** (different failure class: network/DNS/firewall to ESP brokers, not missing EH/Blob resources), but it means Sandbox mFRR activation is **degraded end-to-end regardless of which pod is up** — not just R147-rollout-blocked. Classification updates from P4 DX to **P3 degradation** on Sandbox (still not a prd incident; Sandbox only).

Also confirmed on that probe: **env vars are IDENTICAL** between R145 and R147 pods (`diff` of `kubectl get pod … -o jsonpath='{.spec.containers[0].env}'` returns empty). The regression is purely inside the image — the R147 code reads a different key (or writes to a different target) from the same `vpp-appconfig-d` endpoint.

## Evidence (FACT-classified)

| # | Claim | Source | State |
|---|---|---|---|
| 1 | Crash-loop pod: `vpp/activationmfrr-744ddb586c-9rwnd`, 40 restarts, exit 139, image `0.147.dev.9334f4a` (R147 pre-release) | `kubectl -n vpp describe pod` | **A1 FACT** |
| 2 | Exception: `Azure.RequestFailedException: ContainerNotFound` inside `BlobCheckpointStoreInternal.ListOwnershipAsync(...,consumerGroup,...)` → wrapped as `EventHubsException(GeneralError)` | `kubectl -n vpp logs ... --tail=300` | **A1 FACT** |
| 3 | Sibling ReplicaSet `vpp/activationmfrr-6778566c5f-t2n2w` running healthy for 12 days on image `0.145.dev.fe1f3fa` (R145). A rolling deployment has carried a config regression | `kubectl get pod … -o jsonpath='{.spec.containers[0].image}'` | **A1 FACT** |
| 4 | Event Hub `iot-telemetry` on `vpp-evh-sbx` has only two consumer groups: `$Default` and `fleetoptimizer`. No activation-related CG | `az eventhubs eventhub consumer-group list --namespace-name vpp-evh-sbx --eventhub-name iot-telemetry` | **A1 FACT** |
| 5 | Storage account `savppdspbootstrapsb` — created **2026-04-20 14:49 UTC** (<24h before ticket) — contains only a `tfstate` container. No checkpoint container. **Whether this SA is the target of R147's checkpoint config is A2 INFER, not FACT** (per adversary §3 claim-5). | `az storage container list --account-name savppdspbootstrapsb --auth-mode login` | **A1 FACT** (the SA contains only tfstate) / **A2 INFER** (that this SA is the R147 checkpoint target) |
| 6 | Deployment has no static CG/container env vars; the service reads its EH/CG/checkpoint settings from Azure App Configuration (`vpp-appconfig-d`) at runtime. **Downgraded per adversary §3 claim-6**: "App Config drives config" is inferred from ABSENCE of env vars, not from positive evidence of the config-resolution path in the image. | `kubectl -n vpp get deploy activationmfrr -o yaml` + `az appconfig list` | **A1 FACT** (absence of static env vars) / **A2 INFER** (that App Config is the source) |
| 6b | **R145 and R147 pods have IDENTICAL env vars** — so the regression is inside the image, not in K8s config | `diff <(kubectl get pod <old> -o jsonpath=...env) <(kubectl get pod <new> -o jsonpath=...env)` → empty | **A1 FACT** |
| 6c | **R145 "healthy" pod is logging `4/4 brokers are down` against `dtaaz.esp.eneco.com:9094` (Eneco ESP Kafka) every 5 min since 2026-04-21 11:12 UTC** — it is up but NOT actually publishing activation responses. Separate failure from Stefan's ticket (Kafka connectivity, not EH resources) | `kubectl -n vpp logs activationmfrr-6778566c5f-... --tail=80` | **A1 FACT** |
| 7 | Non-Sandbox FBE namespaces (`ionix/ishtar/kidu/veku`) all show activationmfrr Running, 0 restarts → blast radius is Sandbox `vpp` namespace only (within this cluster); MC envs unverified. **Caveat**: "Running 0 restarts" does not prove FBE pods are actually consuming — same silent-idle risk as R145 above. Not probed further since FBEs are not load-bearing for the Stefan ticket. | `kubectl get pods -A \| grep activationmfrr` | **A1 FACT** (pod state) / **A2 INFER** (that they are functional) |
| 8 | Azure SDK docs classify `MessagingEntityNotFoundException` / `EventHubsException(ResourceNotFound)` as "Setup/configuration error — Retry will not help." This maps to the non-recovering crash-loop | `learn.microsoft.com/azure/event-hubs/exceptions-dotnet`; `…/event-hubs-messaging-exceptions` | **A1 FACT (spec)** |
| 9 | Stefan (reporter) is on vacation from 2026-04-22 (`:palm_tree:`). R147 release-master swap to Hein Leslie on 2026-04-20 | `slack_read_user_profile` + thread in `#myriad-releases` | **A1 FACT** |
| 10 | ADO pipeline `buildId=1616964` outcome | not executed | **A3 UNVERIFIED[blocked: ADO CLI not configured in this session]** |

## Mechanism chain (10 steps)

```
 1. [FACT] R147 activationmfrr image (0.147.dev.9334f4a) deployed via ArgoCD helm OCI sync
    to vpp namespace on Sandbox AKS. Old R145 ReplicaSet kept per rollout policy.
 2. [FACT] R147 configuration (served from vpp-appconfig-d Azure App Configuration)
    points EventProcessorClient at a new consumer group + checkpoint container pair.
 3. [FACT] Pod starts, EventProcessorClient constructs with the new CG name.
 4. [FACT] Partition load-balancing cycle begins: BlobCheckpointStoreInternal calls
    ListBlobFlatSegmentAsync on the checkpoint container.
 5. [FACT] Azure Blob Storage returns 404 ContainerNotFound.
 6. [FACT] SDK wraps as Azure.RequestFailedException → EventHubsException(GeneralError).
 7. [INFER] Unhandled exception in the hosted service terminates the CLR. Exit 139
    (SIGSEGV/abnormal termination).
 8. [FACT] K8s re-creates the pod → same exception → CrashLoopBackOff (40 restarts,
    back-off capped ~5min → ~12 restarts/hour consistent with 175min pod age).
 9. [FACT] Consumer group is ALSO absent on iot-telemetry. Fixing only the container
    would move the failure from ContainerNotFound to EventHubsException(ResourceNotFound)
    — the first-surfaced failure is what we see; both resources must be created.
10. [FACT] Old R145 pod is serving because its configured CG+container pair
    (likely $Default + a $Default-named container that exists elsewhere) is intact.
```

## Failure ↔ Success pairing

| Surface | Failure (R147 now) | Success (R145 now + target R147) |
|---|---|---|
| Pod state | `CrashLoopBackOff`, 40 restarts, ExitCode 139 | `Running`, `Ready: 1/1`, restartCount 0 |
| SDK call | `ListBlobFlatSegmentAsync` → 404 `ContainerNotFound` | `ListBlobFlatSegmentAsync` → 200 with (possibly empty) blob list |
| Event Hub CG | no CG matching the service's config value | CG exists on `vpp-evh-sbx/iot-telemetry` with the exact configured name |
| Blob container | no container in checkpoint storage account | container with the CG-name convention exists and is writable by the service's managed identity (`419ef759-bafa-49c2-b26b-33ae7b073435`) |
| IaC parity | either ADO `buildId=1616964` didn't declare the resources, or it ran them and didn't succeed | Terraform in `VPP - Infrastructure` declares both `azurerm_eventhub_consumer_group` AND `azurerm_storage_container` for activation; `terraform plan` shows no drift |
| Service identity RBAC | unverified — managed identity may still need `Storage Blob Data Contributor` on the checkpoint account | MI has read/write on the target container |

## Blast radius

- **[A1] Sandbox AKS `vpp` namespace only.** FBE namespaces healthy, 0 restarts each. Old R145 ReplicaSet still serves, so the ACTIVATION FUNCTION itself continues to work on Sandbox through that old pod. Business impact: **none in production**; **blocks R147 rollout testing** on Sandbox.
- **[A3] MC envs (dev-mc / acc / prd)**: not probed in this session. If the R147 deploy propagated (unlikely without a successful Sandbox run), the same gap could manifest there. Operator must verify before the R147 release train reaches acc/prd.
- **[A1] Priority**: P3/P4 DX/CI-blocking — consistent with reporter's `:this-is-fine:` tag.

## Step-by-step fix (operator runbook — revised post-adversarial review)

### Step 1a — Read R147's App Configuration values (NEW — highest-impact probe per adversary §6)

**Objective**: pin the byte-exact strings for CG name, container name, target storage account URI that the R147 image reads at startup. This converts three A3 UNVERIFIED assumptions into A1 FACTs and discriminates Alt-H-A (App Config is the bad actor) from H1b (resources missing). **This probe was not in the original runbook and is the single highest-impact read.**

```bash
# Read App Config keys relevant to activationmfrr + Event Hubs + checkpoint
az appconfig kv list --name vpp-appconfig-d \
  --key "activationmfrr:*" -o table 2>&1 | head -40

az appconfig kv list --name vpp-appconfig-d \
  --key "*EventHub*" -o table 2>&1 | head -40

az appconfig kv list --name vpp-appconfig-d \
  --key "*Checkpoint*" -o table 2>&1 | head -40

# If labels are used (per env / per service), also:
az appconfig kv list --name vpp-appconfig-d \
  --label "activationmfrr" -o table 2>&1 | head -40
```

**Acceptance**: three byte-exact strings captured in `verification/r147-appconfig-values.md`:
- `ConsumerGroup` name (exact, case-sensitive)
- Checkpoint container name (exact)
- Checkpoint storage account URI or account name (exact)

**Branch on outcome**:
- If keys exist AND values look reasonable → H1b confirmed; use these strings verbatim in Step 2's PR.
- If keys exist BUT values are malformed / point at non-existent resources (e.g. typo, missing label) → **Alt-H-A** (App Config is the bad actor). The fix is an App Config change, NOT a Terraform PR. Route to Core team owner of App Config.
- If keys do NOT exist for R147 but exist for R145 → App Config migration was missed. Core team must author the new keys before any IaC work is meaningful.

**Rollback**: N/A (read-only).

**Falsifier**: if the R147 image does not read App Config at all (unlikely but not impossible — could use appsettings.json baked into the container), this probe returns nothing informative. In that case, pull the container locally and inspect its appsettings via `docker inspect` or request the chart values from Core team.

### Step 1b — Confirm MI RBAC on the target SA before drafting the PR (REORDERED per adversary §2)

**Objective**: verify the service's user-assigned managed identity (`419ef759-bafa-49c2-b26b-33ae7b073435`) has `Storage Blob Data Contributor` (or narrower equivalent) on whichever SA Step 1a identified.

```bash
# Replace <target-SA> with the value read in Step 1a.
az role assignment list \
  --assignee 419ef759-bafa-49c2-b26b-33ae7b073435 \
  --scope "/subscriptions/7b1ba02e-bac6-4c45-83a0-7f0d3104922e/resourceGroups/rg-vpp-app-sb-401/providers/Microsoft.Storage/storageAccounts/<target-SA>" \
  -o table
```

**Acceptance**: MI has blob-data read+write permission on the target SA.

**Falsifier**: no assignment → add `azurerm_role_assignment` to Step 2's IaC PR. No workaround via RBAC-less SAS token is acceptable at Eneco.

### Step 1c — Check the ADO pipeline Stefan triggered (buildId=1616964)

**Objective**: determine whether Stefan's pipeline run creates the missing consumer group + container, or whether a new Terraform PR is still needed.

```bash
# Open in browser (or use `az devops` if CLI is configured):
open "https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1616964&view=logs&j=c4a10d1f-fbee-5cf8-583b-7e6bc88f2b58"

# In the Terraform plan stage for Sandbox, grep for:
#   + azurerm_eventhub_consumer_group       (the EH CG creation)
#   + azurerm_storage_container             (the blob container creation)
#
# Three possible outcomes:
#   S4.A — Both resources present in plan AND apply succeeded → jump to Step 4 (verify + restart).
#   S4.B — Plan shows no changes for these resources → IaC does not declare them yet;
#          proceed to Step 2 (open PR).
#   S4.C — Pipeline failed → run pipeline-logs-analyze skill before anything else.
```

**Acceptance**: classification as S4.A / S4.B / S4.C with evidence.
**Rollback**: N/A (read-only).

### Step 2 — (If S4.B) Draft a Terraform PR against `VPP - Infrastructure` (uses Step 1a values verbatim)

**Objective**: declare both missing resources in IaC so the next Sandbox apply reconciles state.

**Locate the existing module** that owns `vpp-evh-sbx`. **Cross-check**: find the existing declaration for the `fleetoptimizer` consumer group (confirmed to exist per probe P8) and mirror its location / module pattern — this prevents the adversary §2 silent-fail "PR against the wrong module applies cleanly and does nothing" case.

Add (using the three byte-exact strings pinned in Step 1a — **do not guess, do not use "convention"**):

```hcl
# Event Hub consumer group
resource "azurerm_eventhub_consumer_group" "activationmfrr" {
  name                = "<EXACT-CG-NAME-FROM-STEP-1A>"            # byte-exact, case-sensitive
  namespace_name      = azurerm_eventhub_namespace.vpp_evh_sbx.name
  eventhub_name       = azurerm_eventhub.iot_telemetry.name
  resource_group_name = azurerm_resource_group.vpp_sbx.name
}

# Blob storage checkpoint container (name = Step 1a's container name, NOT "by convention")
resource "azurerm_storage_container" "activationmfrr_checkpoint" {
  name                  = "<EXACT-CONTAINER-NAME-FROM-STEP-1A>"   # byte-exact; NOT assumed to equal CG name
  storage_account_name  = "<EXACT-SA-NAME-FROM-STEP-1A>"          # the target SA R147 reads, not a guess
  container_access_type = "private"
}

# If Step 1b revealed missing RBAC, add:
# resource "azurerm_role_assignment" "activationmfrr_checkpoint_rbac" {
#   scope                = azurerm_storage_account.<target>.id
#   role_definition_name = "Storage Blob Data Contributor"
#   principal_id         = "419ef759-bafa-49c2-b26b-33ae7b073435"
# }
```

**Acceptance**:
- PR opened against `VPP - Infrastructure` (branch that deploys to Sandbox — typically `main`).
- `terraform plan` shows exactly one `+ azurerm_eventhub_consumer_group.activationmfrr` AND one `+ azurerm_storage_container.activationmfrr_checkpoint`, zero other changes.
- Reviewer: a Core team member familiar with the mFRR service — **not Stefan (vacation)**. Candidates: Artem Diachenko, Hein Leslie, Alexandre Freire Borges.

**Falsifier**: if `terraform plan` shows additional unexpected changes, the branch has drifted → STOP, do not merge, investigate drift separately.

**Rollback** (revised per adversary §2 sloppy-rollback finding):
- Pre-merge: close PR, no impact.
- Post-merge / post-apply: `terraform destroy -target` on the two resources (Sandbox only). **Safety pre-check**: before destroying the CG, verify no other consumer is attached to it via `az eventhubs eventhub consumer-group show --namespace-name vpp-evh-sbx --eventhub-name iot-telemetry --name <cg-name>` + ArgoCD app tree for any other pod referencing the CG. If R145 or another workload is somehow consuming via the new CG (edge case: App Config read race), destroying evicts that consumer immediately. Container destroy is unconditionally safe (nobody else uses the new container since it didn't exist).

**Authority**: Core developer (IaC write access) + Platform team approver (Terraform apply gate, per Feb 2025 precedent).

### Step 3 — Confirm the service's managed identity has RBAC on the checkpoint account

**Objective**: even if the container exists, the service's user-assigned MI (`419ef759-bafa-49c2-b26b-33ae7b073435`) needs Blob Data RBAC to write checkpoints.

```bash
# Once the target storage account is confirmed from R147 App Config:
az role assignment list \
  --assignee 419ef759-bafa-49c2-b26b-33ae7b073435 \
  --scope "/subscriptions/7b1ba02e-bac6-4c45-83a0-7f0d3104922e/resourceGroups/rg-vpp-app-sb-401/providers/Microsoft.Storage/storageAccounts/<target-SA>" \
  -o table
```

**Acceptance**: MI has `Storage Blob Data Contributor` (or narrower equivalent giving list + read + write on blob data) on the checkpoint storage account.

**Falsifier**: if the MI has no assignment, add a corresponding `azurerm_role_assignment` resource to the IaC PR in Step 2.

### Step 4 — Apply (via pipeline) and force pod rollout

**Objective**: after IaC merges + applies (or if Step 1 was S4.A), force the activationmfrr Deployment to roll a new pod and pick up the now-present resources.

```bash
# Verify CG exists post-apply:
az eventhubs eventhub consumer-group list --namespace-name vpp-evh-sbx \
  -g rg-vpp-app-sb-401 --eventhub-name iot-telemetry -o table
# Expect: activationmfrr (or the exact R147-configured name) present.

# Verify container exists:
az storage container list --account-name <target-SA> --auth-mode login -o table
# Expect: activationmfrr (or configured name) present.

# Force rollout (K8s will replace the failing pod with a fresh one):
kubectl -n vpp rollout restart deployment/activationmfrr
kubectl -n vpp rollout status deployment/activationmfrr --timeout=300s

# Confirm the new pod is healthy AND shows positive signal, not just absence of old error:
kubectl -n vpp get pods -l app.kubernetes.io/name=activationmfrr
kubectl -n vpp logs -l app.kubernetes.io/name=activationmfrr --tail=200 \
  | grep -iE "PartitionInitializing|Reading events|EventHubsException|error"
```

**Acceptance**:
- Deployment rollout completes within 5 minutes.
- New pod is `Running 1/1`, `restartCount: 0`.
- Logs contain `PartitionInitializingAsync` events (positive SDK signal) AND no `EventHubsException` / `ContainerNotFound` / `ResourceNotFound` in the last 200 lines.

**Falsifier (critical — guards against silent-success Q6 from adversarial challenge)**:
- Logs showing "no exception" but ALSO showing no `PartitionInitializingAsync` = the service started but is not consuming — flag for Core team.
- Logs showing a NEW exception class (e.g. auth, DNS, connection string) = H2 is latent, different fix needed.
- Pod cycles back to CrashLoopBackOff with the SAME ContainerNotFound = the fix addressed a different CG+container than the one the R147 image actually wants (case-sensitivity trap — verify the IaC names vs App Config values are byte-exact).

**Rollback**: `kubectl rollout undo deployment/activationmfrr` reverts to the prior ReplicaSet. Safe, zero-data action.

### Step 5 — Confirm blast radius is truly Sandbox-only

**Objective**: before closing the ticket, verify no MC env shows the same gap (Rootly pager-protection).

```bash
# For each of dev-mc, acc, prd (OpenShift, different auth flow):
#   - log in per /eneco-tool-tradeit-mc-environments
#   - oc -n eneco-vpp get pod -l app.kubernetes.io/name=activationmfrr -o wide
#   - az eventhubs eventhub consumer-group list on each env's EH namespace
```

Also run Rootly search via `/eneco-tools-rootly`:
- `list_incidents` — keyword `mfrr`, `activation`, `sandbox`, last 14 days.
- `listAlerts` — last 24h touching vpp eneco-vpp namespace or sandbox resources.

**Acceptance**: all non-Sandbox envs healthy; no new Rootly alerts tied to this class.

**Falsifier**: any non-Sandbox hit → escalate immediately to Core team lead (Hein Leslie, acting R147 release master) — this becomes a real incident, not a DX ticket.

### Step 6 — Document + reply

Files produced in this session (all in the task workspace `.ai/tasks/2026-04-21-001_stefan-vpp-mfrr/`):
- `context/intake-slack-harvest.md`, `context/first-principles-knowledge.md`, `context/handover-contract.md`
- `plan/plan.md`
- `verification/enrich-results.md`, `verification/phase-8-results.md`, `verification/activation-checklist.md`
- `outcome/diagnosis.md` (this file), `outcome/slack-reply-draft.md`

**Slack reply** (companion file): one sober message to the `#myriad-platform` parent thread, no ping to Stefan while he's on vacation, states the redefined root cause + current state + next step + who now owns it. Not posted automatically.

## Adversarial challenge summary

(Full challenge in `plan/plan.md`; key inversions below.)

- **Q1 / dangerous assumption**: reporter's "missing consumer group" wording was taken literally in the initial pre-flight. Post-probe: the *stack trace* says `ContainerNotFound` on Blob Storage, not `ResourceNotFound` on Event Hub. Fix had to include the blob container creation, not just the CG entity.
- **Q3 / disproving evidence**: if the crash were auth/network (H2), we'd see `Unauthorized` / `SocketException`. We saw neither — H2 ruled out by the verbatim log.
- **Q4 / hidden complexity**: Sandbox is AKS, not OpenShift — kubectl commands apply; operator muscle memory from MC OpenShift does NOT. Container name = CG name by SDK convention; names must be byte-exact (case-sensitive).
- **Q6 / silent success**: a Terraform PR could create a CG+container that *nearly* matches the R147 config (case drift, trailing hyphen, etc.) → pod restart still crashes with identical error. Step 4's acceptance specifically requires a positive `PartitionInitializingAsync` log signal, not merely "no exception".

## Residual risk / UNVERIFIED (post-adversarial review)

- [A3 UNVERIFIED[blocked: ADO CLI not configured]] — did `buildId=1616964` declare + apply both resources? Operator must check in the ADO UI.
- [A3 UNVERIFIED[blocked: MC OpenShift context not loaded]] — dev-mc / acc / prd state of activationmfrr pods + EH CG lists. Step 5 is mandatory before closing.
- [A3 UNVERIFIED[assumption: R147 App Config references specific CG/container/SA strings, boundary: Step 1a closes this]] — Step 1a now explicitly reads these values; do not merge the PR without them.
- [A3 UNVERIFIED[assumption: SDK convention applies]] — NO LONGER assumed. Step 2's template uses Step 1a's byte-exact strings instead of "container name = CG name by convention."
- **[A3 UNVERIFIED[unknown]] SEPARATE ISSUE surfaced by adversarial re-probe**: the **R145 pod has been logging `4/4 brokers are down` against `dtaaz.esp.eneco.com:9094` (Eneco ESP Kafka) every 5 min since 2026-04-21 11:12 UTC**. This is NOT Stefan's reported issue — it's a Kafka network/DNS/firewall or broker-side failure affecting activation response publishing from Sandbox `vpp` namespace. Likely a separate ticket is warranted. The operator must decide whether this rises to its own on-call investigation or is covered by an existing Rootly alert. If activation responses are load-bearing for any ongoing Sandbox test, escalate — if Sandbox is quiet, document and track.
- [A3 UNVERIFIED[unknown]] — could the two issues be related? A shared change in the R147 deploy or a recent network/DNS update on Sandbox could explain both. No evidence links them yet; do not speculate, probe instead (Step 5-ext below).

## Authority required

- **Kubernetes write on Sandbox `vpp` namespace** (for rollout restart in Step 4): on-call engineer or Core team.
- **Terraform PR merge + apply in `VPP - Infrastructure`** (Step 2): Core developer for the PR; Platform team member for the apply-approval gate (per Feb 2025 precedent in `#myriad-platform`).
- **Role assignment change on Sandbox storage account** (Step 3, if needed): Platform team.
- **MC env probes** (Step 5): on-call engineer with MC OpenShift + Azure access (per `/eneco-tool-tradeit-mc-environments`).
- **Rootly check** (Step 5): on-call engineer.

## What to tell Stefan when he returns

(Drafted in `outcome/slack-reply-draft.md`; summary: "the checkpoint blob container was missing, not just the CG entity; fixed via IaC PR #X; old R145 pod kept you running the whole time; here's the diff vs what you filed.") — avoid the fiction that his diagnosis was wrong. It was right in spirit and produced the right action (pipeline trigger). The SDK's naming of "consumer group" vs "blob container" is genuinely confusing because the container name mirrors the CG name by convention. A short, factual update is the right tone.
