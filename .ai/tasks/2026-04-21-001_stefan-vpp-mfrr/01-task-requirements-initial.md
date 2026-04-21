---
task_id: 2026-04-21-001
agent: claude-code
status: draft
summary: Initial pre-flight for Stefan VPP mFRR-Activation crash-loop on-call ticket
---

# Pre-Flight Mirror

- Phase: 1 | Brain: 67.0.0 | task_id: 2026-04-21-001
- Request: Diagnose on-call ticket `2026_04_21_stefan_vpp_infrastructure_mfrr` using
  `/eneco-oncall-intake-slack`, `/eneco-oncall-intake-enrich`, `/2ndbrain-*`, and other
  relevant `eneco-*` skills; produce complete, verified diagnosis and step-by-step fix.
- DOMAIN-CLASS: investigation
- ROOT-ARTIFACT: n
- CRUBVG: C/R/U/B/V/G = 2/1/2/2/1/2 → 10
- Triggers: LIBRARIAN:y | CONTRARIAN:y | EVALUATOR:y | DOMAIN:y | TOOLS:y
- BRAIN SCAN: Most dangerous assumption = reporter's self-diagnosis ("missing EventHub
  consumer group causing crash loop") is already correct and complete — accepting it as
  FACT without independent probe is sycophancy gate violation. Most likely failure =
  conflating Stefan's mFRR ticket with unrelated `erik_lumbela_argocd` ticket opened
  in IDE (different ticket, different root cause).

## Ticket Material (bounded Phase-1 probe — route-defining)

Source: `slack-antecedents.txt` (619 bytes, single file in ticket folder).

- **Slack list record**: `T039G7V20/F0ACUPDV7HU?record_id=Rec0AU7GAKAJH`
- **Slack thread**: `C063SNM8PK5/p1776781493090009`
- **Project/Repo**: Vpp-Infrastructure
- **Pipeline**: ADO buildId=1616964 (Myriad - VPP)
- **Priority**: "Today is fine" (low urgency)
- **Bug (reporter)**: "mFRR-Activation on Sandbox is missing EventHub consumer."
- **Detail (reporter)**: "Activation mFRR service on sandbox is crash looping due to
  missing consumer group. Triggered the pipeline for the vpp-infrastructure."

## Belief Classification (initial)

- [INFER] mFRR-Activation service is a Kubernetes workload on Sandbox (AKS/OpenShift
  in MC), consuming from an Azure Event Hub. Basis: VPP platform norms + crash-loop
  terminology, not yet probed.
- [INFER] Missing consumer group = Event Hub consumer group resource absent in IaC
  declaration or not deployed to Sandbox env.
- [UNVERIFIED[assumption: pipeline buildId=1616964 deploys the missing consumer group,
  boundary: pipeline scope covers the owning Terraform module]]
- [UNVERIFIED[unknown: exact Event Hub namespace + event hub name + expected consumer
  group name — no probe yet]]

## Competing Hypotheses (≥2 required — keeping 3)

H1 (reporter): Event Hub consumer group resource genuinely absent from deployed
  Sandbox state; pipeline will reconcile on next successful apply. **Falsifier**:
  `az eventhubs eventhub consumer-group list` in Sandbox returns the expected group
  name that the service pod is configured to use.

H2 (config drift / secrets): Consumer group exists but service pod cannot reach it —
  wrong connection string, wrong namespace, RBAC missing, network policy, or env-var
  mismatch. Crash loop then looks identical from service logs. **Falsifier**: pod
  logs show "ConsumerGroupNotFound"-class error (H1) vs auth/connectivity error (H2).

H3 (deployment race): Consumer group is declared in IaC but targeted with wrong
  env (dev≠sandbox), feature flag, or module was disabled in sandbox.tfvars.
  **Falsifier**: grep MC-VPP-Infrastructure for event hub consumer group resources
  + sandbox tfvars inclusion; pipeline logs for buildId=1616964 show whether the
  consumer group was created on this apply.

## Verification Path (initial)

1. Harvest Slack thread `C063SNM8PK5/p1776781493090009` for additional context
   (who, when, impact, prior attempts) → `/eneco-oncall-intake-slack`.
2. Probe Sandbox: AKS/OpenShift pod status + logs, Event Hubs consumer group list,
   IaC declaration of the consumer group → `/eneco-oncall-intake-enrich`.
3. Read ADO pipeline buildId=1616964 outcome: did Stefan's triggered run succeed,
   and did it create the consumer group resource?
4. Cross-reference: IaC definition (`eneco-platform-mc-vpp-infra` knowledge) vs
   runtime state (Sandbox) to identify the drift source.

## Counterfactual

If this diagnosis is skipped: mFRR-Activation stays crash-looping on Sandbox →
pre-prod testing blocked, Sandbox cannot be used for reserve-market validation →
release train risk for upcoming acc/prod rollouts of mFRR logic.
