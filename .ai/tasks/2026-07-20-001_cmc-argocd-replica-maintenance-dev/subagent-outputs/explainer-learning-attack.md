---
task_id: 2026-07-20-001
agent: principal-engineer-document-writer
timestamp: 2026-07-20T11:07:49+02:00
status: complete
summary: |
  The planned syllabus has enough observed evidence to teach the maintenance, but its present source shape cannot yet produce a zero-context mental model. The dominant defects are two conflated reconciliation loops, three incompatible meanings of current state, and visuals that repeat one linear chain instead of exposing distinct boundaries and clocks. This review defines twelve closed-book reader tests, a two-minute learning spine, five non-decorative visual jobs, contradiction controls, and a destructive attack ledger. The verdict is NO-GO for a readiness claim until the blocking repairs and a fresh-frame redraw/transfer review pass.
key_findings:
  - finding_1: Separate the OpenShift GitOps operator loop from the Argo CD Application reconciliation loop.
  - finding_2: Present DEV-before, DEV-after, and ACC-baseline as timestamped snapshots rather than one ambiguous current state.
  - finding_3: Replace repeated chain diagrams with complementary topology, sequence, service-routing, Redis-HA, and stabilization views.
---

# Destructive learning and architecture review

## Verdict

**NO-GO for calling `argocd_replica_increase_explained.md` complete from the present design.** The evidence is sufficient to draft, but the learning route is not yet safe for a zero-context SRE. A reader can memorize component names and still fail the maintenance because the source material does not force them to distinguish:

1. the OpenShift GitOps operator reconciling an `ArgoCD` custom resource into the Argo CD control plane;
2. the Argo CD application controller reconciling an `Application` from Git into application workloads;
3. declared replicas, realized pods, serving backends, application outcome, and stability over time.

The first two distinctions are the causal skeleton. Treating them as glossary entries produces vocabulary without transfer. The Feynman contract requires observable abilities such as draw, trace, predict, diagnose, and defend, not a claim that the reader “understands” the nouns ([CONFIRMED: `how-to-feynman/SKILL.md:62`, `:169-172`, `:588-593`]).

### Blocking release conditions

The document can move to independent review only after all six conditions hold:

1. The opening contains the two-minute learning spine below.
2. Every state claim is pinned to one of three timestamped snapshots: DEV before, DEV after, or ACC preparation baseline.
3. The architecture separates the two reconciliation loops and the local kubeconfig trust boundary.
4. The visual set covers five distinct cognitive jobs; no Mermaid merely redraws an ASCII chain.
5. The twelve novel-reader tests below are answer-hidden first and reconstructive rather than trivia.
6. A fresh reviewer, given only the finished document, redraws both loops, diagnoses at least two unseen failures, and names where evidence stops. `review_status: complete` is forbidden before that receipt ([CONFIRMED: `how-to-feynman/SKILL.md:485-502`]).

## Evidence key and proof ceiling

| Alias | Source | What it proves |
|---|---|---|
| `SKILL` | `/Users/alextorresruiz/.agents/skills/how-to-feynman/SKILL.md` | Explanation and visual acceptance contract. |
| `REQ` | `.ai/tasks/2026-07-20-001_cmc-argocd-replica-maintenance-dev/01-task-requirements-final.md` | User-facing acceptance criteria and operating boundary. |
| `SPEC` | `.ai/tasks/2026-07-20-001_cmc-argocd-replica-maintenance-dev/specs/01-spec.md` | Planned ownership and content for the syllabus. |
| `START` | `log/employer/eneco/02_on_call_shift/2026_july/2026_07_20_001_cmc_argocd_replica_increase_maintenance_dev_acc/probes-explanation.md` | DEV preparation baseline and current introductory teaching surface. |
| `DEV` | `log/employer/eneco/02_on_call_shift/2026_july/2026_07_20_001_cmc_argocd_replica_increase_maintenance_dev_acc/maintenance-july-20-records-findings.md` | DEV before/after observations and stabilization evidence. |
| `ACC` | `log/employer/eneco/02_on_call_shift/2026_july/2026_07_20_001_cmc_argocd_replica_increase_maintenance_dev_acc/maintenance-july-22-records-findings.md` | ACC preparation snapshot and future-maintenance boundary. |

The installed topology and observed transitions are **CONFIRMED** only to the cited capture windows. Redis/Sentinel/HAProxy internals, the reason a given component uses a Deployment or StatefulSet, and generic Kubernetes routing behavior still require authoritative documentation in the final evidence ledger. They are design requirements here, not promoted facts.

## What must fit in the first two minutes

The opening must fit on roughly one screen plus two small visuals. It must answer the reader’s first operational questions in this order:

| Order | Required content | Why it must be early | Rejection condition |
|---:|---|---|---|
| 1 | One sentence: maintenance changes the desired Argo CD control-plane topology; success means the operator realizes it, Kubernetes makes it serving, applications avoid sustained regression, and the result remains stable for the declared observation window. | Defines the job before exposing product nouns. | “Increase replicas” is presented as equivalent to “change one number.” |
| 2 | Snapshot ribbon: **DEV before** `1/1/1/1/1`; **DEV observed after** controller `1`, server `3`, repo `2`, Redis HAProxy `3` plus Redis server `3`, Dex `1`; **ACC preparation** all active components effectively `1`, HA off. Include capture dates and proof ceilings. | Eliminates the word “current,” which presently names incompatible states. | Any count appears without environment and timestamp. |
| 3 | Two-loop picture: `ArgoCD CR → OpenShift GitOps operator → Argo CD components` beside `Git → Application → Argo CD application-controller → application workloads`. | Prevents the most damaging namespace/category error. | `Application`, `ArgoCD`, operator, and application controller share one unlabeled arrow chain. |
| 4 | Success ladder: intent → workload status → Ready pods → EndpointSlice membership → component function → application outcome → stable interval. | Gives the reader the proof order used throughout the maintenance. | Ready pod count is allowed to terminate the proof. |
| 5 | Identity stop rule: terminal title is not environment identity; verify the API before accepting each capture block. | A wrong-cluster green result is more dangerous than a command error. | DEV/ACC is inferred from a tab name. |
| 6 | One red box: **`solver` is an Argo CD `Application`, not an Argo CD control-plane component.** | Prevents application health from being mistaken for replica state. | The reader cannot sort `solver`, repo server, and application controller into two sets. |

Only after that orientation should the document teach component roles, Kubernetes primitives, Redis HA, resource mathematics, rollout status, temporal stabilization, false-green cases, evidence, and the complete self-test.

## Required non-decorative visual architecture

Do not build one mural. Use five complementary views plus one redrawable ASCII memory aid. The skill requires each visual to do a distinct cognitive job and rejects a diagram that merely repeats prose or another diagram ([CONFIRMED: `SKILL:114-116`, `:332-356`, `:646-647`]).

| Visual | Cognitive job | Required boxes, edges, and boundaries | Misunderstanding it must kill |
|---|---|---|---|
| V1 — environment and ownership topology | Show where the actors and systems live. | Human/CMC boundary; AVD/Ubuntu client; shared kubeconfig; DEV and ACC API boundaries; `eneco-vpp-argocd`; Git source; OpenShift GitOps operator; Argo CD control plane; application namespaces. Split if the node count exceeds readability. | “A terminal tab, namespace, and cluster are interchangeable boundaries.” |
| V2 — two reconciliation loops over time | Show who observes which desired state and who writes which objects. | Loop A: `ArgoCD` CR → operator watch → Deployment/StatefulSet/Service. Loop B: Git → `Application` → repo server/application controller → application resources/status. Add periodic/eventual repetition arrows. | “The operator deploys Git applications” or “Argo CD reconciles its own CR.” |
| V3 — workload-to-serving path | Show why a Running pod is not yet a serving replica. | Deployment/StatefulSet → Pod → readiness condition → Service selector → EndpointSlice backend → client/component traffic. Label the readiness gate. | “Service exists, therefore all new replicas receive traffic.” |
| V4 — Redis HA topology | Show topology replacement rather than a count increase. | Three HAProxy pods; three stable Redis pods; Sentinel sidecar/process in each observed `2/2` pod; leader/follower roles; Sentinel observation/election path; HAProxy routing update; component clients. Mark unverified implementation details until sourced. | “Standalone Redis `1→3` is the whole change.” |
| V5 — stabilization state machine | Show clocks and reversibility. | Baseline/T0 → intent detected → workloads converging → Ready/serving → application observation → stable interval → close; branches for Pending, restarts/OOM, missing EndpointSlice backends, `Progressing`, wrong cluster, and recovery. | “One green snapshot proves completion.” |
| ASCII memory aid | Make the proof chain redrawable from memory. | `identity → intent → realized → serving → outcome → time`; under each word, the one best evidence surface. | “More probes are better even when they do not advance the proof layer.” |

Every visual needs an introduction, a prose walk-through, one takeaway, the misconception it prevents, and an explicit angle shift from the previous visual. A legendless box-and-arrow inventory fails even if Mermaid renders.

## Twelve novel-reader destruction tests

Each test is closed-book. Put the prompt before the answer. A pass requires reconstruction and prediction, not repeating a definition.

### T1 — What is this maintenance actually changing?

- **Prompt:** “CMC says ‘replicas increased.’ Draw the path from that statement to an operationally complete verdict. Name two points where the change can stop while the first object still looks correct.”
- **Pass:** The reader starts with a desired control-plane configuration, then crosses operator reconciliation, workload status, pod scheduling/readiness, serving membership, application outcome, and time.
- **Attack result:** **PARTIAL.** `START` has a useful chain, but it starts from “CMC changes a replica setting” and can be memorized without distinguishing the two controllers (`START:99-132`).
- **Required repair:** Open with the one-sentence maintenance definition and V2. Add a transfer self-test where the CR changes but the workload does not, and another where pods are Ready but EndpointSlice membership is missing.

### T2 — Git desired state versus Argo CD control-plane desired state

- **Prompt:** “A Git commit changes `solver` to three replicas, while CMC changes the `ArgoCD` CR server count to three. Which controller observes each change, and which Kubernetes objects should move?”
- **Pass:** The reader produces two separate loops and does not route both changes through the OpenShift GitOps operator.
- **Attack result:** **FAIL.** Git appears mainly in the `Synced` definition and `solver` explanation (`START:52`; `DEV:228-237`); the sources do not yet teach the two desired-state domains together.
- **Required repair:** Add V2 and a plain analogy: two thermostats govern different rooms; sharing the word “desired” does not merge their sensors or actuators. Add an answer-hidden sorting exercise for six objects: Git commit, `Application`, `ArgoCD` CR, operator, application controller, Deployment.

### T3 — Argo CD `Application` versus Argo CD component

- **Prompt:** “Sort `solver`, server, repo server, Redis, Dex, and application controller into ‘managed application’ or ‘Argo CD control plane.’ Which status columns apply to each?”
- **Pass:** `solver` is an `Application`; the other names are control-plane components. The reader does not treat `solver: Progressing` as a control-plane replica count.
- **Attack result:** **PARTIAL.** The distinction is explained correctly but late in the DEV findings (`DEV:228-237`, `:287-294`), not in the opening mental model.
- **Required repair:** Put the red two-column sorter in the first two minutes. Add a near-case question using a different application name so the reader must classify by object kind, not memorize `solver`.

### T4 — `ArgoCD` CR, operator, and reconciliation

- **Prompt:** “The `ArgoCD` CR says server replicas `3`; the server Deployment still says desired `1`. Who is behind, what evidence distinguishes delay from rejection, and what must not yet be called success?”
- **Pass:** The reader identifies the operator reconciliation boundary, checks CR/operator/workload status and events, and refuses to promote intent to realized state.
- **Attack result:** **PARTIAL.** The concept bridge states CR → operator → workloads (`START:43-44`, `:80`), but it does not force a temporal loop or distinguish operator reconciliation from Argo CD application reconciliation.
- **Required repair:** Explain reconciliation as repeated observe–compare–act, not one provisioning event. Use V2 and add the divergent-CR scenario to the self-test.

### T5 — Deployment versus StatefulSet

- **Prompt:** “Why can three HAProxy pods be replaceable while three Redis pods need stable identity? What changes during replacement, and what evidence would show ordered/stable identity?”
- **Pass:** The reader explains interchangeability versus stable identity/order, then maps the observed server/repo/HAProxy to Deployments and controller/Redis server to StatefulSets without claiming the generic mechanism proves the installed design rationale.
- **Attack result:** **PARTIAL.** The introductory glossary names the types (`START:45-46`), and live evidence proves Redis became a StatefulSet topology (`DEV:251-257`), but no transfer test forces the reader to predict replacement behavior.
- **Required repair:** Add a comparison table: identity, naming, storage/network identity, rollout behavior, observed local example, and proof command. Use a “numbered seats versus any free seat” analogy and state its boundary: it explains identity, not HA by itself.

### T6 — Pod, Service, and EndpointSlice

- **Prompt:** “The server Deployment is `3/3`, all pods are Running, and the Service exists, but only two ready backends appear in EndpointSlice. Is the replica increase serving? Draw the missing edge.”
- **Pass:** The reader separates object existence, readiness, selection, backend publication, and traffic usefulness.
- **Attack result:** **FAIL.** Endpoint membership was observed and legacy Endpoints was deprecated (`DEV:109`, `:299-304`), but the present teaching chain compresses Service and backend publication into ‘component becomes useful’ (`START:112-118`, `:131`).
- **Required repair:** Add V3, explain selector and readiness gating in prose, and add the exact `3 pods / 2 EndpointSlice backends` false-green self-test.

### T7 — Redis, Sentinel, and HAProxy

- **Prompt:** “One Redis process disappears. Which layer detects the failure, which layer chooses or discovers the writable member, which layer gives clients a stable target, and which three observations prove recovery?”
- **Pass:** The reader assigns detection/election, data role, and client routing to distinct boxes and can name proof for each. If installed wiring is not sourced, the reader labels the unverified edge instead of inventing it.
- **Attack result:** **FAIL for mechanism, PASS for observed topology.** DEV proves three HAProxy pods, a three-member Redis StatefulSet, and `2/2` Redis/Sentinel pods (`DEV:251-257`); it does not yet prove the exact failover/routing behavior.
- **Required repair:** Add V4, source the installed/operator HA design from authoritative documentation, and include a failure walk-through. The answer must state what evidence is observed, what is generic mechanism, and what remains unverified locally.

### T8 — Requests, limits, measured use, and scheduling

- **Prompt:** “Node CPU is 20%, a new controller pod requests `4Gi`, and the pod remains Pending with `FailedScheduling`. Why does low CPU not prove capacity, and which values must be compared?”
- **Pass:** The reader distinguishes reservation from runtime use and limits; checks eligible-node allocatable/request fit and constraints; treats `top` as sampled consumption rather than scheduler truth.
- **Attack result:** **PARTIAL BUT STRONG.** `START` separates reservation, ceiling, and measured use and forbids multiplying a point sample (`START:136-155`); `ACC` immediately warns that measured use alone does not prove scheduling safety (`ACC:94-104`).
- **Required repair:** Add one worked scheduling equation using symbolic allocatable/request values, not an invented Eneco threshold. Change “substantial measured headroom” (`ACC:104`) to “low observed utilization at capture time” so the prose cannot be read as schedulable headroom. Keep the Pending transfer test answer-hidden.

### T9 — `Synced`, `Healthy`, and `Progressing`

- **Prompt:** “Give one valid system state for each: `Synced + Progressing`, `OutOfSync + Healthy`, and `Synced + Degraded`. Which axis is Git drift and which is runtime health?”
- **Pass:** The reader treats sync and health as independent axes and refuses to infer CMC causation from one row.
- **Attack result:** **PARTIAL BUT STRONG.** The DEV record explains why `Synced Progressing` is not contradictory and preserves the observed recovery sequence (`DEV:228-248`, `:287-296`); ACC repeats the definitions (`ACC:108-114`).
- **Required repair:** Add a 2×3 status matrix with one concrete example per cell and one explicit boundary: Argo CD health is not an end-user transaction test. Add a near-case where an application stays `Synced Healthy` while a control-plane pod restarts.

### T10 — Desired, current, updated, ready, and available

- **Prompt:** “Desired `3`, current `3`, updated `3`, ready `2`, available `2`, one Pending. State exactly what succeeded, what failed, and the next two discriminating probes.”
- **Pass:** The reader does not collapse creation, revision, readiness, availability, or scheduling; stable node CPU does not alter the Pending diagnosis.
- **Attack result:** **PARTIAL BUT STRONG.** The current self-test covers this false green (`START:188-194`), and the final requirements demand all five replica states (`REQ:38`, `:53`). The prose does not yet teach field differences by Deployment versus StatefulSet.
- **Required repair:** Add a transition table per workload kind and a small timeline from spec change to available backend. Retain the scenario but hide the answer behind a clear divider/details block in rendered output.

### T11 — Temporal stabilization

- **Prompt:** “All replicas and endpoints are green at 10:35; a controller CPU spike peaks at 10:39; `solver` recovers at 10:40; the last stable application sample is 10:48. At what point may the observer close, and which part is policy versus observed evidence?”
- **Pass:** The reader distinguishes first convergence, recovery, stable interval, user completion signal, and contractual versus observer-default clocks.
- **Attack result:** **PARTIAL.** The DEV record defines two fresh resource samples plus five stable minutes as an observer default (`DEV:72`) and preserves the recovery sequence (`DEV:105-120`, `:205-220`). The mental model lacks a state/clock visual.
- **Required repair:** Add V5. Use two clocks: workload/controller conditions and the operator’s observation window. Mark the five-minute rule as local observer default, never an Eneco/CMC contract.

### T12 — Kubeconfig trust boundary

- **Prompt:** “A tab titled DEV returns healthy `1/1` objects after another tab logged into ACC. What exact evidence invalidates or accepts the sample, and what state was shared?”
- **Pass:** The reader rejects the whole block until `oc whoami --show-server` matches the intended API; they identify shared kubeconfig/context state rather than trusting presentation labels.
- **Attack result:** **PARTIAL BUT OPERATIONALLY PROVEN.** The wrong-cluster event occurred and was rejected (`DEV:121`, `:321-328`); the final requirements make the identity guard mandatory (`REQ:32`). The current architecture does not show this as a trust boundary.
- **Required repair:** Put the identity stop rule in the first two minutes and show the V1 client/kubeconfig/API boundary. Add a self-test where namespace and object names are identical across clusters so content shape cannot rescue the reader.

## Contradictions and duplication risks across the document set

| ID | Attack | Evidence | Required resolution |
|---|---|---|---|
| C1 — “current DEV” has two incompatible meanings | `START` says the maintenance target is unconfirmed and each active component is effectively one, while `DEV` later records completed server `3`, repo `2`, Redis HAProxy `3`, Redis server `3`, controller `1`, Dex `1`. | [CONFIRMED: `START:16`, `:69-80`, `:201`; `DEV:66-67`, `:205-212`] | Rename the old material “DEV preparation snapshot.” In the syllabus, use explicit `DEV before` and `DEV observed after` cards with capture times. Never write unqualified “current DEV.” |
| C2 — ACC “current” is a dated preparation state | ACC is captured July 20, maintenance not started, and explicitly does not prove Wednesday’s future state. | [CONFIRMED: `ACC:60`, `:68-78`, `:146`, `:168`] | Call it “ACC preparation baseline captured July 20.” Add a T0 refresh placeholder; do not present it as live Wednesday truth. |
| C3 — Redis is both standalone and HA across valid snapshots | DEV-before and ACC preparation show standalone Redis; DEV-after shows HAProxy plus Redis/Sentinel StatefulSet. | [CONFIRMED: `START:72`; `ACC:75`; `DEV:251-257`] | Use a before→after topology transition, not one component inventory. This is the maintenance’s best concrete teaching example. |
| C4 — visual coverage claims every angle while drawing one angle twice | `START` says the Mermaid expands the ASCII path, then declares no excluded angles although the coverage note lists only the ASCII path and one flowchart. | [CONFIRMED: `START:99-121`, `:208-210`; skill distinct-angle rule `SKILL:349-356`] | Do not reuse that pair as the syllabus’s visual plan. Derive V1–V5 separately and list each angle/job. |
| C5 — “measured headroom” risks masquerading as scheduler headroom | ACC calls the snapshot “substantial measured headroom” and then correctly states `top` proves only measured use, not request fit or eligible placement. | [CONFIRMED: `ACC:94-104`] | Use “low observed utilization at capture time.” Reserve “schedulable headroom” for allocatable-minus-requests on eligible nodes with constraints considered. |
| C6 — generic rationale can be misreported as local fact | `START` says the controller is StatefulSet because identity/sharding “can matter.” The observed workload kind is proven; the exact installed design rationale is not established by the supplied runtime evidence. | [CONFIRMED observation, INFER rationale: `START:45-46`, `:69`] | Separate “what StatefulSet guarantees generally,” “what this cluster uses,” and “why this installation chose it—unverified unless sourced.” Apply the same rule to Redis HA routing. |
| C7 — self-contained can become copy-and-drift | `SPEC` assigns current facts to baseline/findings, commands to the runbook, and the 360-degree model to the syllabus. | [CONFIRMED: `SPEC:90-100`] | The syllabus should copy only compact, timestamped snapshot cards and causal evidence needed to learn. It should link to the runbook for commands and findings for full ledgers. Duplicated numbers must carry source/capture IDs. |
| C8 — `Application`/`ArgoCD` capitalization is a hidden API boundary | The sources correctly distinguish `solver` from components, but both object kinds are described under the product name Argo CD. | [CONFIRMED: `DEV:228-237`; `ACC:108-114`] | On first use, render exact kind names in monospace: `Application` and `ArgoCD`. Add a “do not confuse” table with owner, desired source, reconciler, children, and status surface. |

## Attempted-attack ledger

| Attack | Claim attacked | Attempt | Result | Consequence |
|---|---|---|---|---|
| A1 | “The existing chain is a sufficient smallest mental model.” | Asked whether it predicts a Git application change and an `ArgoCD` CR change without merging controllers. | **Destroyed.** It does not expose both loops. | V2 and T2 are blocking. |
| A2 | “Current-state facts can be copied into the syllabus.” | Compared `START`, final DEV, and ACC preparation counts. | **Destroyed.** All are valid snapshots but incompatible as one current state. | Snapshot ribbon and time-qualified prose are blocking. |
| A3 | “ASCII plus Mermaid satisfies architecture.” | Compared cognitive jobs rather than syntax. | **Destroyed.** The Mermaid explicitly expands the same ASCII chain. | Replace with V1–V5 complementary jobs. |
| A4 | “The glossary closes prerequisite gaps.” | Applied unseen scenarios requiring prediction across boundaries. | **Destroyed.** Definitions do not prove routing, failover, or temporal reasoning. | Twelve transfer tests required. |
| A5 | “The resource explanation is unsafe.” | Tested low CPU plus unschedulable `4Gi` request. | **Partially survived.** Reservation/limit/use are separated, but “measured headroom” remains misleading. | Keep mechanism; sharpen language and add scheduling math. |
| A6 | “Sync and health are conflated.” | Tested `Synced Progressing` and pre-existing `OutOfSync Healthy`. | **Survived with residual.** The DEV record explains the axes correctly. | Promote the mechanism earlier and add a status matrix. |
| A7 | “The evidence over-attributes CMC.” | Looked for actor-intent claims stronger than the captures. | **Survived.** The DEV record consistently limits topology changes to CMC-correlated. | Preserve the evidence ceiling in the syllabus. |
| A8 | “Redis HA is merely a count change.” | Counted workload types, pods, containers, and routing layers. | **Destroyed.** Six pods plus Sentinel/HAProxy change topology and failure modes. | V4 and T7 are blocking; exact internals need sources. |
| A9 | “Ready replicas prove service.” | Introduced missing EndpointSlice backends with green pods. | **Destroyed.** Current teaching compresses this edge. | V3 and T6 are blocking. |
| A10 | “One green snapshot is enough.” | Replayed the controller CPU peak and `solver` progression after first convergence. | **Destroyed.** Later evidence changes the verdict. | V5 and T11 are blocking. |
| A11 | “A labeled terminal protects environment identity.” | Replayed the observed shared-kubeconfig switch. | **Destroyed by live evidence.** | V1 and T12 belong in the first two minutes. |
| A12 | “Fresh-reader review can be a syntax check.” | Applied redraw, causal reconstruction, and unseen-case transfer criteria. | **Destroyed.** Rendering and anatomy cannot prove capability transfer. | Final review prompt must exercise both loops and failure scenarios. |

## Fresh-reader receipt contract

Give the completed document alone to a reviewer who has not seen these sources. Require the reviewer to:

1. redraw V1–V5 from memory with labels hidden;
2. explain the two reconciliation loops without using “Argo CD handles it” as a causal placeholder;
3. solve T2, T6, T7, T10, and T12 before seeing answers;
4. point to the first sentence or visual where they became uncertain;
5. classify each snapshot as observed, inferred, or pending refresh;
6. name one misleading shortcut they can now reject and the mechanism that makes it fail.

Passing syntax, link, Mermaid, and Feynman-anatomy validators is only structural proof. The readiness claim remains `awaiting-independent-challenge` until this behavioral receipt exists.

## Documentation forcing gate

| Factor | Score | Evidence |
|---|---|---|
| Audience clarity | EXPLICIT | Zero-context/new SRE who must perform and interpret this maintenance (`REQ:12`, `:36-46`). |
| Evidence sufficiency | PARTIAL | Installed snapshots and transitions are strong; Redis failover/routing and some generic design rationale still need authoritative sources. |
| Structure validity | PROGRESSIVE after required repairs | Two-minute spine → primitives → dual loops → runtime paths → failure/time → transfer. Current source order is not yet sufficient. |
| Compression level | DENSE | Twelve tests collapse the completeness question into observable reader behavior; five visuals are bounded by distinct cognitive jobs. |

## Epistemic debt

- **CONFIRMED:** 19 load-bearing evidence claims in this review derive from the supplied skill, requirements, specification, and captured DEV/ACC records.
- **INFER:** 2 design judgments remain intentionally labeled—the installed reason for StatefulSet choices and the exact Redis HA routing/failover mechanism.
- **UNVERIFIED:** authoritative mechanics sources for Redis/Sentinel/HAProxy and the future ACC T0/post-change state.
- **Highest-risk unresolved decision points:** exact CMC ACC intent; installed Redis HA behavior; whether the final fresh reader can reconstruct both loops without oral context.

## Maintainer two years out

The missing future constraint is **snapshot expiry semantics**. Without a visible `captured_at`, `environment`, and `valid_until/reprobe_at` contract on every topology card, a later maintainer can preserve perfectly written but operationally false “current” replica counts. The syllabus should make time part of the data model, not a footnote.
