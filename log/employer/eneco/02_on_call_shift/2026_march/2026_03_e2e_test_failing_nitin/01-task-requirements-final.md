---
task_id: 2026-03-23-001
agent: coordinator
status: complete
summary: Final requirements for E2E test failure root cause validation
---

# Task Requirements (Final)

## Changes from Initial (Phase 2 evidence)
1. **VRE is NOT a separate project/repo** — no "VRE" project, repo, or pipeline found in ADO org `enecomanagedcloud`. VRE is likely a test scenario/component within VPP. This invalidates any assumption that VRE has its own pipeline infrastructure.
2. **E2E pipelines identified**: Only "Behind The Meter - E2E" and "B2B Behind The Meter - E2E tests" — need to verify which (if any) is the failing pipeline, or if VRE tests run in `platform.test.vpp`.
3. **Test repos narrowed**: `platform.test.vpp`, `Eneco.Vpp.Core.Testing` are candidates for containing VRE E2E tests.
4. **Falsifier change**: Initial assumed VRE pipeline lookup; now falsifier must determine WHERE VRE tests actually execute.

## Objective
Read the engineering log investigation (Phase 4), extract every factual claim, and verify each independently against live Azure/ADO/repo state. Produce CONFIRMED/REFUTED/INCONCLUSIVE per claim.

## Verification Strategy
### Acceptance Criteria
- Every claim in the investigation is extracted and classified
- Each claim has an independent verification action designed
- Each verification produces live evidence (command output, API response, file content)
- Final report maps claim → evidence → verdict with no gaps

### Verify-How
| Claim Type | Verification Method |
|---|---|
| Pipeline failure | `az pipelines runs list` + `az pipelines runs show` with logs |
| Code/hook issue | Repo inspection via `az repos show` + file content via API or clone |
| Infrastructure issue | `az resource show` / `az monitor` queries |
| Configuration issue | Pipeline variables, app config, repo config inspection |
| Timeline claim | Git log, pipeline run timestamps, ADO work item history |

### Who-Verifies
- **Executor**: Coordinator + sherlock-holmes subagent (for investigation validation)
- **Verifier**: socrates-contrarian subagent (MANDATORY, CRUBVG=8 >= 5)
- **Evidence collector**: Coordinator via az cli + ADO API

## Competing Hypotheses (updated)
1. **H1**: Investigation correctly identifies BeforeFeature hook failure as root cause
2. **H2**: BeforeFeature hook failure is a symptom; root cause is infra/config in the pipeline or test environment
3. **H3**: Investigation is partially correct but there are additional contributing factors not documented

## Counterfactual (updated with Phase 2 evidence)
Without this verification: ticket closes on claims about a "VRE BeforeFeature hook failure" but we don't even know WHERE VRE tests run. The very first claim (which pipeline/repo) could be wrong. Risk of recurrence is HIGH because the wrong system might get the fix.

## Constraints
- Read-only verification — no changes to any system
- Must use live az cli / ADO API / GitHub API for evidence
- Contrarian challenge mandatory (CRUBVG >= 5)
- 295 total lines in investigation — coordinator can self-read in Phase 4
