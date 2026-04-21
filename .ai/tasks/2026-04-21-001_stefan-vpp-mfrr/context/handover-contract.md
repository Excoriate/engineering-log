---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Four-part handover contract (identity, mechanism with citation, probes, gates) for /eneco-oncall-intake-enrich
---

# Handover Contract → /eneco-oncall-intake-enrich

## Part 1 — Identity

| Field | Value |
|---|---|
| Ticket | Stefan Klopf / `Rec0AU7GAKAJH` / `CICD Request` bot / 2026-04-21 16:24 CEST |
| Filer status | On vacation from 2026-04-22 (one week) — no direct confirmation possible |
| Coordinator | claude-code (this session), operator = Alex Torres (U09H7TBJFSQ, on-call until Apr 22 09:00 CEST) |
| Service | mFRR-Activation — Activation leg of dispatcher MFRR in `Eneco.Vpp.Core.Dispatching` (consolidated via PR 123675, 2025-05-12) |
| Env | Sandbox (Azure AKS; subscription hypothesis `7b1ba02e-bac6-4c45-83a0-7f0d3104922e`; RG hypothesis `rg-vpp-app-sb-401`; EH namespace hypothesis `vpp-evh-sbx.servicebus.windows.net`) — **verify all three** |
| IaC repo (per ticket) | `VPP - Infrastructure` (ADO project `Myriad - VPP`), pipeline `buildId=1616964` triggered by Stefan |
| Priority | P3/P4 developer-experience (non-prod, no TenneT exposure); reporter tag `:this-is-fine:` |

## Part 2 — Mechanism (with authoritative citation)

Leading hypothesis H1 (reporter's self-diagnosis — treated as **INFER** until F4 passes):

> `mFRR-Activation` pod's `EventProcessorClient` tries to open the named consumer group on the Sandbox Event Hub at startup. The consumer group does not exist. Azure Event Hubs service returns `ResourceNotFound`. SDK throws `EventHubsException(Reason=ResourceNotFound, IsTransient=false)` (or legacy `MessagingEntityNotFoundException`). Per Microsoft Learn, this is a "Setup/configuration error — Retry will not help." Pod exits non-zero → Kubernetes `CrashLoopBackOff`.

Citations:
- EventHubsException / ResourceNotFound: https://learn.microsoft.com/azure/event-hubs/exceptions-dotnet
- MessagingEntityNotFoundException: https://learn.microsoft.com/azure/event-hubs/event-hubs-messaging-exceptions ("Entity associated with the operation does not exist or it has been deleted. Retry will not help.")

Alternatives held live:
- **H2**: Auth/connectivity (different error class — will be clear from F4 log line)
- **H3**: Config-side CG name mismatch (same error class as H1, different fix path — F2 disambiguates)
- **H4**: Recent Apr 16 Core deploy carried new CG name not yet in IaC (sub-case of H3 with temporal link to thread `1776325810.944189`)

**Single highest-information discriminating probe**: capture the pod's crash-loop first-failing log line (F4). Cheap, instantly partitions H1/H3 vs H2; partitions H1 vs H3 when combined with F2.

## Part 3 — Probes (in execution order; each read-only)

### Stage A — Identity resolution (must come first; fills the `<ns>/<eh>/<cg>` blanks)

A1. **Resolve Sandbox subscription + RG + EH namespace current names**
```bash
# Login to Sandbox (MC dev alias is read-only on MC; Sandbox may need a
# distinct subscription login. The on-call engineer must confirm which
# alias/subscription covers Sandbox.)
az account list -o tsv --query "[].{name:name,id:id,state:state}" | grep -i sandbox
# Expected: one subscription whose name or tag indicates Sandbox (likely
# the 7b1ba02e-bac6-4c45-83a0-7f0d3104922e GUID if unchanged since 2024).

az eventhubs namespace list --subscription <sandbox-sub> \
  -o tsv --query "[].{name:name,rg:resourceGroup}" | grep -i vpp
# Expected: vpp-evh-sbx (or renamed). Capture namespace name + RG.
```

A2. **Locate the mFRR-Activation workload on AKS Sandbox**
```bash
# Connect to Sandbox AKS cluster.
az aks list --subscription <sandbox-sub> -o tsv \
  --query "[].{name:name,rg:resourceGroup}"
az aks get-credentials --subscription <sandbox-sub> \
  -g <aks-rg> -n <aks-name> --overwrite-existing

# Find the activation workload.
kubectl get pods -A | grep -iE "mfrr|activation|dispatch"
# Capture: namespace, pod name(s), current status, restartCount.
```

### Stage B — Discriminating falsifier (single cheapest probe for H1 vs H2)

B1 (F4). **Capture the pod's crash-loop log line**
```bash
kubectl -n <ns-from-A2> logs <activation-pod-from-A2> --previous \
  --tail=400 > /tmp/mfrr-activation-crash.log
kubectl -n <ns-from-A2> logs <activation-pod-from-A2> --previous \
  --tail=400 | grep -iE "EventHubs|MessagingEntity|Unauthorized|Socket|ConsumerGroup|ResourceNotFound" \
  | head -n 10
```
Classification at this point:
- `EventHubsException` + `Reason=ResourceNotFound` + path `/consumergroups/<name>` → **H1 or H3 confirmed as "missing CG entity"** (continue to F2/F1 to decide which).
- `UnauthorizedAccessException` / `Unauthorized` / `401` → **H2** (auth/identity). Different fix path — abandon this pipeline for now, open a new investigation.
- `SocketException` / `Name or service not known` / DNS timeout → **H2** (network). Different fix.
- Anything else → surface for Phase 5 plan re-entry.

### Stage C — If Stage B points at H1/H3: IaC vs service-config disambiguation

C1 (F1). **Live Event Hubs consumer group state**
```bash
# For each event hub in the namespace the activation service uses
# (if B1 log line names the EH, use that; otherwise enumerate).
az eventhubs eventhub list --subscription <sandbox-sub> \
  -g <rg-from-A1> --namespace-name <ns-from-A1> -o tsv --query "[].name"

az eventhubs eventhub consumer-group list --subscription <sandbox-sub> \
  -g <rg-from-A1> --namespace-name <ns-from-A1> \
  --eventhub-name <eh-from-log-or-enum> -o table
```

C2 (F2). **Service's expected CG name**
```bash
kubectl -n <ns-from-A2> get deploy <activation-deploy> -o yaml \
  | grep -A3 -iE "ConsumerGroup|EventHub"
kubectl -n <ns-from-A2> get configmap -o yaml \
  | grep -iE "ConsumerGroup|EventHub" -A1 | head -n 40
# Also check helm values if ArgoCD manages the sync:
#   ArgoCD UI → application → live manifest → Deployment envs / ConfigMap / Secret
```

C3. **Compare**: if B1 path's `<cg-name>` matches C2's config but is absent from C1's list → H1 confirmed (IaC gap). If B1 path's `<cg-name>` does NOT match C2's config → H3 confirmed (config drift; fix service config, not IaC).

### Stage D — Pipeline trigger outcome check (F3)

D1. **ADO pipeline buildId=1616964 status + Terraform diff**
```bash
# Via Azure DevOps CLI if available, else browser:
az pipelines runs show --id 1616964 --org https://dev.azure.com/enecomanagedcloud \
  --project "Myriad - VPP" --output json

# Look for the Terraform plan stage. Expected action:
#   + azurerm_eventhub_consumer_group.<name>  (or whatever naming the module uses)
# In the apply stage: "Apply complete! Resources: 1 added..."
```
- If pipeline ran and plan shows `+ azurerm_eventhub_consumer_group` for the missing CG → the fix is in flight; after apply completes, re-run C1 to confirm CG exists, then `kubectl rollout restart deployment/<activation-deploy>` to force a pod restart and watch F4 log class.
- If pipeline ran and plan shows **NO** consumer-group change → the IaC does not declare this CG yet. A Terraform PR against `VPP - Infrastructure` (same shape as Stefan's Oct 2025 PR 144873) is required. Triggering the pipeline again will not help.
- If pipeline failed → pipeline log analysis via `/azuredevops:azuredevops-pipeline-logs-analyze`.

### Stage E — Blast radius (F5)

E1. **Other envs check**
```bash
# For each of dev-mc, acc, prd: repeat A1 + C1 minus B1 (workloads may be
# healthy but the CG could still be absent, causing intermittent failures).
# In OpenShift envs use `oc` and appropriate cluster contexts per
# /eneco-tool-tradeit-mc-environments login flow.
```
If any non-Sandbox env shows same CG missing → escalate, this is a wider regression possibly linked to Apr 16 P3 thread.

E2. **Rootly check**
```bash
# Via /eneco-tools-rootly:
#   list_incidents with keyword "mfrr" or "activation" in last 14 days
#   listAlerts touching sandbox eneco-vpp namespace
```

### Stage F — Historic link check (optional, informational)

F1-hist. Re-open Apr 16 thread `1776325810.944189` in `#myriad-team-core`; slack-search for resolution messages from Alexandre / Tiago on 2026-04-16 afternoon through 2026-04-17 morning to determine whether that "activation service is red" was fixed by a config change, a cherry-pick, or remains open. If it remained open and the same pattern propagated to Sandbox via release, H4 is the more probable root cause than H1.

## Part 4 — Gates (human-in-the-loop boundaries — enrich must NOT cross these)

1. **No writes**: enrich is read-only. No `terraform apply`, no `kubectl apply`, no `az eventhubs consumer-group create`, no merging IaC PRs, no pipeline re-triggers.
2. **No Slack posts**: the reply draft is prepared but NOT posted without operator (Alex) approval. Reporter is on vacation; posting into an empty thread while he's out reads as noise unless there is a resolution to share.
3. **Severity assignment**: if any probe reveals prd impact (F5 or F6 positive), stop and escalate to on-call + Core team leads (Alexandre Freire Borges, Hein Leslie) before further action. Do not decide severity unilaterally.
4. **IaC PR scope**: if H1 confirmed and a Terraform PR is required, draft the PR body in this task workspace — do NOT open the PR on behalf of the user. The PR author should ideally be a Core team member familiar with the mFRR service (with Stefan on vacation: Artem Diachenko or Hein Leslie).
5. **Capturing secrets**: never dump connection strings, managed identity tokens, or key vault secrets into the task workspace. If a probe would reveal such values (e.g. reading a Secret manifest), capture only the existence and key names, never the values.

## Part 5 — Expected outputs of enrich

Write into `$T_DIR/verification/`:
- `enrich-identity.md` — resolved `<sandbox-sub>`, `<rg>`, `<ns>`, `<eh>`, `<cg>`, pod name.
- `enrich-log-classification.md` — verbatim first-failing log line from B1, classification of H1/H2/H3.
- `enrich-state-comparison.md` — C1 vs C2 table.
- `enrich-pipeline-outcome.md` — D1 findings; if pipeline did not declare the CG, a draft Terraform patch (diff against the `azurerm_eventhub` or consumer-group module) ready for a Core engineer to open as a PR.
- `enrich-blast-radius.md` — E1 + E2 findings.
- Updated confidence score (should be ≥95% post-enrich, or flagged explicitly if probes failed).
