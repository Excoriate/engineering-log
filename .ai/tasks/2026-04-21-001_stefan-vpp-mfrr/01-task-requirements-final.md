---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Final requirements + verification strategy for Stefan VPP mFRR ticket
---

# Final Requirements

## Goal

Produce a **verified root-cause diagnosis** (depth ≥2: proximate + enabling) of the
mFRR-Activation crash loop on Sandbox, plus a step-by-step remediation plan that the
on-call engineer can execute with read-only verification gates between steps.

## Non-goals

- Running `terraform apply` or any write-path action — this session is diagnosis-only.
- Touching other envs (dev, acc, prd) — scope is Sandbox.
- Fixing unrelated tickets (Erik ArgoCD sandbox access is a different ticket).

## Acceptance Criteria

A complete deliverable in `$T_DIR/outcome/diagnosis.md` containing:

1. **Identity** (FACT): exact Event Hub namespace / event hub name / expected consumer
   group name, cited to file:line or Azure CLI output.
2. **Mechanism** (FACT): crash-loop cause confirmed by runtime signal — pod log
   error class captured verbatim, mapped to the specific failure mode.
3. **Root-cause depth ≥2**: proximate cause (what the pod sees) + enabling cause
   (why the environment is in that state — IaC omission, env-var mismatch, failed
   apply, etc.).
4. **Blast radius**: Sandbox only? Any risk of recurrence in acc/prd if same config
   path? Any cross-service impact (e.g., BTM, other mFRR components)?
5. **Fix plan**: ordered, idempotent steps with per-step read-only verification
   falsifier, rollback note, and authority required (who runs what).
6. **Independent adversarial review** by `socrates-contrarian` OR `el-demoledor`
   (not by coordinator; NN-6 rule).
7. **Residual risk / UNVERIFIED[unknown]** list — anything that could not be probed
   from this session must be stated explicitly with the missing capability.

## Verification Strategy

| What | How | Who |
|---|---|---|
| Slack thread content + list record | `/eneco-oncall-intake-slack` harvests `C063SNM8PK5/p1776781493090009` and list `Rec0AU7GAKAJH`; captures reporter, impact, prior attempts | Slack intake skill |
| ADO pipeline outcome | Read buildId=1616964 logs + stage outcomes via `github-magician`/`/azure-devops-pipeline-debugger` equivalent or enrich-skill Azure DevOps MCP | pipeline debugger |
| IaC declaration of consumer group | Grep MC-VPP-Infrastructure for `azurerm_eventhub_consumer_group`, sandbox tfvars inclusion, module call sites | `/eneco-platform-mc-vpp-infra` + `archeologist` for history |
| Runtime Event Hub state | `az eventhubs eventhub consumer-group list --namespace <ns> --eventhub <eh>` on Sandbox | `/eneco-oncall-intake-enrich` read-only Azure CLI probes |
| Pod crash-loop log line | `kubectl logs` (or ArgoCD) on mFRR-Activation Sandbox pod — **most discriminating signal**: `ConsumerGroupNotFound` vs auth vs network vs config | `/eneco-oncall-intake-enrich` |
| Service config (expected CG name) | Read mFRR service appsettings / ConfigMap / helm values for `EventHub:ConsumerGroup` binding | `/eneco-context-repos` locate repo; enrich reads config |
| Fix plan rigor | Adversarial pass: socrates-contrarian on the fix plan + el-demoledor on silent-failure modes | subagent dispatch |

## Falsifier Changes (vs initial)

- Initial had 3 hypotheses (H1 reporter / H2 drift / H3 race). **Change**: the pod
  log line is promoted to THE single discriminating falsifier between H1/H2/H3 —
  all three produce "crash loop" symptom but different log class. Phase 4 MUST
  capture this signal; anything else is secondary evidence.
- Added H4: **image/deployment change unrelated to consumer group**. Possible if
  the Helm chart or container image rolled to a version that references a renamed
  consumer group (consumer group was fine, service changed). Falsifier: compare
  current deployed image/config revision with last-known-good on Sandbox.
- Added requirement: blast radius analysis (was not in initial).
- Added requirement: per-step verification falsifier + rollback per fix step.

## Routing Commitment

- **Phase 4 (context)**: invoke `/eneco-oncall-intake-slack` (primary) →
  `/eneco-context-repos` (locate mFRR service repo) → `/eneco-context-docs`
  (Event Hub consumer group conventions).
- **Phase 7 (execute)**: invoke `/eneco-oncall-intake-enrich` with the handover.
- **Phase 8 (verify)**: dispatched `socrates-contrarian` for adversarial pass
  (EVALUATOR:y, CRUBVG≥4, executor ≠ verifier).
- **Memory**: Phase-8 consolidation via `/2ndbrain-memory-consolidate`; checkpoint at
  Phase-4→5 and Phase-7→8 transitions.

## Phase 2 → Phase 3 transition

Phase 2 revealed that the ticket's material antecedents are entirely external
to this repo (Slack thread + ADO pipeline + MC-VPP-Infrastructure + mFRR service
repo). The coordinator must not self-fetch external systems (NN-4); every Phase 4
question maps to a delegated skill. The most dangerous unknown remains the pod
log line — everything else is inference until that is captured.

"What was I most wrong about?" — Initial pre-flight framed reporter's diagnosis
as a single hypothesis to confirm. Correct framing: three different mechanisms
produce identical surface symptom; the *discriminator* is the log line, not the
Event Hub state. If we probe CG state first and find it missing, we still cannot
rule out H2 (drift with stale service config) without the log line.
