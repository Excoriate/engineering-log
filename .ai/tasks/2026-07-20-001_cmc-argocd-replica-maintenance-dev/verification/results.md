---
task_id: 2026-07-20-001
agent: codex
status: complete
summary: Live DEV proof is complete, ACC preparation is bounded, the exact final document bytes pass the full static and wrong-variant suite, and independent assurance is closed with live AVD, Wednesday, and human-reader evidence explicitly future.
---

# Verification results

## Outcome by proof layer

| Claim | Epistemic state | Highest proof tier | Result |
|---|---|---|---|
| DEV Argo CD effective topology increased and converged | FACT | BEHAVIORAL-ACTIVATED | server `1→3`, repo server `1→2`, standalone Redis changed to three HAProxy plus three Redis/Sentinel Pods; controller and Dex remained one. Final sample: all twelve Argo CD Pods Running/Ready with zero restarts. |
| DEV control-plane health remained stable across the observed interval | FACT | BEHAVIORAL-ACTIVATED | Workloads converged, EndpointSlice/application/event/resource layers were sampled, `solver` recovered, and the user declared maintenance complete. This proves only the captured interval, not an unsupplied long-term duration. |
| Post-maintenance application degradation was caused by the replica increase | FACT: refuted | ADVERSARIAL-SURVIVED plus external runtime/source chain | The control plane stayed healthy. Both applications consumed one bad generated revision with empty tags, Helm defaulted to `latest`, and the registry lacked those manifests. F-014 records the separate cause. |
| ACC preparation topology | FACT at capture time | BEHAVIORAL-ACTIVATED read-only snapshot | At preparation capture, effective components were one replica each, Redis was standalone, HA false, and no HPA was present. This expires at Wednesday T0. |
| ACC pinned-context wrapper | INFER | STRUCTURAL plus local behavioral simulation | The wrapper parses and rejects/pins contexts in a stub. Automated AVD typing corrupted punctuation, so installed AVD behavior is `UNVERIFIED[blocked]`. |
| EndpointSlice Pod-UID join and full Application aggregation | INFER for ACC runtime; FACT for fixture behavior | STRUCTURAL and behavioral fixture | Exact jq forms parsed and discriminated a missing-backend/incomplete-fleet fixture. They have not yet run in the AVD/ACC consumer. |
| Six documents satisfy the Feynman protocol | FACT for structure | STRUCTURAL/consumer-rendered | All six pass the named validator with Mermaid rendering. Eleven Mermaid blocks rendered. |
| Runbook shell blocks parse | FACT for syntax | STRUCTURAL | Twelve Bash fences pass Bash and zsh parsing; ShellCheck warning-or-higher produced no findings. This is not installed `oc` behavior. |
| Durable documents contain no detected secret-shaped value | FACT for the tested patterns | STRUCTURAL | Bearer/token/password/`sha256~` scan returned no matches. A pattern scan is not a general proof that no sensitive business data exists. |
| Freelens DEV configuration and access | FACT | BEHAVIORAL-ACTIVATED UI observation | PowerShell `cmctoolsverify` passed; `cmcfreelens dev` selected/verified the DEV API/project and exported the current context; the fresh `file=~\\.kube\\config` row loaded the cluster view. The earlier `Unauthorized` page was a duplicate stale-row false negative. |

## Executed discriminators

1. Wrong-cluster identity: expected ACC API versus a different active context. A different API must reject the sample, not merely label it ACC.
2. Desired versus realized: a CR desired count without updated/ready/available workload equality cannot pass convergence.
3. Ready versus serving: selected Ready Pod UID set must equal ready EndpointSlice target UID set for the applicable Service.
4. Screenful versus fleet: deterministic Application total/distribution/exception/freshness output distinguishes a full fleet from a truncated green view.
5. Usage versus scheduling: low measured CPU/memory cannot override per-node request fit, scheduler constraints, or `FailedScheduling` events.
6. Green pipeline versus healthy runtime: the July 20 incident proves a pipeline and Argo sync can succeed while image realization fails.

## Belief changes

- The maintenance was broader than “increase server replicas”: Redis changed topology from standalone to an HAProxy/Redis-Sentinel shape, which adds a separate routing/quorum proof obligation.
- Controller CPU rose during convergence, but the evidence does not isolate replica reconciliation from concurrent application reconciliation. The document now records correlation plus hypotheses, not an invented cause.
- Numeric observation defaults were initially mistaken for acceptance gates. They were removed; completion duration must come from signed intent or explicit human handoff.
- A complete Application fleet cannot be proved by a visible table. The ACC capture now fails closed unless total, distribution, exceptions, and freshness are all present.
- The real post-maintenance failure was a fail-open generation chain, not Argo CD control-plane instability. That distinction is now a reusable teaching example and ACC T0 guard.

## Generated/actionable artifact inventory

| Source | Derived artifact | Consumer/validator | Proof | Blocked residual |
|---|---|---|---|---|
| Live DEV `oc` observations | DEV command proof and findings ledger | on-call SRE / cross-sample reconciliation | BEHAVIORAL-ACTIVATED | no end-user transaction test; actor causation bounded |
| Live ACC preparation observations | ACC ledger and runbook starting card | Wednesday operator | BEHAVIORAL-ACTIVATED at capture time | expires at T0; Application fleet baseline incomplete |
| Argo/Kubernetes source-backed model | first-principles syllabus | new SRE / Feynman validator / Mermaid renderer | SOURCE-VERIFIED plus STRUCTURAL | human learning transfer remains future USER-GRADED evidence |
| Runbook commands | Wednesday cockpit and probe blocks | Bash, zsh, ShellCheck, jq fixtures | STRUCTURAL plus fixture behavior | installed AVD/`oc` activation still blocked |
| Pipeline/repository and live Pod evidence | F-014 and worked Synced-Degraded example | Slack/on-call/Wednesday attribution | external source plus runtime chain | ACC consumption of the blank override remains unverified |

## Epistemic debt

- FACT: 6 load-bearing observations above.
- INFER: 2 operational mechanisms whose local fixtures pass but whose ACC consumer has not run them.
- UNVERIFIED[blocked]: 1—AVD execution of the pinned context wrapper.
- UNVERIFIED[future]: CMC's exact ACC intent, Wednesday T0 state, future convergence, Redis functional quorum, and end-user transactions.

Top unresolved decision points:

1. Do not start Wednesday monitoring until a human paste or isolated kubeconfig proves `acc_bind`, `acc_guard`, a pinned query, and the wrong-context rejection in the AVD.
2. Do not call ACC complete as intended until CMC supplies the exact component/count/topology and observation/handoff contract.
3. Do not attribute a pre-existing `marketinteraction` degradation to maintenance; establish its revision/image/ReplicaSet/event baseline first.

## Independent gates

- zero-context fresh-reader recheck 2: PASS at source/document-transfer tier;
- user-verbatim goal-fidelity recheck 2: PASS;
- operational command/proof-sufficiency recheck 2: PASS for documentation and exact local failure fixtures; live activation PARTIAL;
- independent assurance grading: `CONDITIONALLY_ASSURED`; its current-byte condition C-010 was subsequently cleared by the exact current-corpus suite below. C-011 remains the intended AVD/Wednesday/human evidence boundary.

## Current-byte parity after independent grading

The assurance grader correctly found that the documents had changed after the preceding recheck hashes. That was a real traceability gap, not a wording issue. After refreshing all `mental_model_review` pointers and recording the final PowerShell/FreeLens result, the complete suite was re-run against the exact final bytes:

- six of six Feynman validators passed, including Mermaid consumer rendering;
- eleven of eleven Mermaid diagrams rendered;
- all 27 Bash fences parsed in Bash and zsh;
- ShellCheck at warning-or-higher reported no finding;
- the preserved `verification/test-acc-structured-sample.sh` extracted the exact published function and passed guard, API-source, freshness, selector, backend, and Application-fleet wrong variants in Bash and zsh;
- every relative Markdown link target resolved;
- the tested secret-shaped patterns returned no match;
- all six canonical documents retained `review_status: complete`.

Final SHA-256 identities:

| Canonical document | SHA-256 |
|---|---|
| `argocd-openshift-command-probes.md` | `d478203a046ddb84b521aca200714c7dacc6da4d5af19b55e099f5091835bc72` |
| `argocd-replica-increase-acceptance-runbook.md` | `4fdbe20681f448fc031344a6b4b24cf09ea88305dee8e27783f2f8c6e4db451f` |
| `argocd_replica_increase_explained.md` | `73bfbfd26393639fd783e0b96103b70987dcb660d14bea1f851aeb6408e04026` |
| `maintenance-july-20-records-findings.md` | `662356ed7b00ff6601a5d9ce5867c321b96caec4ab93d2b53b241ff3ae1ff154` |
| `maintenance-july-22-records-findings.md` | `5eec2110407796cb4023c54cf85b5ad849724820dbfa5a97230d860cfdc8ccdd` |
| `probes-explanation.md` | `69868df1bda60972ef85ea7dedc21e136e85edfb5da74764a4ab876b69ea1aa6` |

The package is therefore complete at document/source/local-fixture scope, with DEV Freelens behaviorally connected. It is deliberately **not ACC `monitor-ready`**: the AVD execution of the ACC context wrapper and ACC authentication/current-context export require human-owned activation. Wednesday intent, T0, convergence, Redis functional quorum, end-user behavior, and genuine new-SRE comprehension are future evidence, not missing documentation claims.
