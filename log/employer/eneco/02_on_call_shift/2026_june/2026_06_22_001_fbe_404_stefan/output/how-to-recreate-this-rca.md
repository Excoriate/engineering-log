---
title: How to recreate this RCA — FBE operations slot 404 (finalizer-wedged app-of-apps)
status: review
timestamp: 2026-06-22T11:50:00Z
agent: eneco-sre-coordinator
---

# How To Recreate This RCA

This is a pass/fail **replay contract**. A different engineer or agent, starting
with no memory of this incident, should be able to rebuild the diagnosis in
[`rca.md`](./rca.md) by walking the ordered probes below. Each probe states the
command, the expected output, and the branch decision. If a step depends on
knowledge that is not written here or in a named source, the contract has failed —
report it, do not improvise.

The original incident is **resolved** (slot serves `200`). Replay is therefore a
re-derivation against a now-healed cluster: the live probes will no longer show the
wedge. To re-witness the wedge state, read the retained pre-fix snapshots named in
the Source Inventory rather than the live objects.

## Recreation Knowledge Contract

A replayer who completes this contract can, afterward, do all of the following — and
each is falsifiable against a named source, not author memory:

1. **Reproduce** the confirmed root cause (app-of-apps wedged mid-deletion since
   `2026-06-01`) by walking probes 0–7 against the live cluster or the retained
   snapshots.
2. **Reject** the three competing hypotheses (PAT expiry, per-app credential gap,
   path/ingress misalignment) using the specific branch decisions in the probe table.
3. **Distinguish** the trap (the `operations` namespace looks `Active` and healthy)
   from the decisive surface (the app-of-apps CR `deletionTimestamp`).
4. **Identify** the one item the probes cannot close (the trigger of the 06-01
   deletion) and name the blocked-access reason plus the exact resolving probe.

The contract **fails** if any step needs knowledge that is not written here or in a
named source — that is the signal to report the gap, not to improvise around it.

## Preconditions

- `kubectl` with the **`vpp-aks01-d`** context (FBE Sandbox AKS, `rg-vpp-app-sb-401`).
  Sandbox is reachable directly — no AVD, no MC service principal, no IP whitelist.
- `jq` for the JSON-field probes.
- `argocd` CLI — optional; every probe here uses `kubectl`, the CLI is a convenience only.
- `az login` against the Sandbox subscription (`7b1ba02e-…`) — required **only** for
  the blocked-trigger probe. The incident ran without it; that gap is what the trigger
  item stays unverified on.

## Source Inventory

| Source | Path | Replay role |
|---|---|---|
| Slack-Lists filing (raw) | `../slack-intake.md` | The original "restore the FBE" request |
| SRE intake / context handover | `../sre-intake.md` | FBE platform model, slot/pipeline IDs, Sandbox topology |
| Sober Slack reply | `../slack-answer.md` | What was communicated back to the filer |
| Live read-only probe ledger | `../../../../../../.ai/tasks/2026-06-22-005_fbe-404-rca-howtofix/context/probe-results.md` | A1 evidence: the confirmed wedge + ruled-out hypotheses |
| Fix + verification ledger | `../../../../../../.ai/tasks/2026-06-22-005_fbe-404-rca-howtofix/context/fix-result.md` | A1 evidence: 404→200 after finalizer clear |
| Antecedent copies (in-package) | `../antecedents/` | The same intake + diagnosis ledgers, retained alongside this package |
| Transcribed probe + fix script | `../proofs/scripts/probes.sh` | The exact commands below, ready to read/replay |
| Raw probe outputs + pre-fix snapshots | `../proofs/outputs/` and `…/context/probes/` (incl. `prefix-snapshot/`) | Re-witness the wedge state on a healed cluster |

## Replay Steps

Walk these in order; each builds on the previous output. The same commands are
transcribed, set-by-set, in [`../proofs/scripts/probes.sh`](../proofs/scripts/probes.sh).

| # | Probe | Expected output | Branch decision |
|---|---|---|---|
| 0 | `kubectl config get-contexts \| grep vpp-aks01-d` | context present | absent → fix kubeconfig, do not guess |
| 1 | `kubectl --context vpp-aks01-d get ns operations -o json` (read `.status.phase`, `.metadata.deletionTimestamp`) | `phase: Active`, **no** ns deletionTimestamp | the namespace does **not** reveal the wedge (the trap) → go to probe 2 |
| 2 | `kubectl --context vpp-aks01-d -n argocd get application operations-app-of-apps -o json \| jq '{deletionTimestamp:.metadata.deletionTimestamp,finalizers:.metadata.finalizers,owner:.metadata.ownerReferences}'` | non-empty `deletionTimestamp` (`2026-06-01T10:50:12Z` in snapshot) + `[resources-finalizer.argocd.argoproj.io]`, owner = ApplicationSet `controller:true` | **confirms the wedge** → continue · empty deletionTimestamp → reject wedge, pivot to credential gap (probe 5) |
| 3 | `kubectl --context vpp-aks01-d -n operations get applications` | only `assetmonitor` present; no `frontend`/`gateway-nl`/`clientgateway` | slot is **undeployed** (matches wedge) · frontend present → routing 404, not undeployment |
| 4 | `kubectl --context vpp-aks01-d -n argocd get applicationset vpp-feature-branch-environments -o json \| jq -r '.status.conditions[]? \| "\(.type)=\(.status)"'` | `ErrorOccurred=False`, `ParametersGenerated=True`, `ResourcesUpToDate=True` | generator healthy → **PAT-expiry ruled out** · `ErrorOccurred=True` + `authentication required` → pivot to PAT rotation |
| 5 | `kubectl --context vpp-aks01-d -n operations get applications -o json \| jq -r '.items[] \| "\(.metadata.name) sync=\(.status.sync.status) health=\(.status.health.status)"'` | no operations app shows `source N of M … authentication required` (only unrelated `loki` helm-values error) | **credential gap ruled out** for this slot · auth error here → register repo-creds before declaring done |
| 6 | `curl -svk https://operations.dev.vpp.eneco.com/ 2>&1 \| grep -iE "HTTP/\|x-correlation-id\|server"` | `404 Not Found` from nginx, **no** `x-correlation-id` | edge 404, **no backend** (undeployed, matches wedge) · 404 **with** `x-correlation-id` → backend exists, path misaligned → this RCA is the wrong authority |
| 7 | `kubectl --context vpp-aks01-d -n argocd get pod argocd-application-controller-0 -o wide` | `Running 1/1`, age ~5d22h (restarted ~06-16, after the 06-01 delete) | a controller restart already happened and did **not** clear the wedge → finalizer removal is the fix, not another restart |

A clean walk through probes 0–7 reproduces the confirmed root cause and the three
ruled-out hypotheses (PAT expiry, per-app credential gap, path/ingress misalignment)
without any author memory.

## Evidence Promotion Rules

A replayed observation may only be promoted to a load-bearing fact under the label
discipline below; anything that cannot be witnessed stays blocked, not assumed.

| Label | Meaning |
|---|---|
| A1 | Externally witnessed this session — command + captured output, file:line, or primary URL |
| A2 | Inferred from A1 facts via a named reasoning chain (e.g. "recreate is a no-op because the wedged CR holds the name") |
| A3 | Could not be probed — the blocking reason and the resolving probe are named |

A probe output is promoted to **A1** only when the command and its captured output are
both retained (see `../proofs/outputs/`). A conclusion built from those outputs is
**A2** only when the reasoning chain is written out. An item the probes cannot reach
stays **A3** with its blocking reason and resolving probe named — never silently
upgraded to a conclusion.

## Reproduction Failure Conditions

The replay **fails** — report it, do not improvise — under any of these conditions.

The decisive one: one item cannot be closed by the probes above — **what triggered the
1 June deletion.** During the incident `az account show` returned `Please run
'az login'`, and the Logic App run-history probe
(`context/probes/08-logicapp-runs.txt`) errored before returning data — so the trigger
is **A3 UNVERIFIED[blocked: az not logged in]**.

Resolving probe (run after `az login` against the Sandbox subscription):

```bash
az logic workflow run list \
  -n vpp-fbe-autodelete-trigger -g rg-vpp-app-sb-401 \
  --query "[?starts_with(startTime,'2026-06-01')]"
```

Timing discriminator already established: the `10:50:12Z` deletion = `12:50 CEST`,
which does **not** match the Mon–Fri 14:30 W.Europe auto-evict schedule — so a manual
destroy or a pipeline `2629` run on 06-01 is the leading suspicion, not the auto-evict
Logic App. The replay is not allowed to assert the trigger as known until this probe
(plus ADO pipeline `2629` run history around 06-01) returns. Treating the timing
suspicion as a conclusion fails the contract.

Other failure conditions: a probe needs a context or credential not listed in
Preconditions; a probe's branch decision is taken without its expected output actually
appearing; or the cluster has healed and no pre-fix snapshot is read to re-witness the
wedge. Each is a contract failure to report, not to work around.
