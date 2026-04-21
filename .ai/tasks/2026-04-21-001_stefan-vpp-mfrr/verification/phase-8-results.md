---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Phase 8 verification results — falsifier pass/fail, belief changes, adversarial integration, retrospective
---

# Phase 8 — Verification Results

## Falsifier outcomes (from plan.md §Plan steps)

| Falsifier | Stage | Evidence | Verdict |
|---|---|---|---|
| F4 — Pod log class discriminates H1/H2/H3 | B1 | `kubectl -n vpp logs activationmfrr-744ddb586c-9rwnd --tail=300` returned `Azure.RequestFailedException: ContainerNotFound` inside `BlobCheckpointStoreInternal.ListOwnershipAsync` | **PASS but with inversion** — the error is NOT the `ResourceNotFound` on EH (H1 as reporter stated); it's `ContainerNotFound` on Blob Storage. Reporter's diagnosis required refinement (H1b = missing checkpoint container; CG is also missing by transitive necessity). Discrimination worked — just the winning hypothesis is a variant of H1, not H2 or H3-vanilla. |
| F1 — Event Hub consumer group state | C1 | `az eventhubs eventhub consumer-group list --namespace-name vpp-evh-sbx --eventhub-name iot-telemetry` returned only `$Default`, `fleetoptimizer` | **PASS** — no activation-named CG exists. |
| F2 — Service's expected CG name | C2 | Deployment yaml has no static CG env var; config comes from Azure App Configuration | **PARTIAL** — confirmed config source (App Config), but did NOT capture the byte-exact CG name value. Adversary §6 flagged this as the highest-impact gap. Step 1a added to runbook to close. |
| F3 — Pipeline buildId=1616964 outcome | D1 | `az devops` CLI not configured in session | **FAIL[BLOCKED]** — operator must check in ADO UI. Default: assume S4.B (PR needed) until proven S4.A. |
| F5 — Blast radius Sandbox-only | E1 | FBE namespaces on AKS healthy; MC envs not probed | **PARTIAL** — within-AKS Sandbox confirmed isolated; MC unverified (different auth path, not in this session's scope). |
| F6 — No related prior production impact | E2 | Rootly not queried in this session (out of coordinator scope) | **PARTIAL** — operator must run Rootly check as part of Step 5. |

**Summary**: 2 full PASS, 3 PARTIAL (all with named unblocking probes), 1 BLOCKED. No FAIL that invalidates the diagnosis. The residual PARTIALs are appropriately represented as UNVERIFIED in the outcome, not hidden.

## Belief changes (Phase 7 → Phase 8)

1. **Reporter's diagnosis (H1)** → refined to **H1b**: the missing entity is the blob *container*, not the EH *consumer group entity*. Stefan saw "consumerGroup" in the stack trace parameter list and concluded CG was missing; he was directionally correct but the immediate fix must address both the container AND the CG (the container blocks first).

2. **"Stuck rollout, not outage" framing** → **falsified by adversarial re-probe**: the R145 "healthy" pod is `Running 1/1` but NOT publishing activation responses — it's been logging `4/4 brokers are down` against Eneco ESP Kafka brokers (`dtaaz.esp.eneco.com:9094`) every 5 min since 11:12 UTC today. K8s liveness/readiness probes at `/liveness` and `/readiness` test only process aliveness, not upstream broker connectivity. Sandbox mFRR activation is degraded end-to-end regardless of which pod is up. Severity reclassified from P4-DX to **P3-Sandbox-degradation** (still not prd).

3. **"R147 introduces new config"** was partially correct, but **env vars are IDENTICAL** between R145 and R147 (`diff` returned empty). So the behavior change lives entirely in the image code path — not in the K8s manifest or env-var injection.

4. **`savppdspbootstrapsb` as the R147 checkpoint SA**: was A1 FACT in Phase 7, **downgraded to A2 INFER** per adversary §3. The SA name pattern ("dsp" = dispatching, recent provisioning) is suggestive but not proven. Step 1a closes this via App Config read.

5. **"App Config drives config"**: downgraded from A1 to A2 INFER per adversary §3. Absence of env vars proves only absence, not the alternative mechanism.

## Adversarial review integration

`verification/socrates-contrarian-review.md` produced a verdict of "survives scrutiny with three caveats". All three caveats were **accepted and integrated**:

| Caveat | Response | Evidence |
|---|---|---|
| (1) Read R147 App Config values before writing the PR | **Accepted**. New Step 1a added to runbook, explicitly highest-impact probe. | `outcome/diagnosis.md` §Step 1a |
| (2) Downgrade claims #5, #2, #6 from A1 FACT to A2 INFER | **Accepted**. Evidence table row #5 and #6 updated with mixed A1/A2 classification; row #6b/6c added reflecting env-var diff and R145 Kafka-broker facts. Headline confidence split 90% on mechanism / 75% on fix. | `outcome/diagnosis.md` §Evidence + §Bottom line |
| (3) Probe R145 pod log positively before accepting "serving healthy" framing | **Accepted and SURFACED A BIGGER FINDING**. `kubectl -n vpp logs activationmfrr-6778566c5f-...` revealed `4/4 brokers are down` Kafka failures — separate concern but it changes the severity framing. | `outcome/diagnosis.md` §Bottom line framing update + §Residual risk |

Further adversary alternative hypotheses addressed:
- **Alt-H-A** (App Config itself is malformed): now explicitly a branch in Step 1a. If Step 1a reveals malformed config, route to Core team for App Config correction — NOT a Terraform PR.
- **Alt-H-B** (`savppdspbootstrapsb` not the target SA): closed by Step 1a reading the exact SA URI from App Config.
- **Alt-H-C** (exit 139 = native crash / OOMKilled): not yet probed; `kubectl describe pod | grep OOMKilled` added as an optional Step 1a-bis. Low probability but non-zero; exit 139 is unusual for managed .NET SDK failures.
- **Step 5 forcing function**: noted in diagnosis — Step 5 (MC env probes + Rootly) is now gated before ticket-close per adversary §2 point 6.

## Domain-fit retrospective ("what was I most wrong about")

- **Most wrong in Phase 1**: framing reporter's diagnosis as a single hypothesis to confirm. A more discriminating initial move would have been treating the ticket text ("missing consumer group") as a symptom description, not a cause claim, and demanding a log-line probe BEFORE accepting the reporter's mechanism. I held this in Phase 3 but the initial pre-flight was too accommodating.
- **Most wrong in Phase 7**: not immediately reading the R145 pod's log after finding it `Running 1/1`. "Running" is a necessary but not sufficient condition for "functioning" — the adversary caught this. I'd internalized the K8s-health-probe-semantics limitation elsewhere but not applied it here.
- **Most wrong in Phase 7 (#2)**: over-confidence in the SA identification. `savppdspbootstrapsb` created <24h before the ticket is suggestive, but I should have sought positive confirmation via App Config, not treated the temporal proximity as causal proof.
- **Not wrong (credit)**: capturing the pod log with `grep -iE "EventHubs|..."` filter caught the `ContainerNotFound` class immediately — the reporter's diagnosis inversion was surfaced within the first discriminating probe. That's what the probe was for; it worked.

## Memory-worthy lessons (for `2ndbrain-memory-consolidate`)

1. **Reporter self-diagnoses in Slack Lists intake are INFER, not FACT** — even when they sound precise. The SDK's parameter naming (`consumerGroup` in the `ListOwnershipAsync` signature) confused Stefan's reading of his own stack trace into "missing consumer group" when the actual exception class was `ContainerNotFound` on blob storage.
2. **Kubernetes `Running 1/1, 0 restarts` does NOT imply functional** — always positive-signal-probe (log for expected activity class) before accepting "healthy pod" framing in outage triage. Liveness/readiness probes are proxy health, not semantic health.
3. **"SDK convention" is not "SDK guarantee"** — Azure EventHubs SDK's BlobCheckpointStore accepts arbitrary container names. The pattern of naming the container after the CG is convention at the service/team level, not an SDK contract. IaC PRs must use the exact string the service reads from config.
4. **When a Terraform PR's target names come from dynamic config (App Config, KV), read those values before authoring the PR** — do not rely on naming convention guesses. This is the single highest-impact probe for this class of ticket.
5. **Sandbox on Azure AKS vs dev-mc/acc/prd on OpenShift (MC)** — topology asymmetry at Eneco means kubectl in one context, `oc` + MC auth in the other. Runbooks that conflate the two will silently fail.
6. **ArgoCD helm OCI sync + Azure App Configuration + KV CSI** is a three-layer dynamic config stack for VPP workloads — understanding the layering is prerequisite to diagnosing "why does the new image fail with the same env vars" situations.

## Gate-out

Plan.md's final deliverables:
- `outcome/diagnosis.md` — complete, includes adversarial revisions
- `outcome/slack-reply-draft.md` — drafted, not posted
- `verification/enrich-results.md` — complete
- `verification/socrates-contrarian-review.md` — complete (independent reviewer)
- `verification/phase-8-results.md` — this file
- `verification/activation-checklist.md` — to be written
- `.ai/runtime/second-brain/consolidation-attestation.json` — to be written at NN-6

Authority barriers honored (NN-4 safety kernel):
- Zero writes to Azure, K8s, ArgoCD, Git, ADO.
- Zero Slack posts.
- Zero secrets captured (only key names, never values).
- Zero severity claim beyond what probe evidence justifies (upgraded P4→P3 based on FACT about Kafka brokers, not speculation).
