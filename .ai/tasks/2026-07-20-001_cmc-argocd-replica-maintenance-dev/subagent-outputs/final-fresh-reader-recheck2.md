---
task_id: 2026-07-20-001
agent: architect-kernel-fresh-reader-recheck2
status: complete
summary: |
  PASS at source/document-transfer tier. R1-R4, F1-F7, architecture fidelity,
  Synced-Degraded transfer, source/count alignment, and all six structural
  validators passed. Human-reader and live AVD/Wednesday activation remain
  explicitly outside this receipt.
---

# Final fresh-reader recheck 2

## BRAIN SCAN

- **Decision target:** can a context-free new SRE learn the actual DEV shape, causal mechanisms, evidence ceilings, and Wednesday ACC handoff without inventing context?
- **Dangerous assumption:** the four targeted wording/diagram repairs may be locally correct while disagreeing with counts, source records, or the operational runbook.
- **Opposite-conclusion prediction:** if the repair is only cosmetic, the reader will still route Git through the repo Service, treat Dex as an unexplained orphan, infer that green CI validates nested shell work, or claim the replica increase is universally excluded as a cause.
- **Discriminating falsifier:** the syllabus must support an unaided redraw with exact arrow directions and a bounded `Synced Degraded` explanation; companion records must then independently support every observed count, failure-chain step, and uncertainty boundary.
- **Failure path:** source-accurate prose can still be unsafe if the Wednesday entry route points to historical DEV commands or if AVD-unproven wrappers are presented as activated.
- **Frame:** fresh-reader architecture and action-transfer verification. The downstream actor is a new Wednesday ACC SRE; wrong identity, boundary, or causality yields false closure or CMC misattribution.
- **Isolation limit:** this pass withheld the five companion documents until after the closed-book record, but this same agent reviewed predecessor revisions. It is a fresh-source recheck, not a genuine zero-prior-knowledge human test.

## Closed-book syllabus transfer

Recorded after reading only `argocd_replica_increase_explained.md`.

### Redraw from memory

```text
Authorized CMC party -> ArgoCD/eneco-vpp CR -> GitOps operator
  -> server Deployment x3 behind server Service/EndpointSlice
  -> repo-server Deployment x2 behind repo Service/EndpointSlice
  -> application-controller StatefulSet x1
  -> Dex Deployment x1
  -> Redis HAProxy Deployment x3
  -> Redis/Sentinel StatefulSet x3

Application flow:
controller -> repo Service -> repo-server -> Git clone/fetch
repo-server -> rendered manifests -> controller
controller -> managed application resources -> sync/health feedback

Identity flow:
UI/CLI -> server Service -> server
server -- documented generic SSO delegation --> Dex
Dex -- documented generic identity protocol --> external identity provider

Cache flow:
server/controller -> Redis Service -> HAProxy -> Redis/Sentinel members
```

The diagram distinguishes observed Kubernetes shape/counts from documented-generic SSO/identity behavior and from unverified Redis quorum/role routing.

### Maintenance and Wednesday model

A maintenance is an authorized, time-bounded desired-state change with a declared before-state, intended result, evidence window, and recovery owner. The proof ladder is:

```text
verified API identity -> authoritative intent -> revised workload
-> Ready Pod -> published EndpointSlice backend -> fresh application outcome
-> stability through the declared window -> explicit closure/handoff
```

The package route is learn in the syllabus → execute read-only from the ACC runbook → write Wednesday evidence to the ACC ledger. DEV probes and the July 20 ledger are historical references, not Wednesday truth.

### `Synced Degraded` transfer

The worked case remains reconstructable:

```text
missing release variable -> unresolved shell substitution becomes empty
-> image.tag "" committed -> Helm falls back to appVersion latest
-> Argo CD synchronizes valid desired Deployment
-> registry lacks latest -> new Pods ImagePullBackOff
-> live matches desired (Synced) but desired rollout cannot start (Degraded)
```

Old `0.158.0` ReplicaSets remaining Ready prove preserved capacity at capture time, not end-user success. The evidenced failed-rollout cause is the fail-open generator; the document now says only that no **observed** mechanism connected it to the replica increase. Green CI proves the configured jobs' final result was accepted, not that every nested shell action succeeded or the generated configuration was valid.

### Closed-book R1–R4 verdict

| Prior finding | Verdict | Observation |
|---|---|---|
| R1 repo/Git/Service direction | **PASS** | controller requests through repo Service; repo-server clones/fetches Git; rendered manifests return to controller |
| R2 green-pipeline rule | **PASS** | rule is limited to the CI engine accepting configured final job results and explicitly rejects nested-action/config-validity inference |
| R3 universal negative causation | **PASS** | the generator is named as evidenced cause; only absence of an observed replica mechanism is claimed |
| R4 Dex orphan | **PASS** | Dex has explicitly dotted/documented-generic SSO and external-identity edges |

### Closed-book F1–F7 and transfer verdict

- **F1 CMC definition: PASS** — local role is defined; unavailable expansion is not invented.
- **F2 acronym bridges: PASS** — HPA is expanded with the resource kind; UI, CLI, RBAC, OOM, SSO, UID, and etcd are explained at first material use.
- **F3 controller CPU causality: PASS** — maintenance reconciliation remains a hypothesis; independent application reconciliation survives.
- **F4 unified DEV topology: PASS** — counts, workload kinds, namespace, Services, external actors, and proof-ceiling distinctions are in one map.
- **F5 Git/reconciliation arrows: PASS** — fetch agency and internal repo-Service request path are exact.
- **F6 maintenance primitive: PASS** — authorization, time, baseline, intent, observation, and recovery ownership precede specialization.
- **F7 navigation/entry route: PASS** — start route and course map are explicit.
- **Architecture/action transfer: PASS from syllabus alone** — the two loops, environment trust boundary, serving path, Redis roles, stabilization states, and unseen diagnosis cases can be solved without companion files.

## Open-book source and package recheck

After freezing the closed-book answers above, I read all five companion documents in full and compared them with the syllabus. The canonical route is consistent in all six documents: learn from the syllabus, execute Wednesday from the ACC runbook, and append Wednesday evidence to the ACC ledger. The DEV command guide and July 20 ledger remain historical/reference surfaces, not live ACC authority (`argocd_replica_increase_explained.md:14`; `argocd-replica-increase-acceptance-runbook.md:13`; `maintenance-july-22-records-findings.md:11`; `argocd-openshift-command-probes.md:13`; `probes-explanation.md:11`).

### R1-R4 source verdict

| Requirement | Verdict | Discriminating source check |
|---|---|---|
| **R1 — repo/controller/Git arrows** | **PASS** | The controller requests rendered manifests through the repo Service, the repo server performs `clone / fetch` against Git, and the repo server returns rendered manifests to the controller (`argocd_replica_increase_explained.md:71-73`). This rejects the prior wrong model in which the Service or controller performs the Git fetch. |
| **R2 — green-pipeline configured final result** | **PASS** | The rule now says a green pipeline proves only that the CI engine accepted the configured jobs' final result and explicitly does not prove nested shell success or generated-configuration validity (`argocd_replica_increase_explained.md:501`). The July 20 record independently supplies the plausibly-wrong case: unresolved shell substitutions logged `command not found`, wrote an empty tag, and were still committed by a successful build (`maintenance-july-20-records-findings.md:344-347`). |
| **R3 — bounded causation** | **PASS** | The syllabus names the fail-open generator as the evidenced failed-rollout cause, then limits the negative claim to “No observed mechanism connected it to the replica increase” (`argocd_replica_increase_explained.md:501`). The source record uses the same bounded conclusion and preserves unverified recovery/end-user evidence (`maintenance-july-20-records-findings.md:346-347`). It does not claim that a causal connection is universally impossible. |
| **R4 — Dex generic SSO edge** | **PASS** | The diagram contains dotted, explicitly generic edges from server to Dex and Dex to the external identity provider (`argocd_replica_increase_explained.md:75-76`). The teaching text identifies Dex as single-sign-on integration while observed evidence is limited to one replica (`argocd_replica_increase_explained.md:315-317`). This is neither an orphan nor an installed-flow claim. |

### F1-F7 source verdict

| Requirement | Verdict | Source check |
|---|---|---|
| **F1 — CMC definition without invented expansion** | **PASS** | `CMC` is defined locally as the authorized maintenance party, while the absent acronym expansion is explicitly not invented (`argocd_replica_increase_explained.md:20`). |
| **F2 — acronym/concept bridges** | **PASS** | HPA is expanded and tied to `HorizontalPodAutoscaler` in the snapshot table (`argocd_replica_increase_explained.md:30-32`); UI/CLI/RBAC, OOM, etcd, SSO, and UID are expanded or explained at their material teaching surfaces (`argocd_replica_increase_explained.md:286,294,306,317,335`). |
| **F3 — controller CPU causal restraint** | **PASS** | The `24m -> 733m -> 109m` movement is taught as a maintenance-reconciliation hypothesis while independent application reconciliation remains live (`argocd_replica_increase_explained.md:300`; `maintenance-july-20-records-findings.md:269-274`). |
| **F4 — unified DEV architecture** | **PASS** | One connected map carries the CR/operator, observed workload kinds and counts, Services/EndpointSlices, Git, clients, applications, external identity, and Redis path (`argocd_replica_increase_explained.md:36-82`). Observed topology, documented-generic mechanism, and unverified quorum are distinguished (`argocd_replica_increase_explained.md:38,86`). |
| **F5 — exact Git/reconciliation agency** | **PASS** | The diagram and prose agree that repo-server fetches/renders while the controller requests and consumes rendered manifests (`argocd_replica_increase_explained.md:71-73,292-300`). |
| **F6 — maintenance primitive before specialization** | **PASS** | Authorization, starting state, intended result, observation window, and recovery owner are defined before component details (`argocd_replica_increase_explained.md:18-24`). |
| **F7 — entry route and navigation** | **PASS** | The first screen gives the exact syllabus -> ACC runbook -> ACC ledger route and quarantines historical DEV surfaces (`argocd_replica_increase_explained.md:12-14`). |

## Architecture fidelity and source/count alignment

**PASS.** The syllabus snapshot card's DEV after-state—controller `1`, server `3`, repo `2`, Redis HAProxy `3`, Redis/Sentinel `3`, Dex `1`—matches the July 20 live ledger (`argocd_replica_increase_explained.md:30-32`; `maintenance-july-20-records-findings.md:107,113,117,121`). The same ledger independently records the serving membership (`maintenance-july-20-records-findings.md:190`) and the controller CPU rise/recovery (`maintenance-july-20-records-findings.md:109,114,116,120`).

The ACC preparation card also matches the ACC record: controller, server, repo server, standalone Redis, and Dex were each effectively one, with HA disabled and no HPA (`argocd_replica_increase_explained.md:32`; `maintenance-july-22-records-findings.md:70-80`). Historical restart counts, observed-use samples, and incomplete Application-fleet coverage remain explicit rather than being collapsed into a green baseline (`maintenance-july-22-records-findings.md:82-112`).

The architecture keeps its evidence classes separate:

- observed installed shape and counts (`argocd_replica_increase_explained.md:38-82`);
- documented-generic SSO and identity edges (`argocd_replica_increase_explained.md:75-76`);
- explicitly unverified Redis/Sentinel quorum and live role routing (`argocd_replica_increase_explained.md:450-454,649`);
- documented mechanisms versus live cluster facts versus missing CMC/end-user proof (`argocd_replica_increase_explained.md:642-649`).

No source/count contradiction was found.

## `Synced Degraded` source-to-transfer check

**PASS.** The closed-book causal chain is isomorphic to the July 20 evidence:

1. both Applications were `Synced Degraded` (`maintenance-july-20-records-findings.md:337-338`);
2. the new ReplicaSets referenced missing `:latest` images and entered `ErrImagePull`/`ImagePullBackOff` (`maintenance-july-20-records-findings.md:339`);
3. the old `0.158.0` ReplicaSets retained `5/5` and `2/2` Ready Pods (`maintenance-july-20-records-findings.md:341-342`);
4. the shared revision/build had missing release variables, `command not found`, `image.tag: ""`, and Helm fallback to `latest` (`maintenance-july-20-records-findings.md:343-344`);
5. the Argo CD control plane remained healthy at the observed new counts (`maintenance-july-20-records-findings.md:345`);
6. the fail-open generator is the evidenced cause, while the replica relation is bounded to no observed mechanism and recovery tags/end-user behavior remain unverified (`maintenance-july-20-records-findings.md:346-347`).

The Wednesday transfer is operational rather than merely explanatory: both the syllabus and runbook require the ACC `marketinteraction` state to be captured at T0 and classified as pre-existing if already degraded, without attributing it to CMC absent a demonstrated alteration (`argocd_replica_increase_explained.md:503`; `argocd-replica-increase-acceptance-runbook.md:154-171`; `maintenance-july-22-records-findings.md:127-131`).

## Wednesday action-transfer and proof ceiling

**PASS at document/source-transfer tier.** A new operator is routed to the ACC cockpit, forced to bind evidence to the ACC API, obtain authoritative intent, capture fresh T0, compare revision/readiness/Pod UID/EndpointSlice/Application freshness, preserve failure observations, and close only after stability plus explicit intent/handoff. The runbook's decision code keeps `COMPLETE AS INTENDED` stronger than `STABLE AS OBSERVED` and still refuses to call Argo health an end-user transaction test (`argocd-replica-increase-acceptance-runbook.md:34-68,134-152,479-485`).

The source package also preserves the exact activation limits:

- the pinned ACC wrapper is `STRUCTURALLY VERIFIED, AVD BEHAVIORAL PROOF BLOCKED`; human paste or isolated kubeconfig is still required (`argocd-replica-increase-acceptance-runbook.md:130`);
- structured Pod/EndpointSlice joins and Application aggregation are `STATICALLY VERIFIED, NOT YET RUN IN THE AVD` (`argocd-replica-increase-acceptance-runbook.md:334`);
- ACC July 20 evidence is not Wednesday truth, and CMC intent, Wednesday topology, metrics freshness, Redis quorum, controller freshness, late stability, and end-user transactions remain unproven (`argocd-replica-increase-acceptance-runbook.md:582-587`);
- the ACC ledger itself expires its preparation values at Wednesday T0 (`maintenance-july-22-records-findings.md:182-204`).

## Validator evidence

The canonical `how-to-feynman` validator was re-run against every canonical document after the source recheck:

| Document | Result |
|---|---|
| `argocd_replica_increase_explained.md` | **PASS** |
| `argocd-replica-increase-acceptance-runbook.md` | **PASS** |
| `maintenance-july-20-records-findings.md` | **PASS** |
| `maintenance-july-22-records-findings.md` | **PASS** |
| `argocd-openshift-command-probes.md` | **PASS** |
| `probes-explanation.md` | **PASS** |

All six runs reported `mermaid render skipped`. These are structural/document validators; they do not establish rendered-diagram usability or live operational activation.

# PASS

**Verdict:** PASS for R1-R4, F1-F7, architecture fidelity, `Synced Degraded` transfer, six-document navigation, source/count alignment, causal bounding, and source/document-level Wednesday action transfer.

**Highest honest proof tier:** source-verified plus closed-book agent transfer and structural validator PASS. This is **not** `BEHAVIORAL-ACTIVATED` for the AVD wrappers or Wednesday ACC procedure and is **not** `USER-GRADED` by a genuinely new human SRE.

## Residual limits that do not invalidate the document/source PASS

- This same agent saw predecessor revisions. Withholding the companion documents until after the syllabus test reduced source leakage but did not create a genuine zero-prior-knowledge human reader.
- Mermaid source structure passed, but rendering was skipped; this receipt does not prove visual legibility in the target renderer.
- The AVD context wrapper and structured parsers still need the already-named human-paste or isolated-kubeconfig activation path.
- Wednesday ACC intent/topology, Redis quorum/live role routing, controller reconciliation freshness, late stability, and end-user transactions remain future evidence; no wording in the package promotes them.
- Canonical `review_status` fields that still say `awaiting-independent-challenge` were not edited in this read-only recheck. The parent coordinator owns any status promotion after dispositioning this receipt.
