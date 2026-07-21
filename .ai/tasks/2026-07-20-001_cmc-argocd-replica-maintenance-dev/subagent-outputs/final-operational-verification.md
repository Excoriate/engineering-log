---
task_id: 2026-07-20-001
agent: verification-engineer
timestamp: 2026-07-20T11:37:32+02:00
status: complete
summary: |
  The supplied snapshot passes the Feynman, Mermaid-render, Bash/zsh parse, ShellCheck, and context-pinning probes. The documentation accurately refuses to promote the AVD-corrupted context wrapper to monitor-ready. Operational readiness remains PARTIAL: the shown EndpointSlice output cannot perform the required Pod-UID/readiness join, the Application command does not prove complete-fleet coverage, live cluster behavior was intentionally not re-executed, and snapshot-to-Dropbox byte parity is outside this verifier's accessible surface.
key_findings:
  - finding_1: EndpointSlice serving proof lacks a join-capable command and is a HIGH false-green risk.
  - finding_2: Application fleet completeness lacks a deterministic total/distribution command and is a MEDIUM false-green risk.
  - finding_3: Context pinning is structurally sound in Bash and zsh but remains behaviorally blocked in the AVD as documented.
---

# Final operational verification receipt

## Verdict

| Question | Verdict | Confidence | Proof tier |
|---|---|---:|---|
| Feynman/document anatomy | **PASS** | High | structural, fresh validator execution |
| Mermaid sources and rendering | **PASS** | High | structural/consumer-rendered |
| Bash/zsh syntax and static shell quality | **PASS** | High | structural/static |
| Wrong-context rejection and mid-block context pinning | **PASS (local stub)** | High for wrapper logic | behavioral simulation, not live `oc` |
| Exact `oc`/custom-column behavior in the installed ACC client | **PARTIAL** | Medium | static/schema-plausibility only; `oc` absent locally |
| Wednesday ACC monitor readiness | **PARTIAL / NO-GO for `monitor-ready` promotion** | High | live wrapper proof explicitly blocked; two proof commands remain incomplete |
| Snapshot parity with the four Dropbox originals | **UNVERIFIED[blocked]** | Low | verifier could not access Dropbox; hashes below identify the reviewed snapshot |

The documents are substantially safer than count-only monitoring: they separate identity, intent, revision-aware realization, serving, outcome, and time. They must not yet be promoted to fully monitor-ready. Required promotion work is limited and concrete: prove the wrapper in the real AVD/human-paste path, add a join-capable EndpointSlice probe, and add deterministic Application-fleet aggregation.

## Findings first

### OV-01 — EndpointSlice proof cannot execute its own UID/readiness invariant

- **Claim attacked:** the operator can detect “Ready Pods missing EndpointSlice backends” and compare Ready Pod UIDs with EndpointSlice `targetRef` UIDs/ready conditions.
- **Concrete falsifier:** construct the plausible state “three Ready Pods, only two ready Service backends.” The shown Pod table exposes Pod UID but not Pod IP; the shown EndpointSlice command uses `-o wide`, which exposes endpoint addresses but not a joinable `targetRef.uid`/`conditions.ready` table. The operator therefore cannot perform the documented UID join from the supplied commands.
- **Evidence:** runbook lines 176–190 capture Pod UIDs and only `get endpointslices ... -o wide`; lines 290–296 require the UID/ready-condition comparison; lines 380–381 make it load-bearing. ACC findings lines 120–126 and command-probes lines 263–269 repeat the wide-form command. Static inspection found no JSON/custom-column/jq EndpointSlice join command in the four targets.
- **Severity:** **HIGH / BLOCKING** for the serving-layer completion claim. This can look green at the workload layer while a new replica is not serving.
- **Required change:** add a read-only, context-pinned probe that emits EndpointSlice name, Service label, endpoint address, `conditions.ready`, `targetRef.name`, and `targetRef.uid`, plus Pod name/UID/IP/readiness. Define expected and false results and require set equality for applicable serving components. Then run that exact probe in ACC before promoting it beyond `NOT YET RUN`/structural proof.

### OV-02 — Application-fleet completeness is a prose control without a complete-fleet proof command

- **Claim attacked:** every sample records the total Application count, full sync/health distribution, exceptions, and freshness, so a partial terminal view cannot be called “all healthy.”
- **Concrete falsifier:** omit one off-screen `Degraded` Application while the visible rows remain `Synced Healthy`. The current custom-column command lists rows, but the runbook supplies no deterministic item count/distribution/exception aggregation and no check that the capture consumed the full result.
- **Evidence:** runbook lines 184–190 and 223–229 issue a custom-column list; lines 323–336 require total/distribution/completeness and freshness. ACC findings line 108 deliberately says “visible” inventory, and command-probes lines 249–251 already warn that a screenful is insufficient. No `-o json` + `jq`, JSONPath count, or equivalent complete-fleet aggregation exists in the four targets.
- **Severity:** **MEDIUM**, promoted to **HIGH** if Application health is used for final closure after controller recreation.
- **Required change:** add a context-pinned JSON aggregation that prints `.items | length`, sync/health grouped counts, every exception, and `reconciledAt`; record command exit, item count, capture time, and an explicit incomplete/permission failure path. Preserve `APPLICATION FLEET STATUS INCOMPLETE` when aggregation cannot run.

### OV-03 — Context pinning survives local falsification, but live promotion remains blocked

- **Claim attacked:** a mid-block shared-kubeconfig switch cannot redirect a pinned ACC sample, and a DEV context cannot bind as ACC.
- **Concrete falsifier:** stub `oc config current-context` as DEV during bind; expected rejection. Separately bind ACC, switch the active context to DEV, then execute through `acc_oc`; expected argv still starts with `--context acc-context`.
- **Evidence:** both `/bin/bash` 3.2.57 and `/bin/zsh` 5.9 produced `WRONG_CONTEXT_REJECTED`; after the switch both produced `MOCK_ACCEPT context=acc-context argv=<-n><eneco-vpp-argocd><get><pods>` and `MID_BLOCK_SWITCH_PINNED_TO_ACC`. Runbook line 128 and lines 438–439 accurately label the wrapper `STRUCTURALLY VERIFIED, AVD BEHAVIORAL PROOF BLOCKED`; ACC findings lines 128–132 explain the keyboard-corruption mechanism without blaming ACC/CMC.
- **Severity:** **BLOCKING RESIDUAL**, not a documentation defect. Local stubbing cannot prove the installed `oc`/AVD input path.
- **Required change:** before Wednesday monitoring, a human paste or isolated-kubeconfig execution must run `acc_bind`, `acc_guard`, one pinned resource command, and a wrong-context negative control in the real AVD. Record exit/stderr/API/context and only then change the proof state to `MONITOR-READY`.

## Named attack matrix

| Attack | Result | Discriminating evidence | Required change |
|---|---|---|---|
| Bash and zsh correctness | **PASS** | All 24 Bash fences parsed under Bash 3.2 and zsh 5.9; ShellCheck warning-or-higher count was zero. A deliberately vacuous zero-block harness was rejected and corrected. | None for syntax; live `oc` proof still required. |
| `oc` global `--context` placement | **PASS (simulated)** | Stub required `--context` as the first global flag and accepted `acc_oc` argv in both shells. | Prove with installed `oc` in AVD. |
| JSON/custom-column paths | **PASS (static), PARTIAL (consumer)** | Deployment, StatefulSet, Pod, and Application field paths are internally consistent and shell-quoted; no local `oc` binary existed to parse them. EndpointSlice join is the explicit exception in OV-01. | Run exact forms against ACC; add EndpointSlice structured output. |
| Wrong context / mid-block switch | **PASS (simulated)** | Wrong bind rejected; post-bind active-context switch did not change pinned argv. | OV-03 live proof. |
| Empty CMC intent | **PASS** | Hard stop and verdict split prevent `COMPLETE AS INTENDED` without authoritative component/count/topology (runbook lines 34–38, 63–66, 130–145). | None. |
| Desired=ready with generation/revision lag | **PASS** | `GEN/OBS`, updated/available/unavailable, and StatefulSet current/update revision are required; poisoned scenario rejects `RDY=3` alone (lines 161–171, 372–379, 414–425). | None. |
| Pod replacement resets restarts | **PASS** | UID, creation time, revision, predecessor preservation, and `REPLACED` state are explicit (lines 173–179, 377, 423–424). | None. |
| Cached Application state after controller recreation | **PASS, capability-bounded** | `reconciledAt` must advance or freshness becomes unverified (lines 323–336). | Add OV-02 aggregation; retain unverified if freshness signal is unavailable. |
| Partial Redis HA | **PASS, quorum-bounded** | HAProxy alone cannot pass; full CR/workload/Service/EndpointSlice/event topology is required and data-plane quorum is explicitly unverified without a read-only signal (lines 272–286, 381, 425). | None beyond OV-01 for backend join. |
| Ready Pods missing Service backends | **FAIL operational command sufficiency** | Correct invariant and decision exist, but no join-capable command; see OV-01. | OV-01. |
| Node averages vs per-node reservation | **PASS** | Actual destination node, allocatable/requested reservation, constraints, events, and measured use are separate panes; low `top` cannot override `FailedScheduling` (lines 299–321, 383, 428). | None; use `SCHEDULABLE HEADROOM UNVERIFIED` on permission failure. |
| Stale/missing Metrics API | **PASS** | Raw timestamp/window advancement and expected-Pod coverage are required; otherwise utilization becomes unknown (lines 240–260, 384). | None. |
| Incomplete Application fleet | **PARTIAL** | Exact fail-closed wording exists, but completeness has no deterministic command; see OV-02. | OV-02. |
| Late regression / first-green closure | **PASS** | Evidence floor is a maximum across serving, advancing metrics, freshness, interval, and late checkpoint/handoff (lines 340–369). | None. |
| Missing events | **PASS, retention-bounded** | Exact wording is “no events returned by this query at this timestamp”; retention/aggregation and disappearing warnings are explicit (lines 181–193). | None. |
| Exact proof-state language | **PASS with explicit ceiling** | Wrapper remains behaviorally blocked; July 20 ACC baseline is not Wednesday truth; CMC intent and future outcome remain future evidence (lines 128, 433–441; ACC findings 128–136, 165–171). | Do not edit status upward until OV-03 executes. |

## Executed evidence trail

1. **Feynman validator with real Mermaid rendering**
   - Command pattern: `python3 work/argocd-review-snapshot/verification/validate-feynman-doc.py --render-mermaid <doc>` for all six snapshot documents.
   - Exit: `0`.
   - Actual: six `PASS` lines; each included `note: mermaid render passed`.
2. **Mermaid inventory**
   - Assertion: document blocks = `.mmd` sources = non-empty `.svg` outputs.
   - Actual: `doc_blocks=10 mmd_sources=10 svg_outputs=10`; exit `0`.
3. **Shell fences**
   - Command: extract every fenced Bash block, pipe independently to `/bin/bash -n`, `/bin/zsh -n`, and `shellcheck --shell=bash --severity=warning -`.
   - Actual: `blocks=24 bash_fail=0 zsh_fail=0 shellcheck_fail=0`; exit `0`.
   - Negative control: the first harness matched zero blocks and was rejected as vacuous; the second deliberately failed on an incorrect expected count of 23; the final assertion required the independently inventoried count of 24.
4. **Context falsification**
   - Actual: wrong-context bind rejected in Bash and zsh; a post-bind active-context switch still emitted pinned ACC argv in both shells; exit `0`.
5. **Reviewed snapshot identity**
   - Runbook: `8131c12332452c40971d32262b261e2f7434e9e8a37b2c80b430a978355d9d6f`
   - ACC findings: `281526c64a85bc0bf98f572d6f3c0bfeb089d9fac5b94f3abcb0da9a6bc82e29`
   - DEV findings: `e51559963e641f5e438f154d91562d24549dad9333b744490a5d9a71e5a9e3a3`
   - Command probes: `c9b133439daf336262a7e2fb7fad671c67124feaeafe544e374c6408a7811d66`

No cluster command was executed. No user-facing document was edited.

## Counter-hypothesis and evidence ceiling

Alternative explanation for the two command gaps: an experienced operator could manually infer backend membership from addresses and manually count every Application row. That does not satisfy the documents' own fail-closed, zero-context-SRE contract: manual inference has no explicit join key, completeness assertion, or reproducible false result. The structured commands requested in OV-01 and OV-02 distinguish the alternatives.

This receipt proves the supplied snapshot's structure and local shell logic. It does **not** independently prove the live ACC facts, the real AVD keyboard path, the installed `oc` parser, Wednesday's future state, CMC intent, Redis data-plane quorum, end-user transactions, or byte identity between the snapshot and inaccessible Dropbox originals. Promotion path: patch OV-01/OV-02, execute OV-03 in the AVD, rerun this same static suite, and byte-compare the reviewed hashes with the four canonical files.

## Insight audit

The two-year maintainer risk is schema drift in manually written custom-column/JSON field paths across OpenShift/Argo CD upgrades. A future-safe runbook should keep one small, versioned fixture or dry-run contract that proves each extraction still yields non-empty join keys before a maintenance window; this was not established in the current snapshot.
