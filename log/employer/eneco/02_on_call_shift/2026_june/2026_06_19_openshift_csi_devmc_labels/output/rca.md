---
task_id: 2026-06-19-openshift-csi-devmc-labels
agent: codex
status: review
output_package: standard
adversarial_review: self-review-only
summary: Dev-MC ArgoCD rollout failure caused by OpenShift CSI Volume Admission rejecting pods that use an unlabeled Secrets Store CSI inline volume in a namespace whose pod security level is lower than privileged.
---

# RCA - Dev-MC ArgoCD rollout blocked by CSI inline volume Pod Security Admission

## Executive summary

AssetPlanning and FleetOptimizer did not roll forward in Dev-MC because OpenShift rejected the new pods before they could be created. ArgoCD was only the messenger: it applied the desired Deployment change, but the Kubernetes/OpenShift admission chain blocked the Deployment controller when it tried to create the next ReplicaSet/pods. The denied pod templates mounted `/mnt/secrets-store` through the inline CSI driver `secrets-store.csi.k8s.io`; the cluster-level `CSIDriver` object had no OpenShift CSI ephemeral volume security profile label, so OpenShift treated that inline CSI volume as requiring `privileged`. The `eneco-vpp` namespace was operating below `privileged`, so pod admission rejected the new pods with the exact error: namespace security level lower than privileged.

The short-term label `pod-security.kubernetes.io/enforce=privileged` on the namespace fixes the symptom because it raises the namespace high enough for the unlabeled CSI driver. It is broad, because it weakens the namespace-level Pod Security Admission guardrail for all pods in that namespace. The least-surprise long-term fix is for CMC/platform owners to classify the CSI driver itself, in GitOps, by adding `security.openshift.io/csi-ephemeral-volume-profile=restricted` to `CSIDriver/secrets-store.csi.k8s.io`, but only after they validate that this Secrets Store CSI driver is safe to use from restricted namespaces. Then workload namespaces can remain restricted instead of being made privileged.

## Table of Contents

1. How to Read This RCA
2. RCA Knowledge Contract
3. Evidence Ledger
4. Backward Derivation
5. Feynman Mental Model
6. L1 - Business and Functional Impact
7. L2 - Repository and Ownership System
8. L3 - Runtime Architecture
9. L4 - Application and Secret Mount Flow
10. L5 - Declarative Contract Failure
11. L6 - Delivery and ArgoCD Flow
12. L7 - Timeline
13. L8 - Fix and Alternatives
14. L9 - Verification Strategy
15. L10 - Lessons Learned
16. L11 - Command Walkthrough and Rationale
17. L12 - One-Page On-Call Playbook
18. Remaining Unknowns and Review Status
19. Official References

## How to read this RCA

If you only need the answer for CMC, read Executive Summary, L8, and L12. If you want to recreate the troubleshooting yourself, read L11 and run `proofs/scripts/replay_oc_diagnosis.sh`. If you want to understand why each command was used, read the Question, Why, Fields, Expected output, Decision rule, and Principle under each command in L11.

The key mental move is this: do not start by asking "why is Argo stuck?" Start by asking "who is trying to create the missing pod, and who is refusing it?" The refusal happened at API admission time, before scheduling, before image pull, before the application started, and before readiness probes mattered.

## RCA Knowledge Contract

This RCA must let a new on-call engineer do five things without guessing:

| Capability | What the reader should be able to do |
| --- | --- |
| Recreate the symptom | Show that the affected Deployments could not create new ReplicaSets/pods. |
| Identify the enforcing component | Explain that the API admission chain rejected the pod before it existed. |
| Identify the config mismatch | Connect workload inline CSI usage, CSIDriver metadata, and namespace Pod Security Admission level. |
| Explain why the workaround worked | Explain why making the namespace privileged admitted the pods, and why that is broad. |
| Explain the durable fix | Explain why labeling the CSIDriver is safer than labeling every workload namespace privileged, provided CMC validates the driver profile. |


Observable mastery verbs for the reader:

- **Draw** the admission path from ArgoCD to Deployment controller to API admission.
- **Trace** the failing decision from pod template to CSIDriver metadata to namespace security level.
- **Recreate** the diagnosis with read-only `oc` commands.
- **Reject** false explanations such as image-pull, readiness, scheduler, or Argo-only root cause.
- **Defend** the difference between namespace privileged mitigation and CSIDriver profile fix.
- **Repair** the platform contract by pointing CMC to the driver-level GitOps change.

Rejection condition for this RCA: if someone reads it and still thinks ArgoCD, the app image, readiness probes, or pod scheduling were the primary cause, the explanation has failed.

## Knowledge domain map

| Domain | What this RCA needs from it | Boundary |
| --- | --- | --- |
| OpenShift admission | Why the API server rejected pod creation before scheduling. | This RCA does not inspect API server source code or audit logs. |
| Kubernetes workload controllers | Why a Deployment shows `ReplicaSetCreateError` when pod creation is denied. | This RCA does not debug app container runtime behavior after pod start. |
| CSI storage metadata | Why `CSIDriver/secrets-store.csi.k8s.io` classification affects inline volumes. | This RCA does not certify the Secrets Store CSI driver security profile; CMC must validate it. |
| GitOps ownership | Why CMC should fix the driver object in source of truth rather than only patching a namespace. | Exact CMC repo path and PR are not confirmed here. |
| On-call operation | How to recreate the diagnosis with read-only `oc` commands. | ACC/PRD are risk candidates, not confirmed impacted environments in this RCA. |
| Security posture | Why namespace-level Pod Security Admission and SCC are related but independent. | This RCA does not approve permanent namespace privilege. |

## 4. Evidence Ledger

Evidence codes are used only in evidence tables and command rationale. Narrative sections state the basis in plain language.

| ID | Evidence | Source | Strength | Why it matters |
| --- | --- | --- | --- | --- |
| E1 | Cluster server was `https://api.eneco-vpp-dev.ceap.nl:6443`. | Live `oc whoami --show-server` observation in Dev-MC terminal. | A1 | Confirms commands targeted Dev-MC, not another environment. |
| E2 | OpenShift server version observed as 4.20.16 and Kubernetes v1.33.8. | Live `oc version` observation. | A1 | Confirms the relevant OpenShift 4.20 behavior/docs apply. |
| E3 | `assetplanning-eneco-vpp` Deployment showed `Progressing=False` with reason `ReplicaSetCreateError`. | Live `oc describe deploy assetplanning-eneco-vpp -n eneco-vpp`. | A1 | Moves the investigation from Argo UI to Deployment controller/admission. |
| E4 | AssetPlanning pod template mounted `/mnt/secrets-store` from CSI driver `secrets-store.csi.k8s.io`. | Live `oc describe deploy assetplanning-eneco-vpp -n eneco-vpp`. | A1 | Shows the affected pod uses inline CSI secrets. |
| E5 | AssetPlanning event said pod creation was forbidden because the namespace enforce level was lower than privileged for inline CSI driver `secrets-store.csi.k8s.io`. | Live `oc describe deploy assetplanning-eneco-vpp -n eneco-vpp`. | A1 | Directly names the admission cause. |
| E6 | `fleetoptimizersolver-eneco-vpp` had `0/1` and `ReplicaSetCreateError` with the same forbidden inline CSI event. | Live `oc describe deploy fleetoptimizersolver-eneco-vpp -n eneco-vpp`. | A1 | Confirms the problem is shared platform/admission behavior, not a single app bug. |
| E7 | `eneco-vpp` namespace had `pod-security.kubernetes.io/audit=restricted` and `pod-security.kubernetes.io/warn=restricted`, plus annotation `security.openshift.io/MinimallySufficientPodSecurityStandard: restricted`. | Live `oc describe ns eneco-vpp`. | A1 | Shows the namespace context is restricted/lower than privileged. |
| E8 | `CSIDriver/secrets-store.csi.k8s.io` had no labels and `Volume Lifecycle Modes: Ephemeral`. | Live `oc describe csidriver secrets-store.csi.k8s.io`. | A1 | Shows the driver supports ephemeral inline volumes but lacks OpenShift profile classification. |
| E9 | The CSIDriver had ArgoCD tracking annotation for `cmc-secrets-store-csi-driver`. | Live `oc describe csidriver secrets-store.csi.k8s.io`. | A1 | Indicates the durable fix belongs in CMC/platform GitOps, not only a manual cluster patch. |
| E10 | Red Hat OpenShift 4.20 docs state Pod Security Admission `enforce` rejects pods that do not comply with the selected profile; profiles are privileged, baseline, restricted. | Red Hat OCP 4.20 Pod Security Admission docs. | A1-doc | Explains the namespace admission mechanism. |
| E11 | Red Hat OpenShift docs state that without `csi-ephemeral-volume-profile` on a CSI ephemeral driver, the CSI Volume Admission plugin treats the driver as privileged for enforcement/warn/audit behavior. | Red Hat OCP storage docs search/open result for OCP 4.20 CSI. | A1-doc | Explains why an unlabeled CSIDriver became a privileged requirement. |
| E12 | Slack screenshot reported the incident was mitigated by adding `pod-security.kubernetes.io/enforce=privileged`. | User-provided screenshot. | A2 | Supports that raising namespace enforce level resolved the immediate symptom; not independently queried from Slack. |
| E13 | Exact CMC repository file and PR are not confirmed in this RCA. | Not queried in this session. | A3 | Prevents overstating the implementation location for the durable GitOps fix. |
| E14 | ACC/PRD are not checked in this RCA. | Not queried in this session. | A3 | The same condition is a risk if those clusters share driver/workload/namespace state, but this RCA does not claim it exists there. |


## Context ledger

Detailed context is also captured in [antecedents/context-ledger.md](../antecedents/context-ledger.md) and raw observations are summarized in [proofs/outputs/observed-devmc-session.md](../proofs/outputs/observed-devmc-session.md). The local ledger below keeps the core surfaces visible before the RCA levels.

| Context surface | Role in diagnosis | Evidence pointer | Boundary |
| --- | --- | --- | --- |
| Dev-MC OpenShift API | Runtime control plane that rejected the pod request. | [Observed Dev-MC session](../proofs/outputs/observed-devmc-session.md) | Audit logs were not queried. |
| `eneco-vpp` namespace | Supplies namespace security labels read by Pod Security Admission. | [Context ledger](../antecedents/context-ledger.md) | Exact namespace GitOps repo path is blocked-source: not inspected. |
| AssetPlanning Deployment | First affected workload used to prove the rollout failure mechanism. | [Observed Dev-MC session](../proofs/outputs/observed-devmc-session.md) | Business functional internals were not inspected. |
| FleetOptimizer solver Deployment | Second affected workload proving the shared pattern. | [Observed Dev-MC session](../proofs/outputs/observed-devmc-session.md) | Gateway/runtime behavior after pod start is outside this RCA. |
| `CSIDriver/secrets-store.csi.k8s.io` | Cluster-scoped driver metadata that lacked the OpenShift profile label. | [Observed Dev-MC session](../proofs/outputs/observed-devmc-session.md) | Correct restricted classification requires CMC validation. |
| Red Hat OpenShift docs | Vendor specification for Pod Security Admission and CSI Volume Admission behavior. | [Pod Security Admission docs](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/authentication_and_authorization/understanding-and-managing-pod-security-admission), [CSI docs](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/storage/using-container-storage-interface-csi) | Docs explain expected behavior; live `oc` output proves this cluster state. |

## Backward derivation from the contract

We start from the externally visible symptom and walk backward to the first mechanism that explains every observation.

| Knowledge domain | Primitive | Visual | Probe | Challenge | Section |
| --- | --- | --- | --- | --- | --- |
| OpenShift admission | A pod creation request is accepted or rejected before a pod exists. | Door-check mental model. | `oc describe deploy` event text. | If pods existed and crashed, this would be a runtime/log problem instead. | L3, L6, L11 |
| CSI volume classification | Inline CSI driver metadata can change admission outcome. | Pod spec carries a CSI item in the bag. | `oc describe csidriver secrets-store.csi.k8s.io`. | If the driver had the profile label, the route would shift to namespace/profile mismatch. | L4, L5, L8 |
| Namespace security | Namespace labels supply Pod Security Admission posture. | Door policy in front of the namespace. | `oc describe ns eneco-vpp`. | If namespace were already privileged, the same forbidden event would need a different policy source. | L5, L8, L9 |
| GitOps ownership | Durable fixes must land in the source of truth. | Live object points back to CMC-managed driver. | CSIDriver Argo tracking annotation. | If object were not GitOps-managed, live patch plus ownership ticket would be the only route. | L2, L8 |
| Recurrence analysis | Same driver pattern can affect other namespaces. | Event scan versus exposure scan. | all-namespace `oc get events` and workload-template scan. | Events prove current impact; workload templates prove exposure only. | L11, L12 |


| Step | Observation | What that rules out | What it points to |
| --- | --- | --- | --- |
| 1 | ArgoCD apps stayed Progressing / Sync failed. | Argo alone cannot be assumed as root cause; it may be reporting a lower-level Kubernetes failure. | Inspect the live Kubernetes objects. |
| 2 | Deployment condition was `Progressing=False` with `ReplicaSetCreateError`. | Rules out readiness-only or service-routing-only causes. | The Deployment controller could not create the next ReplicaSet/pod. |
| 3 | Events said pod creation was forbidden. | Rules out scheduler capacity, node readiness, image pull, and runtime crash as primary causes. | API admission rejected the pod before it existed. |
| 4 | Forbidden event named inline CSI driver `secrets-store.csi.k8s.io` and namespace level lower than privileged. | Rules out app container logic and ordinary Secret env var problems. | CSI Volume Admission and Pod Security Admission intersected. |
| 5 | Pod template used a CSI inline volume; CSIDriver had ephemeral mode but no profile label. | Rules out a random namespace label-only explanation. | The CSI driver was unclassified, so OpenShift defaulted it to privileged for this admission path. |
| 6 | Namespace was restricted/lower than privileged. | Rules out a mismatch where namespace was already privileged. | The namespace could not admit pods using that unclassified inline CSI volume. |
| 7 | Namespace privileged label mitigated the issue. | Confirms the failing decision was a namespace-vs-driver security profile mismatch. | Durable fix should classify the driver, not permanently broaden every namespace. |

Root cause statement: the Dev-MC platform had an unlabeled ephemeral CSI driver used by application pods, and OpenShift 4.20 admission treated that driver as privileged by default. New pods in the `eneco-vpp` namespace were therefore rejected because the namespace was lower than privileged.

## Mental model map

Think of pod creation as entering a building with two checks at the door. The Deployment controller is the person asking to enter. The pod spec is the bag they carry. The namespace security label is the door policy. The CSI driver label is the risk label on one item in the bag.

If the bag contains an inline CSI volume and the CSI driver has no risk label, OpenShift says: "I do not know how safe this item is, so I will treat it as privileged." If the namespace door policy is restricted, the door refuses entry. ArgoCD keeps saying "I am still trying to apply the desired state," but the actual refusal happens at the Kubernetes API admission door.

```text
Desired state in ArgoCD
        |
        v
Deployment controller tries to create new ReplicaSet/pod
        |
        v
Pod spec contains inline CSI volume: secrets-store.csi.k8s.io
        |
        v
OpenShift checks CSIDriver profile label
        |
        +--> no csi-ephemeral-volume-profile label found
        |        |
        |        v
        |    OpenShift treats driver as privileged for admission
        |
        v
Namespace eneco-vpp is lower than privileged
        |
        v
API admission rejects pod creation
        |
        v
Deployment cannot roll out, ArgoCD remains Progressing/Sync failed
```

The important distinction is between "the app failed after starting" and "the pod was never allowed to be born." Here, the pod was never admitted. That is why `oc describe deploy` was more useful than logs from the new pod: there was no new pod to log from.

## L1 - Business and Functional Impact

The affected application surfaces were AssetPlanning and FleetOptimizer in Dev-MC. Based on the observed Deployment states, AssetPlanning still had old available replicas, so the immediate symptom was a stuck rollout rather than total application disappearance. FleetOptimizer solver showed zero desired runtime availability for the new Deployment state, so its new version could not become active.

The business impact in this RCA is intentionally scoped to Dev-MC rollout failure. This RCA does not claim production customer impact, because ACC/PRD were not queried. The operational impact was that ArgoCD could not converge and application changes could not replace old pods in the affected namespace.

## L2 - Repository and Ownership System

### The story in plain English

The incident crosses two GitOps ownership lanes. The application lane declares pod templates that use the Secrets Store CSI inline volume. The platform/CMC lane declares the cluster-scoped CSIDriver object that tells OpenShift how to classify that inline volume for admission. The failure appeared in application rollouts, but the durable fix belongs in the platform lane because the missing driver profile is shared across namespaces.

### Ownership rigor table

| Repo | System role | Technology / artifact | Source surface | Deployment handoff | Incident relevance |
| --- | --- | --- | --- | --- | --- |
| [VPP application GitOps source - blocked](../antecedents/context-ledger.md) | Declares application workloads such as AssetPlanning and FleetOptimizer. | Helm/Deployment pod templates with CSI volume usage. | [Observed pod templates](../proofs/outputs/observed-devmc-session.md); blocked-source: exact repo path not inspected. | ArgoCD application sync. | Shows why these apps triggered the CSI admission path. |
| [CMC Secrets Store CSI driver source - blocked](../antecedents/context-ledger.md) | Declares the cluster-scoped Secrets Store CSI driver. | `CSIDriver/secrets-store.csi.k8s.io` with OpenShift profile label. | [Observed CSIDriver output](../proofs/outputs/observed-devmc-session.md); blocked-source: exact CMC repo path not inspected. | CMC ArgoCD app `cmc-secrets-store-csi-driver`. | This is where the durable profile label should land. |
| [Namespace GitOps source - blocked](../antecedents/context-ledger.md) | Declares namespace labels and Argo management metadata. | Namespace `eneco-vpp` Pod Security Admission labels. | [Observed namespace output](../proofs/outputs/observed-devmc-session.md); blocked-source: exact namespace manifest path not inspected. | Argo-managed namespace object. | Explains why namespace privileged was a working but broad mitigation. |
| [Red Hat OpenShift Pod Security Admission docs](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/authentication_and_authorization/understanding-and-managing-pod-security-admission) | Defines the admission profiles and `enforce` behavior. | Vendor specification. | Official Red Hat docs. | Cluster API admission behavior. | Explains why lower-than-privileged namespace posture can reject pod creation. |
| [Red Hat OpenShift CSI docs](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/storage/using-container-storage-interface-csi) | Defines CSI inline/ephemeral admission profile behavior. | Vendor specification. | Official Red Hat docs. | CSI Volume Admission plugin. | Explains why an unlabeled ephemeral CSIDriver is treated as privileged. |

### How the paths interact under the hood

ArgoCD can sync both application manifests and platform manifests, but the Kubernetes API evaluates the combined result at pod creation time. The [application GitOps source is blocked-source in this RCA](../antecedents/context-ledger.md) and can still be perfectly valid YAML while the [platform GitOps source is blocked-source in this RCA](../antecedents/context-ledger.md) leaves a cluster-scoped driver unclassified for the namespace security level where the app runs.

### Why this matters for the fix

Patching every workload namespace to privileged treats the symptom at the consumer edge. Labeling the CMC-managed CSIDriver treats the shared platform contract that OpenShift admission uses for all consumers of that driver.

## L3 - Runtime Architecture

The runtime path has five actors: ArgoCD, the Deployment controller, API admission, namespace Pod Security Admission, and the cluster-level CSIDriver object.

| Actor | Role in this incident | What the live output showed |
| --- | --- | --- |
| ArgoCD | Applies desired state and reports health/sync. | Apps stayed Progressing/Sync failed. |
| Deployment controller | Converts Deployment changes into ReplicaSets/pods. | Reported `ReplicaSetCreateError`. |
| Kubernetes/OpenShift API admission | Accepts or rejects pod creation requests before pods exist. | Returned `forbidden` for new pods. |
| Namespace Pod Security Admission | Supplies the namespace security profile used by admission. | Namespace was restricted/lower than privileged. |
| CSIDriver `secrets-store.csi.k8s.io` | Describes the CSI driver and its inline/ephemeral behavior. | Driver had `Ephemeral` lifecycle mode and no profile label. |

The feedback loop is important: ArgoCD keeps reconciling because desired state is not reached; the Deployment controller keeps failing because admission rejects; admission keeps rejecting because the namespace and CSIDriver metadata are unchanged.

## L4 - Application and Secret Mount Flow

The affected pods use Secrets Store CSI as a mounted file-system secret source. In the observed pod template, the application container mounted `/mnt/secrets-store` from a volume named `secrets-store-inline`, and that volume used the CSI driver `secrets-store.csi.k8s.io` with a `secretProviderClass`.

That means this was not an ordinary Kubernetes Secret environment variable issue. The pod spec asked the kubelet/CSI machinery to mount material from an external secret provider as an inline CSI volume. OpenShift therefore checked the CSI driver admission profile before allowing the pod to be created.

| Workload | Observed CSI mount | Secret provider class | Failure mode |
| --- | --- | --- | --- |
| `assetplanning-eneco-vpp` | `/mnt/secrets-store` via `secrets-store-inline` | `secret-provider-kv` | New ReplicaSet/pod denied. |
| `fleetoptimizersolver-eneco-vpp` | `/mnt/secrets-store` via `secrets-store-inline` | `secret-provider-keyvault-fleetoptimizer` | New ReplicaSet/pod denied. |

The shared pattern across two workloads is the reason this is platform/admission root cause, not application-specific root cause.

## L5 - Declarative Contract Failure

The declarative contract had three pieces that did not line up.

| Contract piece | Declared state | Why it matters |
| --- | --- | --- |
| Workload pod template | Uses inline CSI driver `secrets-store.csi.k8s.io`. | Triggers CSI Volume Admission checks for inline ephemeral CSI volumes. |
| CSIDriver object | Supports `Ephemeral` lifecycle mode but had no `security.openshift.io/csi-ephemeral-volume-profile` label. | OpenShift treats an unclassified CSI ephemeral driver as privileged for admission behavior. |
| Namespace `eneco-vpp` | Restricted/lower than privileged. | A lower-than-privileged namespace cannot admit a pod whose inline CSI driver is treated as privileged. |

This is the root contract mismatch: workload asks for inline CSI, driver metadata does not classify the security profile, namespace is not privileged, so admission refuses pod creation.

## L6 - Delivery and ArgoCD Flow

ArgoCD did not create the final failure. It surfaced a Kubernetes admission failure. The chain is:

| Stage | What normally happens | What happened here |
| --- | --- | --- |
| ArgoCD sync | Desired Deployment state is applied. | Sync tried to move application state forward. |
| Deployment rollout | Deployment controller creates a new ReplicaSet/pod. | Controller hit `ReplicaSetCreateError`. |
| API admission | API server validates the pod request. | Pod request was rejected as forbidden. |
| Pod lifecycle | Pod schedules, pulls image, starts, becomes ready. | This stage was never reached for the blocked new pods. |

This matters because troubleshooting must stop chasing readiness, logs, or app code once `ReplicaSetCreateError` plus `forbidden` appears. The pod did not fail inside the cluster runtime; it failed at the admission gate.

## L7 - Timeline

| Time on 2026-06-19 | Event | Evidence |
| --- | --- | --- |
| Around 14:28 | Dev-MC OpenShift login visible in WSL/Ubuntu terminal. | User-provided screenshot and live terminal context. |
| Around 14:35-14:36 | Live `oc` diagnosis showed Deployment `ReplicaSetCreateError`, inline CSI usage, namespace lower than privileged, and unlabeled CSIDriver. | Live terminal observations summarized in `proofs/outputs/observed-devmc-session.md`. |
| 15:04 | Incident references were created/shared in Slack. | User screenshot. |
| 15:12 | Slack message reported namespace label `pod-security.kubernetes.io/enforce=privileged` was added because of CSI inline volumes. | User screenshot. |
| 15:13 | Team discussion questioned whether privileged namespace is too broad and whether ACC/PRD could be hit; CMC mentioned a later PR for `ephemeral-volume-profile`. | User screenshot. |

The timeline is consistent with a latent platform configuration issue surfacing only when new pods were created after the OpenShift/admission behavior was present.

## L8 - Fix and Alternatives

### Immediate mitigation

Set `pod-security.kubernetes.io/enforce=privileged` on namespace `eneco-vpp`. This is why the Slack-reported fix worked: it made the namespace high enough to admit pods using a CSI driver that OpenShift considered privileged.

Do not confuse this with saying "every pod can now automatically run as root." OpenShift Security Context Constraints still run independently and still validate what a service account is allowed to do. However, the namespace-level Pod Security Admission guardrail is weakened for every pod in that namespace, so this is broad and should be treated as a mitigation, not the preferred permanent design.

### Preferred durable fix

CMC/platform owners should add this label to the cluster-scoped driver definition in GitOps, after validating the driver is safe for restricted consumers:

```yaml
metadata:
  labels:
    security.openshift.io/csi-ephemeral-volume-profile: restricted
```

Target object:

```text
CSIDriver/secrets-store.csi.k8s.io
```

Why this is better: it classifies the risky object directly. The namespace can remain restricted, and every namespace using the same Secrets Store CSI inline driver benefits from the same driver-level classification instead of needing a namespace-wide privileged exception.

### What this fix does NOT change / residuals

The namespace workaround does NOT classify the CSI driver, does NOT prove ACC/PRD are safe, and does NOT prove `restricted` is the correct driver profile. It only changes the namespace admission level. The durable fix still needs CMC validation, a GitOps source change, and rollout verification after the driver metadata is corrected.

### Alternatives considered

| Option | Result | Why it is or is not preferred |
| --- | --- | --- |
| Keep namespace privileged permanently. | Rollout works. | Broad namespace exception; not least privilege. |
| Label each affected namespace privileged. | Workloads in those namespaces work. | Repeats toil and broadens security posture across many namespaces. |
| Remove inline CSI volume from apps. | Avoids the specific CSI admission path. | Likely large application/secret-management redesign; not the immediate platform fix. |
| Label CSIDriver as restricted. | Keeps namespaces restricted while allowing this driver. | Preferred if CMC validates the driver profile is actually restricted-safe. |

## L9 - Verification Strategy

A fix is not verified by seeing Argo become green once. It is verified by proving the admission mismatch is gone and the rollout can create pods.

| Verification question | Command | Passing signal |
| --- | --- | --- |
| Is the driver classified? | `oc describe csidriver secrets-store.csi.k8s.io` | Shows label `security.openshift.io/csi-ephemeral-volume-profile=restricted`, or an explicitly intended profile. |
| Is the namespace still least-privilege? | `oc describe ns eneco-vpp` | Does not require permanent `pod-security.kubernetes.io/enforce=privileged`, unless CMC accepts that as policy. |
| Can affected Deployments create new ReplicaSets/pods? | `oc describe deploy assetplanning-eneco-vpp -n eneco-vpp` and `oc describe deploy fleetoptimizersolver-eneco-vpp -n eneco-vpp` | No new `ReplicaSetCreateError` forbidden events; rollout progresses. |
| Did the workload actually become available? | `oc rollout status deploy/<name> -n eneco-vpp` | Rollout completed successfully. |
| Are other namespaces at risk? | Cluster-wide scan for Deployments with inline CSI driver plus CSIDriver profile and namespace labels. | Risk list is empty or tracked with remediation owner. |

Proof tier for this RCA: source and runtime evidence support the root cause in Dev-MC. ACC/PRD exposure and the exact CMC GitOps PR are not verified in this package.

## L10 - Lessons Learned

1. **ArgoCD is a symptom surface.** ArgoCD health is not always the failing subsystem. When Argo says Progressing and Kubernetes says `ReplicaSetCreateError`, the next question is admission, not application logs.
2. **Inline CSI volumes need driver classification.** Inline CSI volumes have a driver-level security classification in OpenShift. If that classification is missing, OpenShift can treat the driver as privileged even if no one explicitly set `enforce=restricted` on the namespace.
3. **Namespace privileged is a mitigation.** Namespace-wide `enforce=privileged` can be a valid emergency unblocker, but it is broader than the root cause. The precise fix is usually to classify the cluster-scoped resource that admission is using to make the decision.
4. **Existing pods can hide admission failures.** Existing pods can keep running while new pods fail. Admission is checked when pods are created; it does not retroactively re-admit pods that already exist.
5. **ACC/PRD risk is conditional.** The same issue can hit ACC/PRD if they share three conditions: same OpenShift/admission behavior, same unlabeled `secrets-store.csi.k8s.io` CSIDriver, and workloads using inline CSI volumes in namespaces below privileged.

## L11 - Command Walkthrough and Rationale

This section is the replayable troubleshooting path. Every command is read-only unless clearly marked as a proposed CMC fix command. The commands intentionally move from "where am I?" to "what failed?" to "which admission contract caused it?"

### Step 0 - Confirm cluster identity

**Question**: Am I looking at the Dev-MC cluster where the incident was reported?

**Why this command/API**: `oc whoami --show-server` asks the current `oc` client which API server it is logged into. It prevents accidentally diagnosing ACC, PRD, or a stale kubeconfig context.

**Fields selected**: API server URL.

**Expected output**: Dev-MC API server, observed as `https://api.eneco-vpp-dev.ceap.nl:6443`.

**Decision rule**: If this is not Dev-MC, stop. Any later conclusion would be about the wrong cluster.

**Principle**: Always anchor an operational diagnosis to the exact control plane before reading symptoms.

```bash
# WHY: Prove the oc context is the incident cluster before interpreting any resource state.
oc whoami --show-server
```

### Step 1 - Confirm OpenShift version

**Question**: Which OpenShift behavior and documentation version applies?

**Why this command/API**: Admission behavior can change across OpenShift versions. `oc version` gives the server version, which is the behavior that matters for API admission.

**Fields selected**: Server version and Kubernetes version.

**Expected output**: Observed server version was OpenShift 4.20.16 with Kubernetes v1.33.8.

**Decision rule**: Use OCP 4.20 docs for Pod Security Admission and CSI Volume Admission. If version differs, verify the matching docs before generalizing.

**Principle**: Docs are only safe when matched to the runtime version.

```bash
# WHY: Match the cluster behavior to the correct OpenShift documentation version.
oc version
```

### Step 2 - Confirm the namespace and deployment symptom

**Question**: Are the affected Deployments actually unavailable or stuck from Kubernetes' point of view?

**Why this command/API**: `oc get deploy -n eneco-vpp` gives the Deployment controller's summarized state. It is faster than reading Argo first because it tells whether Kubernetes can create/update pods.

**Fields selected**: `READY`, `UP-TO-DATE`, `AVAILABLE`, and age/name.

**Expected output**: AssetPlanning had old available replicas, while FleetOptimizer solver had no available updated pod.

**Decision rule**: If Deployments are fully ready and up to date, Argo may be stale. If Deployments are not progressing, inspect the Deployment details and events.

**Principle**: Move from UI symptom to controller state.

```bash
# WHY: Check the Kubernetes controller's state instead of relying only on Argo UI health.
oc get deploy -n eneco-vpp
```

### Step 3 - Inspect AssetPlanning Deployment conditions and events

**Question**: Why did AssetPlanning fail to roll out?

**Why this command/API**: `oc describe deploy` combines the pod template, Deployment conditions, and recent events. For rollout failures, this is the shortest path from symptom to controller reason.

**Fields selected**: Conditions, events, volume mounts, CSI volume driver, and secretProviderClass.

**Expected output**: `Progressing=False`, reason `ReplicaSetCreateError`, inline CSI volume `secrets-store.csi.k8s.io`, and forbidden event saying namespace enforce level is lower than privileged.

**Decision rule**: If the event says `forbidden`, treat it as an admission problem. Do not chase pod logs, because the new pod was not created.

**Principle**: Controller events often contain the first exact failure boundary.

```bash
# WHY: Read the controller reason, pod template, and admission error for AssetPlanning in one place.
oc describe deploy assetplanning-eneco-vpp -n eneco-vpp
```

### Step 4 - Inspect FleetOptimizer solver for the same pattern

**Question**: Is this the same failure pattern in another affected app, or a one-off AssetPlanning issue?

**Why this command/API**: Repeating `oc describe deploy` on the second affected workload tests whether the mechanism is shared. Shared event wording plus shared CSI driver points to platform/admission, not app code.

**Fields selected**: Conditions, events, volume mounts, CSI volume driver, and secretProviderClass.

**Expected output**: `ReplicaSetCreateError`, zero available new pods, inline CSI volume `secrets-store.csi.k8s.io`, and the same forbidden event.

**Decision rule**: If both apps fail on the same admission event, promote platform/admission as leading cause. If only one app fails, inspect its pod template differences.

**Principle**: A root cause that explains multiple workloads is stronger than an app-specific guess.

```bash
# WHY: Confirm whether FleetOptimizer solver fails for the same admission reason.
oc describe deploy fleetoptimizersolver-eneco-vpp -n eneco-vpp
```

### Step 5 - Inspect namespace Pod Security Admission state

**Question**: What security profile is the namespace presenting to admission?

**Why this command/API**: Pod Security Admission uses namespace labels. `oc describe ns` shows labels and OpenShift security annotations without needing a JSONPath expression.

**Fields selected**: `pod-security.kubernetes.io/enforce`, `pod-security.kubernetes.io/audit`, `pod-security.kubernetes.io/warn`, and `security.openshift.io/MinimallySufficientPodSecurityStandard`.

**Expected output**: Before the workaround, namespace state was restricted/lower than privileged. Observed labels included `audit=restricted`, `warn=restricted`, and OpenShift minimally sufficient PSS annotation `restricted`.

**Decision rule**: If namespace is lower than privileged and the event requires privileged, the namespace side of the mismatch is confirmed. If it is already privileged, inspect whether a different admission policy is failing.

**Principle**: Admission messages must be mapped to the policy object that admission reads.

```bash
# WHY: Show the namespace security profile that admission compares against the pod request.
oc describe ns eneco-vpp
```

### Step 6 - Inspect the CSIDriver object

**Question**: How is the Secrets Store CSI driver classified for inline ephemeral volume admission?

**Why this command/API**: The failing event named `secrets-store.csi.k8s.io`. `CSIDriver` is a cluster-scoped API object that records CSI driver behavior. OpenShift also reads an admission-relevant label from this object for CSI ephemeral volumes.

**Fields selected**: Labels, annotations, `Volume Lifecycle Modes`, and any `security.openshift.io/csi-ephemeral-volume-profile` label.

**Expected output**: Observed `Labels: <none>`, Argo tracking annotation for `cmc-secrets-store-csi-driver`, and `Volume Lifecycle Modes: Ephemeral`.

**Decision rule**: If the driver supports `Ephemeral` and lacks `security.openshift.io/csi-ephemeral-volume-profile`, OpenShift treats it as privileged for this admission path. If the label exists, compare that value to the namespace profile.

**Principle**: Find the cluster-scoped object named by the failure event; do not infer driver behavior from workload YAML alone.

```bash
# WHY: Check whether the named CSI driver has the OpenShift security profile label admission expects.
oc describe csidriver secrets-store.csi.k8s.io
```

### Step 7 - List namespaces currently showing the actual failure

**Question**: Which namespaces are currently impacted according to live cluster events?

**Why this command/API**: Events are the shortest read-only source for "this has already failed." This command looks for the exact admission error text naming inline CSI volumes from `secrets-store.csi.k8s.io`.

**Fields selected**: Namespace, involved object kind/name, event reason, and the forbidden message.

**Expected output**: One row per namespace/object that recently failed pod creation because of the Secrets Store CSI inline volume admission rule.

**Decision rule**: A namespace in this output has already hit the issue recently. No output does not prove safety, because Kubernetes events expire and rotate.

**Principle**: Separate "already failing" evidence from "could fail on next rollout" exposure.

```bash
# WHY: Find namespaces with recent failed pod creation events for this exact CSI admission error.
oc get events -A -o json | jq -r '.items[] | select((.message // "") | contains("inline volume provided by CSIDriver secrets-store.csi.k8s.io")) | [.metadata.namespace, .involvedObject.kind, .involvedObject.name, .reason, (.message | gsub("\n"; " "))] | @tsv' | sort -u
```

### Step 8 - List all namespaces exposed to this root cause

**Question**: Which namespaces have workloads that can hit this issue when they sync or roll out?

**Why this command/API**: Workload pod templates declare whether they use the inline CSI driver. This scan checks Deployments, StatefulSets, DaemonSets, Jobs, and CronJobs across all namespaces.

**Fields selected**: Namespace, workload kind, workload name.

**Expected output**: A list of workload templates that contain a CSI volume using `secrets-store.csi.k8s.io`.

**Decision rule**: Every namespace in this output is exposed to this root cause if the CSIDriver remains unclassified and the namespace is lower than privileged. Cross-check namespace labels to separate already-mitigated namespaces from still-risky ones.

**Principle**: A platform RCA should identify recurrence candidates, not only the first namespace that raised the incident.

```bash
# WHY: Find all workload templates that declare the Secrets Store CSI inline volume driver.
oc get deploy,statefulset,daemonset,job,cronjob -A -o json | jq -r 'def vols: if .kind == "CronJob" then (.spec.jobTemplate.spec.template.spec.volumes // []) else (.spec.template.spec.volumes // []) end; .items[] | select([vols[]? | select(.csi.driver == "secrets-store.csi.k8s.io")] | length > 0) | [.metadata.namespace, .kind, .metadata.name] | @tsv' | sort -u
```

If you only need the namespace names:

```bash
# WHY: Collapse exposed workloads to the unique namespace list for incident scoping.
oc get deploy,statefulset,daemonset,job,cronjob -A -o json | jq -r 'def vols: if .kind == "CronJob" then (.spec.jobTemplate.spec.template.spec.volumes // []) else (.spec.template.spec.volumes // []) end; .items[] | select([vols[]? | select(.csi.driver == "secrets-store.csi.k8s.io")] | length > 0) | .metadata.namespace' | sort -u
```

### Step 9 - Verify the immediate workaround, if CMC applied it

**Question**: Did the namespace workaround raise the namespace to privileged?

**Why this command/API**: The workaround was a namespace label. The only reliable verification is to read the namespace labels after the change.

**Fields selected**: `pod-security.kubernetes.io/enforce`.

**Expected output**: `pod-security.kubernetes.io/enforce=privileged` if the workaround is present.

**Decision rule**: If the label is present and rollouts now work, the workaround matched the admission failure. If rollouts still fail, inspect new events because a second failure exists.

**Principle**: Verify the exact contract field that was changed, not just the UI color.

```bash
# WHY: Confirm whether the broad namespace mitigation is now present.
oc describe ns eneco-vpp
```

### Step 10 - Verify the preferred durable fix, when CMC ships it

**Question**: Did CMC classify the driver rather than only broadening namespaces?

**Why this command/API**: The durable fix is on the `CSIDriver`, not the Deployment. Reading `CSIDriver` proves whether platform metadata changed.

**Fields selected**: `security.openshift.io/csi-ephemeral-volume-profile` label.

**Expected output**: `security.openshift.io/csi-ephemeral-volume-profile=restricted`, assuming CMC validates restricted is the correct profile for this driver.

**Decision rule**: If the CSIDriver label is set appropriately, namespaces should not need `enforce=privileged` just for this CSI admission path. If the label is absent, the platform-level root cause remains.

**Principle**: Fix the object whose missing metadata caused the default privileged interpretation.

```bash
# WHY: Prove whether the driver-level classification exists after CMC's GitOps change.
oc describe csidriver secrets-store.csi.k8s.io
```

### Step 11 - Verify rollout behavior after the fix

**Question**: Can the affected Deployments now create pods and complete rollout?

**Why this command/API**: Admission fixes must be validated by the controller that previously failed. `oc rollout status` waits for the Deployment to reach its rollout condition.

**Fields selected**: Rollout completion status and new Deployment events if it fails.

**Expected output**: Rollout completes for AssetPlanning and FleetOptimizer solver, or the failure event changes to a different cause.

**Decision rule**: If rollout succeeds and no new `ReplicaSetCreateError` forbidden events appear, the admission issue is cleared. If it fails with the same event, the fix did not affect the admission decision.

**Principle**: The final proof is the consumer behavior that failed before: new pod creation through the Deployment controller.

```bash
# WHY: Validate that the previously blocked Deployment controller path now succeeds.
oc rollout status deploy/assetplanning-eneco-vpp -n eneco-vpp
oc rollout status deploy/fleetoptimizersolver-eneco-vpp -n eneco-vpp
```

## L12 - One-Page On-Call Playbook

Use this during a live incident.

| Minute | Action | Why |
| --- | --- | --- |
| 0 | Confirm cluster: `oc whoami --show-server`; confirm version: `oc version`. | Prevent wrong-cluster diagnosis and match docs to runtime. |
| 1 | Check Deployments: `oc get deploy -n eneco-vpp`. | Move from Argo symptom to Kubernetes controller state. |
| 2 | Describe affected Deployment. | Find condition, event, and pod template in one place. |
| 3 | If event says `forbidden` and names inline CSI, describe namespace and CSIDriver. | Admission failures are explained by policy objects, not pod logs. |
| 4 | If CSIDriver lacks `csi-ephemeral-volume-profile` and namespace is lower than privileged, call platform/CMC. | Root cause is driver classification versus namespace policy. |
| 5 | For emergency unblock, CMC may set namespace `enforce=privileged`; for durable fix, CMC should label the CSIDriver in GitOps after validating profile. | Distinguishes mitigation from least-privilege correction. |
| After | Scan other namespaces using the same inline CSI driver. | Prevent recurrence on the next rollout in ACC/PRD or other Dev-MC namespaces. |

## 18. Remaining Unknowns and Review Status

Status is `review`, not `complete`, because this package has not been independently challenged by another operator or by CMC. The Dev-MC root cause is strongly supported by live `oc` output and official OpenShift docs, but these items remain open:

| Unknown | Why it matters | How to close it |
| --- | --- | --- |
| Exact CMC GitOps file/PR for `CSIDriver/secrets-store.csi.k8s.io`. | Needed to implement the durable fix in the source of truth. | CMC identifies the Argo app source for `cmc-secrets-store-csi-driver`. |
| Whether `restricted` is the correct profile for this Secrets Store CSI driver in this platform. | Incorrectly labeling the driver too permissively or too restrictively changes security posture or breaks workloads. | CMC validates driver behavior against OpenShift guidance and vendor/operator docs. |
| ACC/PRD exposure. | Same root cause can recur outside Dev-MC. | Run the Step 7 scan and CSIDriver/namespace checks in ACC/PRD. |
| Whether namespace `enforce=privileged` remains after durable fix. | Permanent namespace privilege may be broader than necessary. | After driver label is validated, test removing namespace workaround under CMC change control. |

## 19. Official References

- Red Hat OpenShift 4.20 - Understanding and managing Pod Security Admission: https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/authentication_and_authorization/understanding-and-managing-pod-security-admission
- Red Hat OpenShift 4.20 - Using Container Storage Interface (CSI): https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/storage/using-container-storage-interface-csi
- Red Hat OpenShift 4.20 - CSIDriver storage API: https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/storage_apis/storage-apis
- Red Hat OpenShift 4.20 - Managing Security Context Constraints: https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/authentication_and_authorization/managing-pod-security-policies
- Kubernetes - Ephemeral volumes: https://kubernetes.io/docs/concepts/storage/ephemeral-volumes/
