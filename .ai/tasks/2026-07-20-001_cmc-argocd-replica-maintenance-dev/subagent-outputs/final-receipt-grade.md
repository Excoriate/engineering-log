---
task_id: 2026-07-20-001
agent: apollo-assurance-marshal
timestamp: 2026-07-20T12:47:42+02:00
status: complete
verdict: CONDITIONALLY_ASSURED

summary: |
  The six-document package is PASS at document/source-transfer scope and PARTIAL for the full assurance chain. All 73 named disposition rows are present, and the second rechecks use discriminating wrong-implementation fixtures rather than happy-path-only checks. Current frontmatter and the final Freelens Unauthorized record preserve the live-proof ceiling. Promotion to an unqualified final package is blocked because five canonical files changed after the recheck-2 hash snapshot, so the current bytes are not covered by the recorded final validator/fixture suite; real AVD/Wednesday and human-reader activation remain explicitly future evidence.

evidence_summary:
  total_claims: 11
  verified: 9
  open_risk: 2
  contradicted: 0
  absent: 0

top_risks:
  - claim: C-010
    risk_level: MEDIUM
    description: Five of six canonical hashes differ from the final recheck-2 snapshot after post-review edits.
  - claim: C-011
    risk_level: MEDIUM
    description: Genuine new-human transfer and live AVD/Wednesday behavior remain external evidence.

sections:
  - id: traceability-matrix
    lines: 57-71
    relevance: high
  - id: residual-risk-register
    lines: 118-128
    relevance: high
  - id: environmental-assumptions
    lines: 130-138
    relevance: medium
---

# Final independent assurance receipt

## Verdict

**PARTIAL / CONDITIONALLY_ASSURED.** The user-facing documentation is publication-ready at the **document/source-transfer** tier. It is not yet an unqualified, byte-current assurance package because the canonical corpus changed after the final recheck-2 hash snapshot. The allowed future residuals are correctly bounded: neither authenticated AVD monitoring nor Wednesday ACC maintenance is claimed complete.

This verdict attacks the claims and ask-to-deliverable fit. It does not treat receipt existence as proof.

## Original user-goal corpus

- “what we have at the moment (the current ArgoCD replicas and their current configuration)”
- “Imagine that there is a new SRE joiner who needs to do this job and does not have any context”
- “With your learnings from my feedback and the proof you ran for the Dev Environment, you have to create a runbook because another maintenance is going to happen for the acceptance environment”
- “Create a new document called argocd_replica_increase_explained.md ... a self-contained, dense, complete, and comprehensive syllabus that explains what maintenance is and how ArgoCD works from first principles”
- “You can finish the dev live watch, maintenance is over; focus on the points about documentation, and the ACC readiness for this Wednesday”
- “don't forget to improve the documents as feyman's style”
- “Leave the configuration of lens until the end”
- “Most likely it is not related, but I want to discard it and provide the root cause of the issue concisely ... As soon as you are certain ... get back to ... finishing the documentation.”

## Traceability matrix

| Claim | Exact outcome assessed | Evidence chain and sufficiency gate | Epistemic result |
|---|---|---|---|
| C-001 | Dated replicas/configuration are available without calling historical state “current.” | Requirements `:36`; three-snapshot card and ban on unqualified current state in `argocd_replica_increase_explained.md:26-34`; DEV baseline/final topology in `maintenance-july-20-records-findings.md:78-124,203-224`; ACC preparation/expiry in `maintenance-july-22-records-findings.md:53-80,182-204`. Type DETERMINISTIC document inspection; depth FULL; environment SOURCE. | **VERIFIED** for document truth and temporal bounding. Underlying live captures are outside this receipt and remain **EXTERNAL_UNVERIFIED** here. |
| C-002 | A zero-context SRE gets one route and a coherent mental model. | All six top panels route syllabus → ACC runbook → ACC ledger; syllabus defines maintenance/CMC, snapshots, two loops, success ladder, components, Kubernetes, Redis HA, sync/health, time, false greens, worked diagnosis, and tests (`argocd_replica_increase_explained.md:14-146,148-653`). Fresh-reader recheck 2 passes at source/agent-transfer tier and discloses predecessor exposure at `:180-192`. Type REVIEW plus closed-book agent transfer; depth FULL; environment SOURCE. | **VERIFIED** at document/agent-transfer tier; genuine human comprehension is C-011. |
| C-003 | ACC has a safe, read-only Wednesday runbook derived from DEV. | Runbook immutable target/hard stops `:23-68`, context binding `:83-130`, intent/T0 `:132-214`, fail-closed structured function `:217-334`, invariants `:405-485`, stabilization/closure `:487-517`, proof ceiling `:582-587`. Operational recheck 2 injects guard/source/freshness failures and selector/backend/Application wrong variants at `:37-146`. Type DETERMINISTIC local fixture; depth FULL for named failure classes; environment LOCAL, with AVD residual. | **VERIFIED** for document/local-fixture behavior. Live AVD and installed `oc` remain explicitly unverified. |
| C-004 | Exact comprehensive Feynman-style syllabus exists. | Exact file exists and was read in full; its connected topology, mechanism sequence, analogies, diagrams, worked example, self-test, sources, and epistemic debt appear at `argocd_replica_increase_explained.md:1-653`. Fresh-reader recheck 2 passes source/document transfer. | **VERIFIED** for source/document completeness; current post-edit validator parity is C-010. |
| C-005 | DEV live watch is closed with a bounded result. | DEV ledger records the user completion signal and closes the watch `maintenance-july-20-records-findings.md:70-76,203-224,382-391`; no authoritative actor-intent or end-user claim is promoted. | **VERIFIED** for the durable record and bounded closure statement; the original live UI/runtime event is **EXTERNAL_UNVERIFIED** in this audit corpus. |
| C-006 | Existing documents were improved in Feynman style. | Each canonical document contains a knowledge contract, concept/mechanism bridge, decision logic, false-green discriminator, self-test, and evidence ceiling. Recheck-2 receipts report all six validators and Mermaid gates passing. | **VERIFIED** for observed current structure; re-execution against current hashes is C-010. |
| C-007 | Lens/Freelens was left until the end and not promoted after Unauthorized. | `probes-explanation.md:24-32` explicitly defers Lens until CLI proof and records discovery plus `/version: Unauthorized`; `maintenance-july-20-records-findings.md:353-363,382-391` classifies discovery as configuration-only, authenticated access as blocked, and requires human login refresh plus same-time CLI parity. | **VERIFIED** for current-document proof ceiling. The UI observation itself is **EXTERNAL_UNVERIFIED** here. |
| C-008 | The post-maintenance degradation received a concise root cause without false replica attribution. | F-014 traces missing variables → empty tag → Helm `latest` fallback → missing manifest → `ImagePullBackOff`, retains healthy Argo control-plane evidence, and says no observed replica mechanism (`maintenance-july-20-records-findings.md:333-351`); the syllabus preserves the same bounded causal language `:483-503`; ACC transfer is explicitly repository/pipeline evidence, not ACC runtime (`maintenance-july-22-records-findings.md:127-131`). | **VERIFIED** for causal wording, scope, and transfer. Raw ADO/cluster artifacts were not part of this audit and remain **EXTERNAL_UNVERIFIED**. |
| C-009 | Every raised finding has Accept/Rebut/Defer plus a real change or bounded residual. | `verification/adversarial-disposition.md` contains 73 named rows: 8 goal-fidelity, 14 SRE, 15 runbook, 10 learning/architecture, 7 completed fresh-reader, 7 completed goal-fidelity, 3 operational, and 9 first-recheck findings. All are `Accept` variants; no named finding is omitted. Second rechecks close the changed-content findings or preserve explicit AVD/human residuals. | **VERIFIED**. No missing disposition found. |
| C-010 | Final recheck evidence applies to the current canonical bytes. | Operational recheck 2 recorded six hashes at `final-operational-recheck2.md:127-146`. Current hashing matched only `argocd-openshift-command-probes.md`; the other five hashes differ, and their mtimes are later than all recheck-2 receipts. Current inspection shows intended frontmatter updates plus final Lens material, but no preserved pre-edit snapshot was found to prove those are the only deltas. | **OPEN_RISK**. Current-corpus validator/negative-control parity is not proved by the older hashes. |
| C-011 | A genuine new SRE and the real AVD/Wednesday environment succeed. | Fresh-reader receipt admits same-agent predecessor exposure; runbook and ACC ledger explicitly require human paste/isolated kubeconfig and Wednesday T0/live evidence. No document claims these outcomes complete. | **OPEN_RISK**, correctly bounded and allowed for documentation publication. |

## Disposition audit

**No missing named disposition found.** The chain does not use bare “looks good” approvals:

- Accepted shell-safety findings changed the published top-level block into `acc_structured_sample()` and captured each API source before parsing.
- Accepted serving findings changed wide output into Service-selector evaluation, selected Ready-Pod UID sets, ready EndpointSlice UID sets, and explicit `MATCH`/`MISMATCH`.
- Accepted fleet findings changed a screenful into total/distribution/exception/freshness aggregation that fails closed.
- Accepted temporal/current-state findings timestamped DEV-before, DEV-after, and ACC-preparation separately and removed locally invented closure minima.
- Accepted attribution findings changed universal or causal language to “evidenced cause” plus “no observed mechanism.”
- Accepted publication findings changed frontmatter to documentation-complete while leaving runbook activation blocked and ACC maintenance not started.
- Residual dispositions are bounded with named promotion evidence: AVD human paste/isolated kubeconfig, Wednesday T0/intent/live results, Redis data-plane evidence, end-user transactions, and genuine new-human grading.

There are no `Rebut` or `Defer` rows to audit. `Accept residual` is used only where the document behavior changed to fail closed or preserve a proof ceiling; it is not used as a silent waiver.

## Recheck-2 discrimination grade

**PASS.** The recheck-2 evidence distinguishes plausible wrong implementations:

| Plausible wrong implementation | Discriminating observation |
|---|---|
| top-level `return` after failed guard continues and exits zero | exact function returns nonzero and makes zero API calls in Bash and zsh |
| failed `oc` source is masked by successful `jq` | each injected Service/Pod/EndpointSlice/Application source failure exits nonzero with a named error |
| stale green Application lacks `reconciledAt` | missing freshness exits nonzero before aggregation |
| Ready but nonmatching Pod is counted for a Service | selector fixture excludes `other-ready/uid-x` |
| one backend missing or unready still looks green | selected and endpoint UID sets emit `MISMATCH`; exact equality emits `MATCH` |
| a hidden Degraded Application disappears in a green screenful | aggregation emits total, distributions, exception, and freshness rows |
| architecture still routes Git through the repo Service | closed/open-book redraw requires controller → repo Service → repo server → Git fetch, with rendered manifests returned |
| a separate evidenced root cause becomes a universal negative | final text says only “No observed mechanism connected it to the replica increase” |

This proof is strong for the named local failure classes. It does not prove installed ACC schemas, RBAC, `jq`/`oc` versions, AVD paste fidelity, or Wednesday data.

## Post-review frontmatter and Lens grade

**PASS for proof-ceiling semantics; PARTIAL for traceability parity.** Current frontmatter says:

- runbook: `preparation-ready-context-wrapper-avd-proof-blocked`, `review_status: complete`;
- syllabus: `complete-source-and-structural-review`, `review_status: complete`, reprobe at ACC Wednesday T0;
- ACC ledger: `preparation-baseline-captured-maintenance-not-started`, `review_status: complete`;
- DEV ledger: `completed-stable-across-observed-proof-layers`, not universal success;
- DEV command guide: completed DEV proof, reference-only for ACC.

Those are honest and do not promote AVD or Wednesday behavior. The Lens record is also honest: configuration discovery is separated from authenticated access, `/version: Unauthorized` is preserved, and the promotion path is human login refresh plus CLI parity.

The traceability weakness is that five canonical files changed after the recheck-2 hashes. Three files with `mental_model_review` still point to the earlier three-document fresh-reader artifact, while the broader six-document approval lives in `final-fresh-reader-recheck2.md`. This is not an operational overclaim, but a future auditor cannot derive current-byte approval from frontmatter alone.

## Residual risk register

| Claim | Residual | Severity | Probability | Risk | Promotion evidence |
|---|---|---|---|---|---|
| C-010 | Current corpus differs from the final recheck-2 snapshot. A post-review edit could preserve good wording while invalidating syntax, links, renderability, or negative controls. | Critical | Remote | **MEDIUM** | Re-run the current-corpus six-document validator/render/link/secret/shell/static gates and the exact R-01/R-02 wrong fixtures; publish new hashes, or produce a byte diff proving only reviewed frontmatter/Lens additions. |
| C-011a | Real AVD context wrapper/structured function is not activated. Wrong-cluster or corrupted-paste evidence could still occur under time pressure. | Critical | Occasional | **MEDIUM** | Human paste or isolated kubeconfig in the real AVD: bind ACC API/context/namespace/CR UID, run a safe wrong-context negative control, then preserve nonempty structured output and exit statuses. |
| C-011b | Wednesday intent, T0, convergence, Redis quorum, freshness, late stability, and end-user outcome are future. | Critical | Occasional | **MEDIUM** | Signed CMC intent plus timestamped Wednesday ledger evidence through the runbook's declared gates. |
| C-011c | Same-agent rechecks do not prove genuine new-human comprehension. | Marginal | Occasional | **MEDIUM** | A new SRE independently routes from any file, redraws the system, explains `Synced Degraded`, and executes a poisoned scenario without coaching. |
| Delivery gate | `manifest.gate_witnesses` was empty when inspected and `final-receipt-grade.md` remained pending. | Marginal | Probable until coordinator closure | **MEDIUM** | Coordinator verifies this file, registers it as the external-agent witness, clears the pending dispatch, and updates `verification/results.md` / `adversarial-disposition.md` from receipt-grade-pending without altering proof ceilings. |

No UNACCEPTABLE residual was found. The live/future residuals are allowed because the canonical documents explicitly deny completion at those tiers.

## Environmental assumptions

| Assumption | Evidence | Status/effect |
|---|---|---|
| Recheck-2 fixtures used the exact then-published function. | Operational recheck 2 states exact extraction and records prior hashes. | **VERIFIED for the old snapshot**; downgraded for current bytes by C-010. |
| Current post-recheck edits are only frontmatter and Lens additions. | File mtimes and current content are consistent with that hypothesis, but no old snapshot/diff was available. | **EXTERNAL_UNVERIFIED**; cannot support parity. |
| The DEV/ACC/ADO live evidence summarized in the canonical ledgers is authentic. | Durable source records and independent receipts cite it; raw runtime artifacts were outside the mandated audit corpus. | **EXTERNAL_UNVERIFIED** for this assessor; document wording remains bounded. |
| The real Wednesday shell has compatible Bash/zsh, `oc`, `jq`, schemas, and RBAC. | Local fixtures and static checks only. | **OPEN_RISK** until AVD activation. |

## Assurance self-questioning

1. **Is evidence proving the claim or merely present?** The strongest evidence proves exact local failure classes, not installed ACC behavior. The verdict is therefore document/source-transfer, not monitor-ready.
2. **Necessary but insufficient evidence?** Passing validators and fixtures are necessary for a safe runbook but insufficient without current-byte parity, AVD activation, signed intent, and fresh Wednesday data.
3. **Coverage versus assurance?** Feynman/Mermaid/shell green results do not prove human comprehension, cluster identity, service success, or end-user transactions.
4. **Strongest skeptical challenge?** The final receipts can all be internally correct while applying to stale bytes. The hash mismatch establishes that this is a real, not hypothetical, assurance gap.

## Final promotion decision

**Documentation outcome: PASS at current source inspection. Overall assurance chain: PARTIAL / CONDITIONALLY_ASSURED.**

The coordinator may publish the documents as documentation-complete with the existing AVD/Wednesday ceilings. It should not close the assurance task as fully verified until C-010 is resolved and this receipt is registered in the manifest. `monitor-ready`, Wednesday-success, Redis-quorum, end-user-success, and genuine-human-transfer claims remain prohibited until their named external evidence exists.
