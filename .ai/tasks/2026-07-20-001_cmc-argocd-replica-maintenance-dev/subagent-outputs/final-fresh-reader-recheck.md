---
task_id: 2026-07-20-001
agent: architect-kernel-fresh-reader-recheck
status: complete
summary: |
  Verdict: PARTIAL. The repaired package now transfers the operating model, but
  one Git/repo-Service arrow and two claims in the new Synced-Degraded example
  still overstate mechanism.
---

# Final fresh-reader recheck

## BRAIN SCAN

- **Decision target:** determine whether the repaired six-document package transfers a correct, source-bounded mental model and a safe Wednesday ACC operating route to a new SRE with no local context.
- **Dangerous assumption:** fixing the seven named defects may make the file look complete while the new content introduces an inaccurate connection, a causal overclaim, or a broken execution handoff.
- **Opposite-conclusion prediction:** if the repairs are cosmetic, a reader will still be unable to redraw the concrete DEV system, distinguish Git/application reconciliation from CMC/operator reconciliation, or explain why `Synced Degraded` can coexist with a healthy Argo CD control plane.
- **Discriminating falsifier:** closed-book reconstruction must name the exact observed component shape, trust boundary, two loops, serving gate, Wednesday entry route, and unverified evidence; source-check must then show that every specific count and causal claim is supported by the package records.
- **Likely failure path:** a narrative can correctly show a missing image tag and `ImagePullBackOff` yet overclaim that this proves the replica increase played no causal role. The source must establish both the upstream failure chain and independent control-plane health.
- **Frame:** architecture/operation transfer. The downstream actor is the Wednesday ACC SRE; a wrong boundary produces wrong-cluster evidence, an incorrect closure verdict, or misattribution to CMC.
- **Isolation limit:** this pass read only the repaired syllabus before the closed-book record below, but the same agent previously reviewed its predecessor. This is a fresh-source recheck, not proof equivalent to a genuinely new human reader.

## Closed-book transfer record

Recorded after reading only `argocd_replica_increase_explained.md`; no companion document was consulted in this phase.

### What exists and why the change matters

Observed DEV after-state, from memory:

```text
Authorized maintenance party (CMC)
  -> ArgoCD/eneco-vpp custom resource
  -> OpenShift GitOps operator
  -> namespace eneco-vpp-argocd
       server Deployment x3 behind Service/EndpointSlice
       repo-server Deployment x2 behind Service/EndpointSlice
       application-controller StatefulSet x1
       Dex Deployment x1
       redis-ha-haproxy Deployment x3
       redis-ha-server StatefulSet x3, each Redis + Sentinel
```

The replica increase changes more than counts: scheduler reservations/placement, revision convergence, backend publication, cache routing/failure shape, and the time required to prove stability all change. A count is therefore intent/realization evidence, never the full outcome.

### Two loops and trust boundary

```text
Loop A: ArgoCD CR -> GitOps operator -> Argo CD workloads/Pods/Services
Loop B: Git + Application -> repo server -> application controller
        -> managed application resources -> sync/health status feedback

Trust boundary: shared kubeconfig -> pinned context -> returned DEV or ACC API
```

CMC changes loop A. `solver` and other `Application` objects live in loop B. The terminal tab title and identical namespace are not environment identity; the returned API is.

### Serving and closure model

```text
identity -> authorized intent -> revised workload -> Ready Pod
  -> selected/published EndpointSlice backend -> fresh application outcome
  -> declared observation window -> stable/handoff
```

Three Ready Pods with two ready EndpointSlice backends is incomplete serving. A Ready replacement controller with frozen `reconciledAt` does not prove fresh application reconciliation. A green sample or a completed observation window proves only what was observed in that interval, not indefinite future stability.

### Redis HA model

Clients reach a stable Redis Service, then interchangeable HAProxy replicas, then the current writable Redis role among stable StatefulSet ordinals. Redis stores cache data/roles; Sentinel observes and coordinates failover information; HAProxy routes clients. Kubernetes `3/3` shape does not prove Sentinel quorum, leader correctness, or failover routing.

### Wednesday ACC operating route

1. Learn the system in the explanation.
2. Open `argocd-replica-increase-acceptance-runbook.md` for the live procedure.
3. Establish fresh ACC API identity and T0 immediately before CMC acts.
4. Obtain authoritative CMC intent; do not assume ACC will repeat DEV.
5. Observe only: intent/generation, workload revision, Pods/restarts/events/resources, EndpointSlices, Application status/freshness, and stabilization.
6. Record Wednesday evidence in `maintenance-july-22-records-findings.md`.
7. Use the DEV ledger and command proof only as history/teaching, not as Wednesday current state.

### What remains unverified

- the expansion of `CMC` (the document safely defines its local role instead of inventing an acronym expansion);
- authoritative Wednesday ACC intent and post-state;
- live Redis/Sentinel quorum, current writable role, and exact routing;
- fresh metrics and eligible-node schedulable headroom;
- post-recreation controller reconciliation freshness;
- end-user transaction behavior and late failures after the declared window.

### Re-test of prior F1–F7 from the repaired syllabus alone

| Prior finding | Closed-book result | Evidence in repaired syllabus |
|---|---|---|
| F1 CMC definition | **PASS** | opening defines CMC as the authorized maintenance party and explicitly refuses to invent an unavailable expansion |
| F2 acronym bridges | **PASS with minor wording note** | HPA, UI, CLI, RBAC, OOM, SSO, UID, and etcd are expanded/explained at first material use; `HorizontalPodAutoscaler` would read more naturally as “Horizontal Pod Autoscaler” |
| F3 controller CPU causality | **PASS** | wording now calls maintenance reconciliation plausible and preserves independent application reconciliation as a surviving alternative |
| F4 unified observed DEV topology | **PASS** | one connected after-state diagram carries the namespace, observed counts, workload kinds, Services/EndpointSlices, and Redis proof ceiling |
| F5 Git/reconciliation arrows | **PASS** | Git arrows now terminate at per-environment Argo CD reconciliation and are labelled “read by repo server” |
| F6 maintenance primitive | **PASS** | opening defines authorization, time boundary, starting state, intended result, observation window, and recovery owner before specializing the change |
| F7 navigation/entry route | **PASS** | “Start here” names the package handoff and a compact course map provides return navigation |

### Closed-book attack on the new `Synced Degraded` example

The mechanism is clear: missing release variable → empty `image.tag` committed → Helm falls back to chart `appVersion: latest` → Argo CD synchronizes that declaration → Azure Container Registry (ACR) cannot resolve `latest` → new Pods enter `ImagePullBackOff`. This explains why pipeline green, Argo CD `Synced`, and runtime `Degraded` can coexist.

The example also avoids the obvious outage overclaim by stating that old `0.158.0` ReplicaSets stayed Ready, so the evidence shows a failed rollout rather than confirmed loss of the existing service. The potentially load-bearing sentence is “The root cause was therefore upstream configuration generation, not the replica increase.” It passes only if companion evidence independently proves the exact empty-tag/defaulting/image-pull chain and shows the Argo CD control plane remained healthy; source-check must attack that next.

## Source-check across the six-document package

### Package routing and role separation

The entry route is now consistent in all six files:

| File | Declared role | Exact evidence |
|---|---|---|
| `argocd_replica_increase_explained.md` | learn the system, then open the ACC runbook, then write the ACC ledger | lines 12–14 |
| `argocd-replica-increase-acceptance-runbook.md` | Wednesday read-only execution surface; no mutation authorization | lines 13–15 |
| `maintenance-july-22-records-findings.md` | append-only ACC T0/live/post-change record | lines 11–13 |
| `maintenance-july-20-records-findings.md` | closed DEV evidence ledger; never append ACC evidence | lines 11–13 |
| `argocd-openshift-command-probes.md` | DEV-pinned command proof and ACC reference only | lines 11–15 |
| `probes-explanation.md` | historical DEV teaching reference, not Wednesday instruction | lines 10–18 |

This closes the former package-entry ambiguity. Starting from any companion file directs the reader back to the same learn → execute → record route.

### Source alignment that survived

1. **Three temporal/environment snapshots — PASS.** The syllabus' DEV-before, DEV-after, and ACC-preparation rows (`argocd_replica_increase_explained.md:26–34`) match the DEV preparation/live ledger (`maintenance-july-20-records-findings.md:64–74, 76–91, 105–120`) and ACC topology (`maintenance-july-22-records-findings.md:55–78`). The stale-at-Wednesday boundary is preserved.
2. **Observed DEV topology counts — PASS.** Server `3`, repo `2`, controller `1`, Dex `1`, HAProxy `3`, and Redis/Sentinel StatefulSet `3` in the new diagram (`argocd_replica_increase_explained.md:48–58`) match the live DEV ledger (`maintenance-july-20-records-findings.md:105–120, 201–220, 251–261`). Redis quorum/routing remains explicitly unproven in the syllabus at lines 38 and 82.
3. **Controller CPU causality — PASS.** The repaired statement (`argocd_replica_increase_explained.md:292–298`) preserves both the maintenance-reconciliation hypothesis and independent application reconciliation. That matches the source's hypothesis/alternative/bounded-attribution structure (`maintenance-july-20-records-findings.md:263–273`).
4. **ACC safety and proof ceiling — PASS.** The runbook binds every sample to the ACC API and hard-stops on missing evidence (`argocd-replica-increase-acceptance-runbook.md:23–45, 83–130`). It accurately discloses that the context wrapper and structured joins/aggregations are structurally verified but not behaviorally executed through the AVD (`argocd-replica-increase-acceptance-runbook.md:130, 246, 494–499`; `maintenance-july-22-records-findings.md:145–149`).
5. **`Synced Degraded` observed chain — PASS at the case level.** The DEV ledger directly supports both Applications being `Synced Degraded`, `:latest`, `ErrImagePull`/`ImagePullBackOff`, missing registry manifests, old `0.158.0` ReplicaSets remaining Ready, shared Git revision, absent release variables, command-substitution errors, empty tags, Helm fallback, and a healthy Argo CD control plane (`maintenance-july-20-records-findings.md:333–351`). The ACC companion carefully limits its related finding to repository/pipeline risk rather than ACC runtime fact (`maintenance-july-22-records-findings.md:127–131`), and the runbook turns it into a T0 pre-existing-condition probe (`argocd-replica-increase-acceptance-runbook.md:154–171`).
6. **Mechanical anatomy — PASS with a render ceiling.** The named Feynman validator returned exit 0 for all six documents. Every result also said `mermaid render skipped`; this proves document anatomy, not rendered visual behavior.

## Adversarial findings after source-check

### R1 — Unified topology misroutes Git through the repo Service (BLOCKING architecture defect)

- **Location:** `argocd_replica_increase_explained.md:70–71`.
- **Current drawing:** `Git -> repo Service + EndpointSlice -> repo-server Deployment -> application controller`.
- **Why this is wrong:** the repo server clones/fetches Git (`argocd_replica_increase_explained.md:286–290`). The Kubernetes repo Service fronts the repo-server workload for internal Argo CD clients; Git does not connect into the cluster through that Service. The current arrow reverses the fetch agency and gives the Service the wrong boundary role.
- **Transfer impact:** a new SRE can redraw the counts correctly while learning an incorrect network/control flow—the exact architecture-fidelity failure the concrete diagram was meant to remove.
- **Concrete repair:** draw `application controller -> repo Service/EndpointSlice -> repo-server Deployment` as “request rendered manifests”; draw `repo-server Deployment -> Git` as “clone/fetch”; optionally return `repo server -> controller` as “rendered manifests.” If the server also uses the repo API in this installed version, add that as a documented generic edge, not an observed live-flow claim.
- **Prior-finding disposition:** F5 is **PARTIAL**, not PASS. The environment diagram's Git arrows are repaired at lines 223–224, but the new unified diagram reintroduces the mechanism error at line 70.

### R2 — “Green pipeline proves its steps exited successfully” contradicts the evidence (BLOCKING causal-clarity defect)

- **Location:** `argocd_replica_increase_explained.md:497`.
- **Why this is wrong:** the source explicitly says the generated Bash logged `command not found` for unresolved command substitutions but continued, committed, pushed, and left the overall pipeline green (`maintenance-july-20-records-findings.md:344–347`). Therefore a green pipeline did **not** prove every nested command or semantic step exited successfully.
- **Transfer impact:** the generalized rule erases the fail-open mechanism that made this case instructive. A new SRE may trust the CI color precisely where the example shows that configured error propagation was insufficient.
- **Concrete repair:** replace the first clause with: “A green pipeline proves only that the CI engine accepted the configured jobs' final result; it does not prove every nested shell action succeeded or that generated configuration is valid.” Keep the separate `Synced` and runtime-health clauses.

### R3 — Negative causation is stronger than the evidence ceiling (MAJOR wording defect)

- **Location:** `argocd_replica_increase_explained.md:497`: “The root cause was therefore upstream configuration generation, not the replica increase.”
- **What the evidence supports:** the fail-open generator chain is a sufficient, directly evidenced cause of the bad `:latest` rollout, and the Argo CD control plane remained healthy. The ledger's exact boundary is: “No observed mechanism connects the Argo CD replica increase to that pipeline revision or missing registry artifacts” (`maintenance-july-20-records-findings.md:346–349`).
- **Why the current wording is too strong:** direct evidence for one cause plus absence of an observed replica mechanism does not prove the universal negative that the replica increase had no contribution under any unobserved path.
- **Concrete repair:** write: “The evidenced cause of this failed rollout was the upstream fail-open configuration generator. No observed mechanism connected it to the replica increase; the Argo CD control plane remained healthy throughout the capture.” This preserves the strong diagnosis and the honest boundary.

### R4 — Dex is an orphan in the new connected architecture (MINOR completeness defect)

- **Location:** `argocd_replica_increase_explained.md:55, 66`; the box is created and operator-managed but has no functional connection.
- **Why it matters:** Part IV says the server delegates authentication and Dex integrates identity providers (`argocd_replica_increase_explained.md:280–313`). A diagram advertised as the connected after-state should either connect `server -> Dex -> external identity provider` with a documented-generic label or mark Dex's runtime edge intentionally omitted.
- **Concrete repair:** add a dotted/documented-generic `server -> Dex` edge labelled `SSO authentication delegation`, plus an external identity-provider boundary if space permits. This is not required to monitor replica convergence, so it does not independently block operational transfer.

## Re-test disposition for prior F1–F7

| Prior finding | Final recheck | Source-backed disposition |
|---|---|---|
| F1 CMC definition | **PASS** | local role is explicit at `argocd_replica_increase_explained.md:20`; unavailable expansion is honestly bounded |
| F2 acronym bridges | **PASS** | load-bearing acronyms are expanded at lines 30–32, 282–313, and 328–341; use “Horizontal Pod Autoscaler” rather than the resource kind spelling only as copy polish |
| F3 controller CPU causality | **PASS** | line 296 matches the source's hypothesis plus surviving alternative |
| F4 unified observed DEV topology | **PARTIAL** | concrete counts/kinds/boundary exist, but the Git/repo Service arrow is wrong and Dex is functionally orphaned |
| F5 Git/reconciliation arrows | **PARTIAL** | environment arrows at lines 223–224 pass; unified diagram line 70 fails mechanism fidelity |
| F6 maintenance primitive | **PASS** | line 20 gives a complete, appropriately bounded primitive before the specialization |
| F7 navigation/entry route | **PASS** | syllabus line 14, course map lines 130–142, and every companion's folder route agree |

## Structural readability versus behavioral transfer

### Structural readability: PASS

The package now has a unique entry route, role-specific documents, a compact course map, an early concrete topology, explained acronyms, distinct visual jobs, source/unknown separation, and an explicit operational proof ceiling. The six documents are long in aggregate but not indiscriminately repetitive: syllabus teaches, runbook acts, records preserve evidence, and DEV references prove historical commands/mechanisms.

### Behavioral transfer: PASS with architecture-correction required

The repaired syllabus supports closed-book reconstruction of the concrete shape, both loops, trust boundary, serving path, Redis HA roles, closure states, Wednesday procedure, and evidence ceiling. It also makes the new delivery failure explainable as `Synced` plus `Degraded` without calling it a service outage. However, a reader reproducing the unified diagram literally will route Git through the Kubernetes repo Service. Behavioral transfer therefore passes at the operational-decision level but not at exact architecture fidelity.

## Grade card

| Dimension | Verdict | Reason |
|---|---|---|
| Self-containedness | **PASS** | CMC's local role, maintenance primitive, required acronyms, component roles, Kubernetes concepts, route, and unknowns are present in the package. |
| Density | **PASS** | Added material closes named reader gaps; package roles prevent the comprehensive scope from becoming one undifferentiated mega-document. |
| Completeness | **PARTIAL** | The required views and operating route exist, but the as-built diagram has one incorrect service boundary and leaves Dex's function disconnected. |
| Concision | **PASS** | The teaching/operation/evidence split is efficient for the requested comprehensive syllabus; navigation makes return-use practical. |
| Architecture fidelity | **PARTIAL** | Counts and boundaries are source-aligned, but `Git -> repo Service -> repo` is mechanically wrong. |
| Wednesday action transfer | **PASS, bounded** | The route, hard stops, T0 discipline, decision vocabulary, and record destination are clear; pinned wrapper/structured aggregation remain explicitly AVD-unproven and require human execution before use. |
| New `Synced Degraded` example | **PARTIAL** | The case chain is strongly evidenced and outage-bounded, but the generalized green-pipeline claim is false and the negative replica-causation wording is too absolute. |

## Verdict

# PARTIAL

The repaired package now clears the core zero-context learning and Wednesday-operation transfer bar, and F1, F2, F3, F6, and F7 are genuinely closed. It does not qualify for PASS because source alignment does not fully survive the new text: the concrete architecture sends Git through the wrong Service boundary, and the new worked example overstates what a green pipeline and absence of a replica link prove.

Promotion requires only targeted edits:

1. correct the repo-server/Git/Service/controller arrows;
2. bound the negative causation sentence to “no observed mechanism”;
3. replace the green-pipeline rule with the configured-result/fail-open distinction;
4. connect or explicitly bound Dex in the unified diagram;
5. rerun the six Feynman validators and render the repaired Mermaid diagrams.

## Residual human-reader limits

- This agent's closed-book section is contaminated by prior exposure to the predecessor document; it is not equivalent to a genuinely new human SRE.
- The validator skipped Mermaid rendering, so visual syntax/legibility was not behaviorally proven in this pass.
- The ACC wrapper and structured join/aggregation commands remain structurally verified but AVD-behaviorally unproven. The package discloses this correctly; a human paste or isolated-kubeconfig run is still required.
- No Wednesday ACC change, Redis data-plane quorum, controller freshness, or end-user transaction was observed. The package's claims remain appropriately below those proof tiers.

The final human promotion test is a 20-minute exercise with a genuinely new SRE: start at any of the six files, find the correct route, redraw DEV after-state with correct arrow directions, explain `Synced Degraded`, and narrate the first five Wednesday ACC actions plus all `CANNOT VERIFY` boundaries without prompting.
