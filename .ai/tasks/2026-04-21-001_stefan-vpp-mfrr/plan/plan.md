---
task_id: 2026-04-21-001
agent: claude-code
status: complete
summary: Investigation + remediation plan for Stefan's mFRR-Activation Sandbox ticket with adversarial challenge
---

# Plan — Diagnose & Remediate mFRR-Activation Crash Loop on Sandbox

## Phase 4 → 5 transition

Phase 4 revealed:
1. Reporter (Stefan) is on vacation — self-diagnosis must be treated as INFER, and no direct confirmation is possible.
2. Parent thread is empty; the full ticket body is only the 619-byte `slack-antecedents.txt`.
3. Sandbox topology is **Azure AKS, not OpenShift** — tooling differs from dev-mc/acc/prd.
4. The same consumer-group-via-Terraform pattern was previously executed by Stefan himself (Oct 2025 PR 144873).
5. There is a **weak but non-zero temporal link** to the Apr 16 unresolved "activation service is red" thread (P3) — cannot be ignored.
6. The single highest-information probe is the pod's first-failing log line; it partitions H1/H2/H3 immediately.

"What was I most wrong about?" — Initial framing treated Event Hub live state (F1) as primary. Correct framing is **pod log (F4) first, then F2 (service config), then F1 (EH state), then F3 (pipeline outcome)**. Starting with F1 risks a Terraform PR that creates an unused consumer group if the real problem is config drift (H3).

## End state (backward-chained goal)

```
 mFRR-Activation pod on Sandbox AKS is Running, Ready, restartCount stable,
 successfully consuming from its configured Event Hub consumer group, with:
  (a) the consumer group entity present on the Sandbox EH namespace,
  (b) the entity declared in IaC (VPP-Infrastructure) so state does not
      drift again on the next apply,
  (c) documented root cause + fix in the ticket folder,
  (d) blast radius confirmed Sandbox-only with no prd exposure,
  (e) a clear, low-noise Slack update ready to post when Stefan returns.
```

Preconditions for (a)+(b): F1 negative (CG missing) AND F4 matches H1 AND F2 matches C2 AND F3 resolves to either "pipeline created CG" or "PR needed".
Silent-failure modes to guard against:
- Creating the CG in IaC while the service is actually failing for H2 reasons → Terraform "succeeds" but pod still crashes → diagnosis appears fixed but isn't.
- Pipeline succeeds but does not declare the CG (missing resource block) → operator assumes fixed, pod stays crashed.
- CG name mismatch (H3) → Terraform adds one CG, service reads a different one → same end state as before.

## Plan steps

### Step 1 — Run the enrich skill / operator runbook (Phase 7)

**Objective**: execute the four-part handover's Probes (Stages A–E) read-only and capture evidence to `$T_DIR/verification/`.

**Route**: invoke `/eneco-oncall-intake-enrich` with the handover-contract.md input. If enrich cannot authenticate to Sandbox in this session, emit the same probe list as a runbook the operator executes manually; enrich's role becomes evidence synthesis rather than probe execution.

**Acceptance**: every probe in Stages A–B executed or recorded as `[UNVERIFIED[blocked: auth/access]]`; F4 log line captured verbatim OR explicitly named as the next manual action.

**Discriminating falsifier (Step 1 itself)**: if Stage B returns a log line that does NOT match H1/H3 patterns (i.e. auth, network, unrelated app-level error), this plan's entire premise is wrong → STOP, re-enter Phase 3, rewrite the plan for the actual failure class.

**Rollback**: N/A (read-only).

**Blast radius**: zero — no writes.

---

### Step 2 — Classify the log line, confirm or disconfirm H1

**Objective**: decide among H1 (IaC gap) / H2 (auth/net) / H3 (config drift) / H4 (release-tied config).

**Mechanism**: compare the verbatim log line from Stage B to the three authoritative patterns (EventHubs ResourceNotFound vs Unauthorized vs Socket/DNS).

**Acceptance**: a single classification decision is entered in `verification/enrich-log-classification.md` with the verbatim line, path (if present), and the `cgname` it references.

**Discriminating falsifier**: if more than one class fits, add Step 2a — re-run pod with increased log verbosity, or request Sandbox AKS operator check `kubectl describe pod` for additional exit-reason signal. Do NOT proceed to Step 3 until classification is unique.

**Rollback**: N/A.

**Blast radius**: zero.

---

### Step 3 — Branch on classification

| Classification | Next step | Rationale |
|---|---|---|
| H1 / H3 (ResourceNotFound) | Step 4 (IaC / config reconciliation) | Expected path per reporter's self-diagnosis |
| H2 (auth) | Branch to a new investigation (managed identity / service principal / network) — out of this plan's scope; return to Phase 3 | Different root cause class; different skill routing (probably `neo-hacker` + `eneco-platform-aad`) |
| H2 (network) | Branch to network investigation (NSG / private endpoint / DNS / firewall) — out of this plan's scope | Different expertise + probes needed |
| H4 (release-tied) | Step 4a — reconcile with `Eneco.Vpp.Core.Dispatching` release/R146 + check Apr 16 thread resolution before touching IaC | Fix must cover both the CG creation AND the service config sync |

---

### Step 4 — (H1) Determine whether buildId=1616964 creates the missing CG (F3)

**Objective**: read Stefan-triggered pipeline's Terraform plan/apply stages to decide whether the IaC already declares the resource or a PR is needed.

**Mechanism**: read pipeline stage outcomes; specifically the `terraform plan` stage targeting Sandbox. Grep for the missing CG name in the `+ azurerm_eventhub_consumer_group...` block.

**Acceptance**: `verification/enrich-pipeline-outcome.md` names one of three explicit states:
- S4.A: **Pipeline succeeded AND plan included the CG creation AND apply completed** → proceed to Step 5 (verify + restart pod).
- S4.B: **Pipeline succeeded but plan did NOT include the CG** (no drift detected by Terraform) → the IaC does not declare this CG yet. Proceed to Step 6 (draft IaC PR).
- S4.C: **Pipeline failed** → dispatch `/azuredevops:azuredevops-pipeline-logs-analyze`; do not attempt remediation until pipeline failure is understood.

**Discriminating falsifier**: if the pipeline's plan stage cannot be read (permissions, ADO outage), record `[UNVERIFIED[blocked]]` and fall back to treating state as S4.B (safer default — assume PR needed; do not assume the pipeline silently fixed it).

**Rollback**: N/A (read-only).

**Blast radius**: zero.

---

### Step 5 — (S4.A path) Verify CG exists; restart the pod

**Objective**: confirm Terraform apply created the CG; force the Sandbox pod to restart to pick up the now-existent resource.

**Commands (operator runs)**:
```bash
# 5a. Confirm CG existence post-apply (repeat F1):
az eventhubs eventhub consumer-group list --subscription <sandbox-sub> \
  -g <rg> --namespace-name <ns> --eventhub-name <eh> -o table
#     Expect: <cg-name> present.

# 5b. Rollout restart:
kubectl -n <ns> rollout restart deployment/<activation-deploy>
kubectl -n <ns> rollout status deployment/<activation-deploy> --timeout=300s

# 5c. Check pod health:
kubectl -n <ns> get pod -l app=<activation-label> -o wide
kubectl -n <ns> logs <new-pod> --tail=100 | grep -iE "PartitionInitializing|ConsumerGroup|Error"
```

**Acceptance**: CG present in 5a; rollout completes healthy in 5b; logs in 5c show `PartitionInitializingAsync` (Azure SDK success signal) and NO `EventHubsException` in the last 100 lines.

**Discriminating falsifier**: if the pod still crash-loops after restart despite CG existing, either the service configured CG name ≠ IaC-created name (H3 still latent), or there is another failure layered on top. Re-classify and loop back to Step 2.

**Rollback**: `kubectl rollout undo deployment/<activation-deploy>` reverts the restart (the previous replica-set comes back). Safe because neither the Helm chart nor the image changed.

**Blast radius**: Sandbox-only; non-prod; pod restart is normal operational action.

**Authority required**: whoever owns kubectl write-access on Sandbox AKS (on-call or Core team).

---

### Step 6 — (S4.B path) Draft Terraform PR against VPP-Infrastructure

**Objective**: declare the missing `azurerm_eventhub_consumer_group` so the next Sandbox apply reconciles state.

**Mechanism**: locate the existing event-hub module / resource block that owns `<eh-name>` on Sandbox and add the consumer group child. Template (exact addresses depend on IaC structure — verify module layout first):

```hcl
# In the file where the event hub is declared (or the module call site):

resource "azurerm_eventhub_consumer_group" "mfrr_activation" {
  name                = "<cg-name-from-F2>"                      # must match service config exactly
  namespace_name      = azurerm_eventhub_namespace.vpp_sbx.name  # or module output
  eventhub_name       = azurerm_eventhub.<eh-tag>.name           # or module output
  resource_group_name = azurerm_resource_group.vpp_sbx.name
}
```

**Acceptance**:
- PR opened against `VPP - Infrastructure` targeting the branch that deploys to Sandbox (typically `main`, per Roel's FTO thread 2026-04-20: "main = mainline to sandbox").
- PR body cites Stefan's ticket (list URL), the F4 log line, and the F1 state showing the missing CG.
- Terraform `plan` in the PR pipeline shows exactly one `+ azurerm_eventhub_consumer_group` with `name = "<cg-name-from-F2>"` and NO other changes.
- Reviewer is a Core team member (Alexandre Freire Borges, Artem Diachenko, or Hein Leslie — NOT Stefan, he's on vacation).

**Discriminating falsifier**: if `terraform plan` shows additional unexpected changes, the branch has drifted; STOP, do not merge, investigate drift separately.

**Rollback**:
- Pre-merge: close PR, no impact.
- Post-merge pre-apply: `git revert` + new PR.
- Post-apply: `terraform destroy -target azurerm_eventhub_consumer_group.mfrr_activation` + git revert. The consumer group has no persistent state beyond checkpoint blobs; destroying it resets offsets but this is Sandbox (acceptable).

**Blast radius**: Sandbox only (branch + pipeline scoped). Zero prd risk because the same apply pattern is env-gated. Verify by confirming `configuration/sandbox-*.tfvars` (or equivalent) is the only env file touched.

**Authority required**: Core team developer (Sandbox IaC write) + Platform team approver (Terraform apply approval gate per Eneco policy).

---

### Step 7 — Confirm blast radius (F5 + F6) regardless of fix path

**Objective**: before closing, verify this is genuinely Sandbox-only.

**Commands** (operator runs; OpenShift envs use `oc` via `/eneco-tool-tradeit-mc-environments` login):
```bash
# For each of dev-mc, acc, prd:
az eventhubs eventhub consumer-group list --subscription <env-sub> \
  -g <env-rg> --namespace-name <env-ns> --eventhub-name <env-eh> -o table
# Expect: <cg-name> present in all non-Sandbox envs.

oc -n <env-ns> get pod -l app=<activation-label> -o wide
# Expect: Running, restartCount stable.
```

Rootly check via `/eneco-tools-rootly`:
- `list_incidents` with keyword `mfrr` or `activation` in last 14 days
- `listAlerts` touching sandbox or non-Sandbox `eneco-vpp` namespace

**Acceptance**: all non-Sandbox envs healthy; no prd Rootly alert tied to this class.

**Discriminating falsifier**: if any non-Sandbox env shows CG missing or activation pod unhealthy, this is a wider regression — stop closing, page Core team lead (Hein Leslie), re-scope as a real incident not a DX ticket.

**Rollback**: N/A (read-only).

**Blast radius**: zero.

---

### Step 8 — Document + park communication

**Objective**: leave the ticket in a state a returning Stefan can pick up.

**Outputs**:
- `$T_DIR/outcome/diagnosis.md` — final diagnosis (root cause, evidence, fix, blast radius, residual risk).
- `$T_DIR/outcome/slack-reply-draft.md` — reply to the `#myriad-platform` parent thread (single message, no ping to Stefan since he's on vacation; mention Core team stand-in if escalation path triggered).
- Commit artifacts to the engineering-log repo under `log/employer/eneco/02_on_call_shift/2026_04_21_stefan_vpp_infrastructure_mfrr/` so future sessions can find the record.

**Posting policy**: operator (Alex) decides whether to post the Slack reply. Do not auto-post.

**Acceptance**: both files exist, content passes the "no AI tells" check (no "happy to dig deeper", no "let me know", no "hope this helps").

---

## Adversarial Challenge

This section references Phase 4 canonical failures + Phase 1 surviving hypotheses and names the downstream consequence of each challenge per the Phase 5 consequence contract.

### Q1 — Which assumption in this plan, if false, causes the worst outcome?

**Assumption**: "Reporter's self-diagnosis (missing CG) is the actual cause." If false, Step 6 (IaC PR) creates an unused Terraform resource + does not fix the pod.
**Consequence in the plan**: Step 2 is elevated to a gate (branching decision) rather than a continuation; Step 6 is predicated on Step 2 returning H1/H3. If Step 2 returns H2, the plan halts and re-enters Phase 3 — this is now explicit in Step 3's branch table.

### Q2 — Simplest alternative approach we haven't taken?

"Ad-hoc `az eventhubs consumer-group create` in Sandbox + restart pod, skip Terraform." Works faster but violates the Feb 2024 platform ADR (consumer groups must be managed in Terraform — Roel, #myriad-platform 2024-02-29). Creates drift that the next apply will either preserve (if tolerated by the module) or destroy (if module enforces a closed set). Not worth the saved 20 minutes.
**Consequence in the plan**: explicitly forbidden by Step 6's path. Ad-hoc is only acceptable if the Core team formally authorizes it as a temporary fix while the PR is in flight; that decision is Core team's, not this skill's.

### Q3 — What evidence would disprove the leading diagnosis?

- F4 log line class ≠ ResourceNotFound / MessagingEntityNotFoundException → H1 disproven.
- F3 pipeline showed an apply that created the CG yet pod still crashes → H1 disproven (CG existed but something else breaks the pod).
- F2 config CG name differs from F1 CG presence (once F1 returns results) → H1 is masked by H3; creating the "missing" CG via IaC is still incomplete until the service config is aligned.
**Consequence in the plan**: Step 5's acceptance requires a post-restart log check, and Step 2's falsifier explicitly asks the question "what log class did we see?" If any of these disprovers trigger, the plan does not proceed past Step 3.

### Q4 — Hidden complexity or dependencies?

- **Sandbox is AKS, not OpenShift** — kubectl commands + auth flow differ from the engineer's MC muscle memory. Must confirm the right kubeconfig context is set before running Step 5b/5c.
- **ADO Terraform apply requires a manual approval gate** for VPP-Infrastructure (per precedent: Alexandre asking for Platform team approvals 2026-02-05). Step 6 cannot merge + apply in one motion; a Platform team member must click approve.
- **CG name case sensitivity**: Azure Event Hubs CG names are case-sensitive. If F2's config value has `"cgw"` but the module template would generate `"CGW"`, the fix fails silently. Step 6's acceptance explicitly requires exact string match.
- **Checkpoint storage** — creating a new consumer group does NOT create its checkpoint blob container; the SDK creates that on first run if permissions allow. If the service's managed identity lacks `Storage Blob Data Contributor` on the checkpoint storage account, Step 5c will show a new failure class. Flag as residual risk.
**Consequence in the plan**: Step 6 acceptance calls out case-sensitivity; Step 5 acceptance checks for secondary errors post-restart; checkpoint storage permission is named as a residual risk in the diagnosis.

### Q5 — Version / existence probes executed (≥1 mandatory)

- [EXECUTED] Live probe of Slack Lists companion mapping for `F0ACUPDV7HU` → `C0ACUPDV7HU` (confirmed via `slack_read_channel`).
- [EXECUTED] Live probe of Stefan's Slack profile → confirmed `:palm_tree: Vacationing` status.
- [EXECUTED] MS Learn live fetch for `EventHubsException.Reason=ResourceNotFound` and legacy `MessagingEntityNotFoundException` — mechanism cited from authoritative source, not memory.
- [DEFERRED to Phase 7] Live probe of `az eventhubs consumer-group list` on Sandbox (requires operator auth).
- [DEFERRED to Phase 7] Live probe of ADO pipeline buildId=1616964 (requires operator auth).

### Q6 — How could this diagnosis pass verification yet be wrong? (Silent-failure mode)

Scenario: **Pipeline buildId=1616964 created a consumer group whose name *almost* matches what the service needs but differs by case or a trailing character (e.g. `mfrr-activation` vs `mFRR-Activation` or a dash-vs-underscore swap).** F1 returns a CG, F3 returns "apply succeeded", Step 5's CG-present check passes, but pod restart still crashes with the identical ResourceNotFound error. Diagnosis report claims "fixed"; operator moves on; ticket lingers.

**Guardrail**: Step 5's acceptance specifically requires `PartitionInitializingAsync` in the post-restart log AND no `EventHubsException` in the last 100 lines — not merely "CG exists". This is the structural defense against the silent-success trap. Additionally, Step 5's falsifier explicitly calls out that a still-crashing pod after restart forces a reclassification back to Step 2, not "try again later."

---

## Downstream consequence named (mandatory — Phase 5 consequence contract)

**Adversarial sweep changed these specific plan elements**:
1. Step 2 promoted from a check to a branching gate with explicit H2/H4 side-exits (from Q1).
2. Step 5 acceptance now requires positive log signal (`PartitionInitializingAsync`), not merely CG presence (from Q6).
3. Step 6 acceptance explicitly flags case-sensitivity (from Q4).
4. Checkpoint storage RBAC named as residual risk in outcome (from Q4).
5. Ad-hoc CG creation explicitly forbidden with reason (from Q2).

If none of these changes had been made and the plan still contained them by accident, the adversarial pass would still have added an explicit "residual risk" entry stating "produced nothing, the plan was already sound on these points." That is not the case here — each of the five items above is a genuine delta.
