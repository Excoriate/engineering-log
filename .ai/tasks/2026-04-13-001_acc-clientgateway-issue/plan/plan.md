---
task_id: 2026-04-13-001
agent: coordinator
status: draft
summary: Plan for RCA delivery and fix execution
---

# Plan: ACC ClientGateway Release Issue — RCA + Fix

## Objective
Deliver a confirmed root cause analysis with visual aids and an actionable fix for the ClientGateway version erasure in ACC/DEV environments.

## Acceptance Criteria
1. Root cause document with FACT-classified evidence chain
2. Visual aids explaining the mechanism
3. Actionable fix instructions (step-by-step CLI commands)
4. Adversarial validation by sre-maniac + el-demoledor (received + synthesized)
5. All 3 non-root-cause hypotheses explicitly eliminated with evidence

## verify-strategy
- Phase 3 blind criteria reconciled:
  - (1) "Can fix be executed without ambiguity?" → YES: exact az CLI commands provided
  - (2) "Does root cause explain ALL symptoms?" → YES: empty tag mechanism explains ArgoCD failure
  - (3) "Evidence ruling out non-root-cause hypotheses?" → YES: H2/H3 eliminated with specific evidence
- Verification: adversarial agents confirm/challenge each claim
- Falsifier: if clientgateway variable IS present in Release-0.145, the entire diagnosis is wrong (VERIFIED: it's absent)

## Steps

### Step 1: Synthesize adversarial agent findings
- Wait for sre-maniac + el-demoledor artifacts
- Address each finding: Accept/Rebut/Defer
- Write synthesis to context/

### Step 2: Write RCA outcome document
- Mechanism diagram (Mermaid)
- Evidence table with FACT classifications
- Fix instructions with exact CLI commands
- Recurrence prevention recommendations

### Step 3: Verify fix instructions
- Dry-run validation: confirm az CLI commands are syntactically correct
- Confirm variable value: `clientgateway = 0.145.0` (from CD pipeline build 0.145.0-0.145)

## Adversarial Challenge

### Phase 4 canonical failure addressed:
- "Variable group is the right data source" → CONFIRMED: pipeline YAML line 5 references it directly
- "Image exists in container registry" → CONFIRMED: CD pipeline 1945 succeeded on release/0.145

### Surviving hypotheses from Phase 1:
- H1 confirmed with FACT evidence (variable group missing entry)
- H2 eliminated: no code regression, pipeline script is correct
- H3 eliminated: environment is fine, it's CI/CD data issue

### 6 Questions:
1. **Assumption + failure mode**: Assuming `clientgateway = 0.145.0` is correct. Could fail if CD pipeline produced a different tag format. Falsified by: checking CD build output for exact tag. Evidence: build number `0.145.0-0.145` matches pattern of other services.
2. **Simplest alternative**: Direct git commit to fix values-override.yaml instead of re-running pipeline. Faster but doesn't fix the variable group for future runs.
3. **Disproving evidence**: If clientgateway variable WERE present in group, "command not found" error would not occur. Variable confirmed absent.
4. **Hidden complexity**: Re-running One-For-All touches ALL services, not just clientgateway. Could overwrite manual patches.
5. **Version/existence probes**: EXECUTED — `az pipelines variable-group show --id 5262` confirms absence. CD pipeline 1945 confirms image exists.
6. **Silent failure**: The fix could pass all verification but be wrong IF the container registry tag doesn't match the variable group value format. However, all other services use the same `X.Y.Z` format and they work. The pipeline ALSO doesn't validate that the image exists before writing the tag — this is a pre-existing design limitation, not introduced by our fix.
