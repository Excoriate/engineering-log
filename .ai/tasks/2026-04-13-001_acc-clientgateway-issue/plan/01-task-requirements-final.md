---
task_id: 2026-04-13-001
agent: coordinator
status: draft
summary: Final requirements for ACC ClientGateway release issue investigation
---

# Task Requirements — Final

## Change from Initial
- **Added**: ADO repo access is REQUIRED (ClientGateway not available locally)
- **Added**: Must use eneco-tool-tradeit-mc-environments skill for Azure access
- **Refined**: Investigation must be parallelized with adversarial agents from the start

## Counterfactual (refined)
If not done: ACC environment broken → release pipeline blocked → production release delayed. If root cause is latent in prod config too, production risk exists.

## Competing Hypotheses (unchanged — need Phase 4 evidence to prune)
- **H1 (Config/Infra)**: Infrastructure misconfiguration in ACC exposed by release
- **H2 (Code Regression)**: Breaking code change in ClientGateway release
- **H3 (Environment Drift)**: ACC env not ready for the release (stale deps, expired certs, missing migrations)

## Requirements
1. Read incident antecedents (file + screenshot) to identify exact error + service
2. Use eneco-context-repos to find and examine ClientGateway repo + recent changes
3. Use eneco-tool-tradeit-mc-environments to access ACC Azure environment
4. Trace the release pipeline to identify what changed
5. Confirm root cause with FACT-level evidence (command output, logs, config diffs)
6. Adversarial validation via sre-maniac + el-demoledor + sherlock-holmes (parallel)
7. Produce RCA document with visual aids + actionable fix

## Verification Strategy
- **Acceptance**: Root cause identified with FACT evidence (file:line, command output, Azure state)
- **Verify-how**: Adversarial challenge by >=3 independent agents; each must confirm or provide counter-evidence
- **Who-verifies**: sre-maniac validates operational diagnosis; el-demoledor stress-tests the fix proposal; sherlock-holmes independently investigates alternative causes
- **Blind criteria**: (1) Can the fix be executed without ambiguity? (2) Does the root cause explain ALL observed symptoms? (3) Is there evidence ruling out each non-root-cause hypothesis?
