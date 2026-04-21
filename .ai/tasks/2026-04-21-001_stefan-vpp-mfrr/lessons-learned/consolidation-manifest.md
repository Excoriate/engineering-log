---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Consolidation manifest for Stefan VPP mFRR-Activation crashloop on-call session — 6 promotions (3 lessons, 2 gotchas, 1 pattern; one lesson carries inquiry tag) with full dual-path writes
---

# Consolidation Manifest

## IKS (Inquiry Knowledge State — deep-session)

- **Purpose**: extract durable Eneco VPP on-call + general agent-behavior insights from the Stefan mFRR-Activation ticket investigation, where the adversary inverted both the diagnosis and the framing.
- **Anchor questions**:
  1. What new on-call intake discipline did this session validate?
  2. What general agent-behavior traps did the adversary surface that apply beyond Eneco?
  3. What Eneco-specific operational knowledge is worth preserving?
  4. What unresolved question must future sessions pursue?
- **Artifact shape**: 1 episode + 4 lessons + 2 gotchas + 1 pattern + 6 JSON entries.
- **Success criterion**: a future on-call session handling a Slack Lists intake ticket with Azure EventHubs / blob checkpoint symptoms can navigate from episode → lesson → runbook without re-discovering the adversary's three caveats.

## QCM (Question Coverage Matrix)

| Question | Answerable now? | Where |
|---|---|---|
| How should I treat reporter self-diagnoses in on-call intake? | YES | lesson `reporter-self-diagnoses-are-infer-not-fact` |
| Does K8s Running 1/1 mean the pod is functional? | YES | lesson `kubernetes-running-ready-does-not-imply-functional` |
| Is "SDK convention" a valid IaC authoring input? | YES | gotcha `azure-eventhubs-checkpoint-container-name-is-convention-not-sdk-guarantee` |
| What should I do before authoring a Terraform PR whose names come from dynamic config? | YES | lesson `read-azure-appconfig-values-before-authoring-terraform-pr` |
| What cluster topology does Eneco VPP Sandbox use? | YES | gotcha `eneco-vpp-sandbox-is-aks-not-openshift` |
| How is VPP workload config layered at runtime? | YES | pattern `argocd-helm-oci-plus-appconfig-plus-kv-csi-three-layer-config-stack` |
| Did buildId=1616964 actually fix the missing resources? | NO — deferred; tracked in episode open threads |
| Why are Eneco ESP Kafka brokers unreachable from Sandbox vpp ns? | NO — separate investigation, tracked in episode open threads |

## Artifact review (Phase 1 classification)

### Session artifacts reviewed (11 files from `$T_DIR`)

| Path | Classification | Rationale |
|---|---|---|
| `01-task-requirements-initial.md` | episode-worthy | Pre-flight + initial hypotheses — narrative only |
| `01-task-requirements-final.md` | episode-worthy | Final hypothesis set + verification strategy |
| `02-ai-map.md`, `02-codebase-map.md`, `02-config-map.md`, `02-docs-map.md`, `02-discovery.md`, `02-automation-map.md` | ephemeral | Phase 2 maps — routine scaffolding |
| `context/intake-slack-harvest.md` | episode-worthy | Slack + Rootly context evidence |
| `context/first-principles-knowledge.md` | episode-worthy | MS Learn + un-braiding — already cited in episode |
| `context/handover-contract.md` | episode-worthy | Four-part contract handover to enrich |
| `plan/plan.md` | episode-worthy | Plan + original adversarial challenge |
| `specs/diagnosis-and-fix-spec.md` | ephemeral | Spec template — deliverable shape only |
| `verification/enrich-results.md` | episode-worthy | 18-probe evidence matrix (FACT/INFER/UNVERIFIED) |
| `verification/socrates-contrarian-review.md` | **promotion-candidate (multiple)** | 3 caveats → lessons + gotcha |
| `verification/phase-8-results.md` | **promotion-candidate (multiple)** | 6 memory-worthy lessons explicitly named |
| `verification/activation-checklist.md` | ephemeral | Gate audit — compliance record |
| `outcome/diagnosis.md` | episode-worthy | Final diagnosis — referenced from episode |
| `outcome/slack-reply-draft.md` | ephemeral | Draft reply — not posted, not durable |
| `lessons-learned/oncall-mfrr-reporter-diagnosis-inversion.md` | **promotion-candidate (source-of-truth for 6 lessons)** | Pre-staged by Phase 8 |

### Promotion candidates (6 total, all surviving 4-gate negative-memory discipline)

| # | Candidate | Type | Severity | Recurrence | Behavior-Δ | Evidence | Non-overlap | Gate verdict |
|---|---|---|---|---|---|---|---|---|
| 1 | Reporter self-diagnoses are INFER, not FACT | lesson (inquiry) | high | HIGH (every on-call ticket) | HIGH (prevents wrong-target PR) | Stefan inversion | No existing note | **PROMOTE** |
| 2 | K8s Running 1/1 ≠ functional | lesson | high | HIGH (every triage) | HIGH (adversary-surfaced; silent-outage detection) | R145 Kafka broker FACT | No existing note | **PROMOTE** |
| 3 | SDK convention ≠ SDK guarantee (EH CheckpointStore container name) | gotcha | medium | MEDIUM (any IaC PR for SDK-managed resource) | MEDIUM (PR authoring discipline) | Adversary §2 finding | No existing note | **PROMOTE** |
| 4 | Read App Config before Terraform PR with dynamic names | lesson | high | HIGH (every Eneco VPP IaC PR) | HIGH (single highest-impact probe) | Adversary §6 | No existing note | **PROMOTE** |
| 5 | Eneco VPP Sandbox = Azure AKS (not MC OpenShift) | gotcha | medium | HIGH (every Eneco on-call cross-env probe) | MEDIUM (runbook awareness) | Sebastian du Rand FACT + live probe | No existing note | **PROMOTE** |
| 6 | ArgoCD-helm-OCI + App Config + KV CSI three-layer config stack | pattern | high | HIGH (every VPP workload) | HIGH (explains "same env vars + different image → different behavior") | Live SecretProviderClass + deploy YAML | No existing note | **PROMOTE** |

All six candidates survive all four negative-memory gates. No duplicates with existing MEMORY.md feedback (ArgoCD three-plane RBAC, verify-own-prior-claim) — different topics, no overlap.

## Dual-path writes executed

| # | Markdown path | JSON id |
|---|---|---|
| 1 | `llm-wiki/learnings/lessons/reporter-self-diagnoses-are-infer-not-fact.md` | LL-010 |
| 2 | `llm-wiki/learnings/lessons/kubernetes-running-ready-does-not-imply-functional.md` | LL-011 |
| 3 | `llm-wiki/learnings/gotchas/azure-eventhubs-checkpoint-container-name-is-convention-not-sdk-guarantee.md` | LL-012 |
| 4 | `llm-wiki/learnings/lessons/read-azure-appconfig-values-before-authoring-terraform-pr.md` | LL-013 |
| 5 | `llm-wiki/learnings/gotchas/eneco-vpp-sandbox-is-aks-not-openshift.md` | LL-014 |
| 6 | `llm-wiki/patterns/workflows/argocd-helm-oci-plus-appconfig-plus-kv-csi-three-layer-config-stack.md` | LL-015 |

Write order: markdown FIRST, JSON SECOND per H-JSON-1. All six markdown notes link to the episode; episode backlinks all six.

## Closure summary

- **Questions now answerable**: 6 of 8 QCM questions.
- **Questions remaining open**: 2 (pipeline outcome + Kafka broker root cause) — routed to episode Open Threads.
- **Mastery delta**: the vault now contains a reusable on-call intake discipline (Lesson 1 + Lesson 2 + Lesson 4) and an Eneco-specific operational stack (Gotcha 5 + Pattern 6). A future on-call session can navigate from Slack intake → diagnostic inversion → IaC PR authoring without re-discovering any of these three times.
- **Contradictions**: none surfaced. No existing note contradicts the six promotions.

## Discarded (ephemeral)

6 artifacts classified ephemeral: Phase 2 scaffold maps (6 files) and the spec template + Slack reply draft + activation checklist. These live in the task workspace; they are operational records, not durable knowledge.
