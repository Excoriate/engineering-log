---
task_id: 2026-07-20-001
agent: codex
role: fresh-reader-review
timestamp: 2026-07-20T10:31:00+02:00
status: complete

summary: |
  A fresh SRE can reconstruct all six requested operational capabilities from the revised three-document set, and can reconstruct the concepts from probes-explanation.md alone. The exact two Pending-diagnosis commands live in the command guide rather than the start document, but the start document names both probes correctly. No contradictory target, replica, control-mode, resource, start-gate, or scenario facts were found across the three documents. Two claim boundaries remain: node request/allocatable headroom is not yet proven, and review_status must not be promoted until mental_model_review points to this fresh-reader receipt rather than the existing goal-fidelity artifact.

key_findings:
  - reader_capability: PASS on all six requested tests
  - cross_document_consistency: PASS for load-bearing operational facts
  - structural_validation: all three documents PASS the Feynman validator; Mermaid rendering was skipped by that validator
  - promotion_gate: update the mental-model receipt pointer before declaring independent challenge complete
---

# Fresh-reader receipt: DEV Argo CD replica maintenance

## Scope and evidence snapshot

I reviewed only these three non-empty user-facing documents in `2026_07_20_001_cmc_argocd_replica_increase_maintenance_dev_acc/`:

- `probes-explanation.md` (`d1fac6e67c5feccbfd142a4c6bd030049ab68144a4da17a265756a8e50748a82`)
- `argocd-openshift-command-probes.md` (`194e3c4037fe8fc92147b19269bc704eb8d66483caf63768a2091b7810fd13f6`)
- `maintenance-july-20-records-findings.md` (`01105f1864254f4655686139e27ca38b0fdf45fd98a59c129cc2a3deba49c7dd`)

The hashes identify the revised files read after their common `2026-07-20T10:26:59+02:00` modification time. The zero-byte `maintenance-july-22-records-findings.md` was not read.

Evidence labels in this receipt:

- **CONFIRMED**: directly present in the cited document line or validator output.
- **INFERRED**: a conclusion drawn from two or more confirmed facts; the chain is stated.
- **UNVERIFIED**: the documents name a missing live probe or future event.

## BRAIN SCAN

- Dangerous assumption: a document that contains every number is operationally usable by a zero-context SRE.
- Falsifier: answer each requested task from `probes-explanation.md` before using the siblings; then use the siblings only to test exact command syntax and factual consistency.
- Opposite-conclusion prediction: if the start document fails as a zero-context conceptual entry point, at least one requested target, count, distinction, calculation, placement branch, or Pending diagnosis will require unstated oral knowledge. If it succeeds, every requested concept and decision will be recoverable from its text, with sibling documents adding command syntax rather than changing the answer.
- Likely false-green: desired and updated counts converge, node CPU looks stable, but one pod remains Pending and usable replicas remain below desired.
- Frame: SRE/operator usability plus Socratic contradiction attack. Downstream actor: the on-call operator deciding whether to continue, challenge CMC, or escalate.

## Verdict

**PASS for capability transfer, with two bounded promotion/claim gates.** I could answer every requested test without oral context. The main document carries the complete conceptual model; the command guide supplies exact executable forms; the evidence record supplies timestamp and attribution discipline.

This does **not** prove that maintenance has started, that the target component/count is known, that a new replica will schedule, or that the change succeeded. All three documents explicitly preserve those boundaries (`probes-explanation.md:16`, `maintenance-july-20-records-findings.md:63-72`, `maintenance-july-20-records-findings.md:185-193`).

## Requested reader tests

| Test | Result | Fresh-reader reconstruction | Exact evidence |
|---|---|---|---|
| Identify the exact DEV target without secret handling | **PASS** | Use Windows App → Developer Desktop → Ubuntu-24.04/WSL. Require server `https://api.eneco-vpp-dev.ceap.nl:6443`, namespace `eneco-vpp-argocd`, and `ArgoCD/eneco-vpp`. Never print `oc whoami -t`, raw kubeconfig, credentials, or credential-bearing screenshots; authentication remains human-only. | `probes-explanation.md:24-36`, `probes-explanation.md:59-68`; corroborated by `argocd-openshift-command-probes.md:10`, `argocd-openshift-command-probes.md:80-104`, `maintenance-july-20-records-findings.md:63-68` |
| State the five active replica counts and control mode | **PASS** | Application controller `1/1` as a StatefulSet; server, repo server, Redis, and Dex each `1/1` as Deployments. The GitOps operator materializes the ArgoCD CR. HA mode is off, server autoscale is off, no HPA exists, and absent replica fields mean no explicit override—not zero; the managed workloads prove the effective default of one. ApplicationSet is not counted because no active workload was observed. | `probes-explanation.md:38-53`, `probes-explanation.md:59-80`; corroborated by `argocd-openshift-command-probes.md:38-49`, `argocd-openshift-command-probes.md:106-164`, `maintenance-july-20-records-findings.md:78-89`, `maintenance-july-20-records-findings.md:106-113` |
| Explain request versus limit versus measured use | **PASS** | A request is scheduler-reserved CPU/memory; a limit is the configured ceiling/constraint; `oc adm top` is sampled consumption, not reservation and not a guaranteed peak. The table makes the distinction concrete—for example, Dex requested `128Mi`, was limited to `256Mi`, and measured `171Mi`. | `probes-explanation.md:82-90`, `probes-explanation.md:136-142`; corroborated by `argocd-openshift-command-probes.md:47`, `argocd-openshift-command-probes.md:180-224`, `maintenance-july-20-records-findings.md:115-122` |
| Calculate each component's +1 reservation | **PASS** | Controller: `+250m CPU`, `+4Gi`; repo server: `+250m`, `+256Mi`; server: `+125m`, `+128Mi`; Redis: `+250m`, `+128Mi`; Dex: `+250m`, `+128Mi`. These are request deltas. Actual-use deltas remain unknown and must be measured. | `probes-explanation.md:144-154`; source per-replica requests at `probes-explanation.md:82-90` |
| Follow placement risk | **PASS** | The six Ready worker snapshots are context, not proof that all nodes are eligible. Selectors, affinity, topology spread, taints/tolerations, request headroom, and scheduler choice can change placement. Follow the new pod with wide pod output, then bind its actual node to node health/metrics and scheduling events; Pending or `FailedScheduling` blocks success. | `probes-explanation.md:92-97`, `probes-explanation.md:156-173`; exact commands and interpretation at `argocd-openshift-command-probes.md:166-178`, `argocd-openshift-command-probes.md:200-234` |
| Diagnose desired=3 / updated=3 / ready=2 / Pending and choose the next two probes | **PASS** | This is not success: desired intent and updated pod creation reached three, but usable capacity reached only two. First run `oc -n eneco-vpp-argocd get pods -o wide`; second run `oc -n eneco-vpp-argocd get events --sort-by=.lastTimestamp`. Stable CPU does not prove that requests and placement constraints can be satisfied. | Concept and probe order at `probes-explanation.md:188-194`; exact commands at `argocd-openshift-command-probes.md:166-178`, `argocd-openshift-command-probes.md:226-234`; explicit answer at `argocd-openshift-command-probes.md:280-288` |

## Attempted-attack ledger

| Attack | What would fail if the attack succeeded | Result | Why it survived or did not |
|---|---|---|---|
| Wrong Argo CD instance among three installations | The operator would monitor a healthy but unrelated instance. | **SURVIVED** | The documents bind server → namespace → CR and explicitly name the wrong-instance false green (`argocd-openshift-command-probes.md:96-104`). |
| Absent replica fields interpreted as zero | The baseline and +1 delta would be wrong. | **SURVIVED** | The main document connects absent override → operator default → managed workload count (`probes-explanation.md:74-80`); the command guide repeats the proof mechanism (`argocd-openshift-command-probes.md:123-149`). |
| HA=false interpreted as “cannot scale” | The reader would reject a legitimate component increase. | **SURVIVED** | HA is defined as a packaged topology, not a ban on explicit per-component scaling (`probes-explanation.md:49-50`; `argocd-openshift-command-probes.md:123-129`). |
| `phase: Available` treated as maintenance success | A component-specific failure could be missed. | **SURVIVED** | The command guide calls phase Available an outer signal and requires workload/pod/node/application proof (`argocd-openshift-command-probes.md:45`, `argocd-openshift-command-probes.md:123-131`). |
| Low node CPU treated as scheduling headroom | A pod blocked by memory requests or placement constraints could be declared healthy. | **SURVIVED for diagnosis; reservation proof remains bounded** | The main document separates candidate context from eligibility and calls Pending/FailedScheduling hard failures (`probes-explanation.md:97`, `probes-explanation.md:160-173`). The self-test rejects stable CPU (`probes-explanation.md:188-194`). The evidence record explicitly says the node-describe attempt is not reservation evidence (`maintenance-july-20-records-findings.md:99-100`). |
| Desired/updated=3 treated as success despite ready=2 | The maintenance would close while one replica is unusable. | **SURVIVED** | Both teaching and command documents require pod and event probes and eventual Ready/Available convergence (`probes-explanation.md:188-194`; `argocd-openshift-command-probes.md:280-288`). |
| Old evidence blamed on CMC | Pre-existing drift or local tooling failure would be misattributed. | **SURVIVED** | T0 and attribution states are defined before findings, and the two pre-existing OutOfSync applications are preserved (`maintenance-july-20-records-findings.md:12-31`, `maintenance-july-20-records-findings.md:89`, `maintenance-july-20-records-findings.md:133-140`). |
| Three documents disagree on target, counts, mode, metrics, start gate, or success semantics | A fresh reader would have two incompatible routes. | **NO LOAD-BEARING CONTRADICTION FOUND** | The target matches at `probes-explanation.md:61-68`, `argocd-openshift-command-probes.md:10`, and `maintenance-july-20-records-findings.md:63-70`; the replica baseline matches at `probes-explanation.md:69-80`, `argocd-openshift-command-probes.md:151-160`, and `maintenance-july-20-records-findings.md:78-89`; maintenance remains start-gated at `probes-explanation.md:175-186`, `argocd-openshift-command-probes.md:258-262`, and `maintenance-july-20-records-findings.md:160-166`. |
| Structure validator mistaken for comprehension proof | A syntactically complete but unusable document would be promoted. | **SURVIVED by independent reader test** | The validator passed all three, but the verdict above comes from reconstructing six observable tasks, not from validator status. Validator output is recorded below. |

## Concision and completeness attack

### Main document

The main document is dense but coherent. The concept bridge makes T0, HA, autoscale, workload types, sync/health, and absent replica fields usable before the baseline (`probes-explanation.md:38-53`, `probes-explanation.md:78-80`). The tables replace what would otherwise require long prose, and the scenario tests transfer rather than trivia.

One navigation weakness remains: the self-test names “wide pod view” and “namespace events” but does not print or link the exact commands (`probes-explanation.md:188-194`). The commands are easy to recover from the sibling guide (`argocd-openshift-command-probes.md:166-170`, `argocd-openshift-command-probes.md:226-230`), so this does not block conceptual transfer; it does prevent `probes-explanation.md` from being a standalone executable runbook. Add a direct relative link to probes 5 and 8 if standalone execution is a goal.

The ASCII chain and Mermaid chart substantially overlap (`probes-explanation.md:99-123`). The Mermaid view adds the application-outcome feedback loop; the ASCII view supplies a render-independent mnemonic. That extra angle is real, but this is the first section to compress if the start document must become shorter.

### Command guide and evidence record

The command guide deliberately front-loads proof and execution vocabulary before the first command (`argocd-openshift-command-probes.md:12-49`, first command at `argocd-openshift-command-probes.md:80`). This helps a zero-context learner but slows incident lookup. The end-of-document minimal sequence (`argocd-openshift-command-probes.md:264-278`) is the correct quick-reference surface; a top link to it would improve live use without deleting teaching content.

The evidence record duplicates only the concepts needed to interpret timestamps and attribution (`maintenance-july-20-records-findings.md:12-31`). That duplication is functional: the record remains intelligible when read during handoff without importing the teaching document.

## Blocking corrections and claim gates

1. **Blocking only before `review_status: complete`: update the mental-model receipt pointer.** `probes-explanation.md:3-4` says `awaiting-independent-challenge` but points `mental_model_review` at `goal-fidelity-attack.md`. A goal-fidelity attack is not this fresh-reader comprehension receipt. Keep the current awaiting status, or point `mental_model_review` to this file before promoting the status. The present operational content is not contradicted by the awaiting status.
2. **Blocking only before claiming pre-change node capacity is proven: obtain request/allocatable evidence.** The main document correctly requires enough requested/allocatable capacity (`probes-explanation.md:169-173`), while the evidence record correctly rejects the failed node-describe attempt as reservation evidence (`maintenance-july-20-records-findings.md:99-100`). The current probes prove measured use, readiness, actual placement, and scheduler failure after it happens; they do not prove pre-change allocatable-minus-requested headroom on every eligible node. Do not convert the percentage snapshots into a capacity-approval claim.

No blocking correction prevents use of the documents for the six requested reader capabilities.

## Validator evidence

Executed against the revised files:

```text
python3 .../how-to-feynman/scripts/validate-feynman-doc.py probes-explanation.md
PASS .../probes-explanation.md
- note: mermaid render skipped

python3 .../how-to-feynman/scripts/validate-feynman-doc.py argocd-openshift-command-probes.md
PASS .../argocd-openshift-command-probes.md
- note: mermaid render skipped

python3 .../how-to-feynman/scripts/validate-feynman-doc.py maintenance-july-20-records-findings.md
PASS .../maintenance-july-20-records-findings.md
- note: mermaid render skipped
```

**Proof tier:** structural validator PASS plus independent fresh-reader capability reconstruction. Mermaid render and live maintenance behavior remain separate proof lanes.

## Residual risks

- **UNVERIFIED:** CMC target component, old→new count, actual start time, and live outcome remain pending (`maintenance-july-20-records-findings.md:63-72`, `maintenance-july-20-records-findings.md:185-193`).
- **UNVERIFIED:** eligible-node reservation headroom is not established; only measured utilization, readiness, current placement, and event probes are proven.
- **UNVERIFIED:** the Feynman validator reported Mermaid rendering skipped. Markdown prose and render-independent ASCII preserve the decision path, but this receipt does not prove visual rendering.
- **VERSION BOUNDARY:** the command guide records client `4.8.11` against server `4.20.16` and limits confidence to commands actually executed (`argocd-openshift-command-probes.md:49`; `maintenance-july-20-records-findings.md:142-149`).

## Epistemic debt summary

- Load-bearing confirmed claims in this receipt: 6 reader-test results, 8 attack outcomes, 3 validator passes.
- Load-bearing inferences: 2—overall capability-transfer PASS; no load-bearing cross-document contradiction found. Both are supported by the test and attack ledgers above.
- Load-bearing unverified claims: 3—future maintenance target/outcome, eligible-node reservation headroom, Mermaid rendering.
- Highest-risk unresolved decision point: do not approve capacity or maintenance success from current percentage snapshots; wait for the intended component/count, fresh T0, actual placement/scheduling evidence, and stabilization.

## Insight audit

The missing two-years-out maintainer constraint is a component-specific, proven method for checking schedulable request headroom before the replica is created. The documents correctly avoid claiming that `top` proves this, but the operator sequence has no live-proven allocatable/requested-capacity probe because the prior node-describe attempt failed. If future policy requires proactive capacity approval rather than observation/escalation, that proof lane must be added and executed with the installed client.
