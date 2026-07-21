---
task_id: 2026-07-20-001-recheck
agent: verification-engineer
timestamp: 2026-07-20T12:21:03+02:00
status: complete
summary: |
  The repaired snapshot passes all six Feynman validations, all 11 Mermaid renders, all 27 Bash/zsh parse checks, ShellCheck, read-only-command scanning, secret-pattern scanning, and representative jq fixtures. OV-02 is structurally closed and OV-01 now exposes endpoint readiness and target UID, but OV-01 is still incomplete because the Pod output omits labels needed to resolve Service selectors. A new HIGH shell failure was reproduced: a failed top-level `acc_guard || return 1` continues into all four `acc_oc` calls in Bash, and both Bash and zsh mask an upstream `oc` failure behind a successful jq pipeline. The package is therefore FAIL for use as-is; live AVD activation remains PARTIAL as correctly documented.
key_findings:
  - finding_1: Failed guard and pipeline source errors do not fail closed in the human-paste structured block.
  - finding_2: EndpointSlice fields are discriminating, but Service-selector-to-Pod membership remains unresolved from the emitted columns.
  - finding_3: Application fleet aggregation discriminates total, distribution, exceptions, and missing freshness.
---

# Final operational package recheck

## Verdict

**Overall: FAIL for Wednesday use as-is.** The repaired documents are structurally strong and remain read-only, but the new structured block is not fail-closed in Bash and OV-01 still cannot deterministically derive the Service-selected Ready Pod set. Fix those two operational defects, rerun the same probes, and keep all structured commands `NOT YET RUN IN THE AVD` until real human-paste or isolated-kubeconfig activation succeeds.

| Lane | Status | Proof tier | Why |
|---|---|---|---|
| Six Feynman documents | **PASS** | structural + renderer-consumed | Validator returned six PASS results; every document's Mermaid rendered. |
| Mermaid inventory | **PASS** | renderer-consumed | 11 document Mermaid blocks; all 11 rendered in the validator's temporary consumer path. |
| Bash/zsh parsing | **PASS** | structural/static | 27/27 Bash fences parsed in Bash 3.2 and zsh 5.9; ShellCheck warning-or-higher findings: 0. |
| Command mutation safety | **PASS** | structural/static | No `oc`/`kubectl` mutate, exec, debug, or restart command in Bash fences. |
| Secret safety | **PASS** | static pattern scan | No private key, JWT-shaped token, client-secret assignment, password assignment, or long token assignment matched. |
| CPU/memory/node proof | **PASS (document contract)** | structural | Metrics freshness, per-node placement/reservation, and `CANNOT VERIFY` boundaries remain separated; no invented go/no-go percentage. |
| Lens independence | **PASS** | structural | CLI is explicitly the source of truth; Lens/Freelens is convenience/historical context only, not an ACC dependency. |
| OV-01 EndpointSlice join | **PARTIAL** | executable jq fixture + structural gap | Endpoint condition/UID extraction distinguishes false backends, but Service selector cannot be resolved against Pod labels from the supplied Pod output. |
| OV-02 Application aggregation | **PASS (static/fixture)** | executable jq fixture | Correct total/distribution/freshness emitted; Degraded, OutOfSync, and missing freshness are explicit. |
| OV-03 context wrapper | **PASS for bind logic; FAIL for structured-block guard; PARTIAL live** | local behavioral simulation | Base wrapper rejects DEV and survives active-context switches, but the new human-paste block continues after guard failure in Bash. AVD activation remains blocked. |

## Blocking findings

### R-01 — The repaired human-paste block is fail-open after guard or source failure

- **Claim attacked:** the structured serving/fleet block is safe to human-paste and a failed identity/source command prevents evidence collection.
- **Concrete falsifier A:** make `acc_guard` return 1, execute the exact runbook block at lines 217–243 in a normal Bash command stream, and count downstream `acc_oc` calls.
- **Expected if safe:** no `acc_oc` call occurs and the block exits nonzero.
- **Actual:** Bash printed `return: can only 'return' from a function or sourced script`, executed all four downstream calls (`UNGUARDED_ACC_OC_CALLED` four times), printed `TOTAL 0`, reached the end, and exited `0`. zsh exited `1` before downstream calls, so the same instructions have divergent shell safety.
- **Concrete falsifier B:** make `acc_oc` return 42 with no JSON, then run the exact `acc_oc ... | jq -r ...` shape in default Bash and zsh.
- **Expected if safe:** pipeline exits nonzero because the API source failed.
- **Actual:** both shells printed `SOURCE_FAILED` followed by `PIPELINE_EXIT=0`; jq accepted empty stdin and masked the failed source command.
- **Evidence:** `argocd-replica-increase-acceptance-runbook.md:214-246`, especially top-level `acc_guard || return 1` at line 217 and pipelines at lines 222–243.
- **Severity:** **HIGH / BLOCKING.** A wrong-context or failed API read can be followed by apparently successful empty/partial processing, exactly the false green the wrapper exists to prevent.
- **Required change:** make the entire sequence one function or explicit guarded block. Inside it, capture each JSON source before parsing so source and jq status are independently checked, for example `endpoint_json="$(acc_oc ... -o json)" || return 1` followed by `printf '%s\n' "$endpoint_json" | jq ... || return 1`; do the same for Applications. Add `|| return 1` to every non-pipeline query. The documented invocation must call that function and reject any nonzero/empty mandatory result. Do not rely on interactive `set -e` or unspecified `pipefail` state.

### R-02 — OV-01 exposes EndpointSlice identity but still cannot derive the selected Ready Pod set

- **Claim attacked:** a zero-context SRE can resolve a Service selector, form the selected Ready Pod UID set, and compare it with ready EndpointSlice target UIDs.
- **Concrete falsifier:** use a Service selector such as `app.kubernetes.io/name=eneco-vpp-server` with two Ready matching Pods plus one Ready non-matching Pod. The runbook prints the Service selector, but its Pod columns print name, UID, IP, readiness, template hash, and controller revision only—not the labels used by the Service selector.
- **Expected if complete:** emitted data deterministically identifies exactly which Ready Pods the Service selects.
- **Actual:** the EndpointSlice jq output identifies Service label, address, readiness, target name, and target UID, but the Pod output cannot prove selector membership. Naming conventions would be an inference, not a selector join.
- **Evidence:** Service selector at runbook lines 218–219; Pod columns at lines 220–221; required set equality at lines 343–354.
- **Severity:** **HIGH** for the serving invariant because an extra non-selected Ready Pod or missing selected Pod can make manual count/name inference wrong.
- **Required change:** emit full Pod labels in structured JSON and perform or explicitly enable selector evaluation, or provide service-specific label selectors obtained from the Service and run a second context-pinned `get pods -l <selector>` that outputs Pod name/UID/IP/readiness. The falsifier must produce a different selected UID set without relying on Pod names.

## Repaired controls that survived falsification

### OV-01 structured EndpointSlice extractor — partial pass

- **Fixture:** one Service slice with two ready targets versus a plausible wrong slice where the second target is `ready=false` and lacks UID.
- **Correct output:** two TSV rows with `true`, `server-1/uid-1` and `server-2/uid-2`.
- **Wrong output:** the second row changed to `false`, `server-2`, `missing-uid`.
- **Assessment:** the exact jq filter parses and makes backend readiness/identity defects visible. It closes the original `-o wide` blindness, but R-02 prevents full set-equality proof.

### OV-02 deterministic Application aggregation — pass at fixture tier

- **Correct fixture:** two `Synced Healthy` Applications with freshness.
- **Output:** `TOTAL 2`, one `DISTRIBUTION Synced Healthy 2`, zero `EXCEPTION` rows, and two `FRESHNESS` rows.
- **Plausible-wrong fixture:** one healthy, one `Synced Degraded` without `reconciledAt`, and one `OutOfSync Healthy` Application.
- **Output:** `TOTAL 3`; three distributions; explicit exception rows for both non-green Applications; `missing` freshness for the Degraded row.
- **Assessment:** **PASS (STATIC/FIXTURE)**. Lines 391–395 correctly make empty output, jq failure, permission error, missing freshness, or truncation `APPLICATION FLEET STATUS INCOMPLETE`. Live AVD activation remains `NOT YET RUN`.

### OV-03 base context pinning — pass in simulation, live partial

- **Wrong bind fixture:** `oc config current-context` returned DEV; both Bash and zsh printed `WRONG_CONTEXT_REJECTED` and the expected ACC-vs-DEV STOP message.
- **Mid-block switch fixture:** bind ACC, change the active context to DEV, then call `acc_guard` and `acc_oc`; both shells emitted `PINNED=acc-context ARGV=<-n><eneco-vpp-argocd><get><pods>` and `MID_BLOCK_SWITCH_PINNED`.
- **Assessment:** `acc_bind`/`acc_guard`/`acc_oc` logic remains structurally and locally behaviorally sound. The document honestly states `STRUCTURALLY VERIFIED, AVD BEHAVIORAL PROOF BLOCKED` at line 128 and preserves the live ceiling at lines 494–499. R-01 is a separate regression in the newly added top-level structured block.

## Exact executed evidence

1. `python3 <snapshot>/verification/validate-feynman-doc.py --render-mermaid <doc>` for all six documents: six PASS results, each with `mermaid render passed`.
2. Independent inventory: `MERMAID_INVENTORY=11`; the preceding validator execution rendered all 11.
3. Bash-fence harness: `SHELL_SUMMARY expected=27 blocks=27 bash_fail=0 zsh_fail=0 shellcheck_fail=0`.
4. jq fixture harness: `JQ_FIXTURE_ASSERTIONS=PASS`, with correct and plausibly wrong EndpointSlice/Application outputs preserved in the command output.
5. Read-only fence scan: `READ_ONLY_COMMAND_SCAN=PASS`.
6. Secret scan: `SECRET_PATTERN_SCAN=PASS`.
7. Context wrapper harness: wrong contexts rejected and switched active contexts remained pinned in Bash and zsh.
8. Guard negative control: Bash executed four `UNGUARDED_ACC_OC_CALLED` markers and exited 0 after the failed guard; zsh exited 1.
9. Pipeline negative control: Bash and zsh both returned `PIPELINE_EXIT=0` after simulated `acc_oc` exit 42.

No cluster command was run. No document in the immutable snapshot was edited. No Lens/Freelens action was needed.

## Snapshot hashes

```text
04e2a28c791d58c5724653c2245096a91e4ebe3d54c83119d1cc7525294b1e4e  argocd-openshift-command-probes.md
58853e1e1bdc35a0f7b459c8778683bf2230f8adef6b8cf5a5b416c9cb3833f7  argocd-replica-increase-acceptance-runbook.md
777ee0aefcfcb714820994e66bb45ab3a70a5d130b3482193622a366e10809f8  argocd_replica_increase_explained.md
ad984f5c6b5c0b495aa6677105f2d7d2da2ea42cd087dd7f0c821401ec97fcd8  maintenance-july-20-records-findings.md
788d0ba38c123c97350ad3e868fd2081b5f1f3aa397bd33959adf97427f5e7ac  maintenance-july-22-records-findings.md
de69d9afcb2ba7a297d11c6518fec009595a9e70444959aacd5ea484d1284971  probes-explanation.md
b17e6efce7250c753ad934566de5889cf2068980711bf69cd0d964ed52819ce8  validate-feynman-doc.py
```

## Proof ceiling and promotion path

- **FACT / STRUCTURAL:** document shapes, renderer compatibility, shell parsing, static read-only posture, jq fixture behavior, and the two reproduced shell regressions.
- **FACT / LOCAL BEHAVIORAL SIMULATION:** base context wrapper rejects wrong contexts and pins post-bind calls; negative controls reproduce fail-open Bash/pipeline behavior.
- **UNVERIFIED[blocked] / BEHAVIORAL-ACTIVATED:** exact context wrapper, structured EndpointSlice extraction, selector membership, Application aggregation, and installed `oc` behavior in the AVD.
- **UNVERIFIED[future]:** Wednesday CMC intent, T0, replica/resource/node/serving/Application deltas, metrics freshness, Redis quorum, stabilization, and end-user outcome.

Promotion requires: fix R-01 and R-02; rerun all local gates and negative controls; human-paste or isolated-kubeconfig execute the fixed wrapper and structured probes in ACC; record API/context, command status, non-empty structured output, wrong-context rejection, and live proof state. AVD activation must remain **PARTIAL** until that external consumer evidence exists.

## Counter-hypothesis and insight audit

An experienced operator might manually map Pod names to Services and notice empty jq output despite exit 0. That does not meet the user’s zero-context, reusable runbook requirement: the safety property must be carried by command structure and join keys, not operator intuition. The maintainer-facing missing constraint is an executable failure harness shipped beside the runbook for context rejection, source-command failure, selector mismatch, missing backend, and hidden Degraded Application; without it, later edits can reintroduce the same fail-open class while syntax and Feynman checks remain green.
