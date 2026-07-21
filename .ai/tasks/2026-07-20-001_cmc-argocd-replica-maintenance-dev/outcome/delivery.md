---
task_id: 2026-07-20-001
agent: codex
status: complete
summary: DEV replica maintenance and the unrelated application incident are closed; six reviewed Feynman documents provide the bounded ACC preparation package for Wednesday.
---

# Delivery outcome

## What is complete

- DEV maintenance was observed read-only from the desired Argo CD configuration through workloads, Pods, nodes, serving membership, Applications, resources, events, and time.
- DEV changed from server `1→3`, repo server `1→2`, and standalone Redis to three HAProxy plus three Redis/Sentinel Pods; controller and Dex stayed at one. The final observed sample had all twelve Argo CD Pods Running/Ready with zero restarts.
- The two post-maintenance `Synced Degraded` applications were traced to a separate fail-open delivery chain: missing release variables produced an empty image tag, Helm fell back to `latest`, and the registry had no `latest` manifest. No observed mechanism connected that generator to the Argo CD replica change.
- The six canonical documents now form one route for a zero-context SRE: learn the system, execute the ACC runbook, and record Wednesday in the ACC ledger.
- The ACC preparation snapshot, identity guard, structured sample, negative controls, stabilization logic, and incident carry-over gate are documented and independently reviewed.
- Lens/Freelens was configured last through the installed PowerShell bridge. `cmcfreelens dev` selected/verified DEV and exported the current context; the fresh `file=~\\.kube\\config` row opened the live cluster view. An older duplicate row remained `Unauthorized`, proving a stale-row false negative. CLI evidence stays authoritative.

## Proof ceiling

Complete means **document/source/local-fixture complete plus DEV live evidence**. It does not mean the ACC monitor is activated or Wednesday has succeeded.

Before Wednesday monitoring can start, a human must refresh **ACC** authentication if needed, prove the context-pinned ACC wrapper in the AVD, obtain the signed CMC intent, and capture a fresh T0 baseline. Use `cmcfreelens acc` and open the newly synchronized row rather than a duplicate stale row. Redis functional quorum, end-user transactions, and genuine new-SRE learning remain separate evidence lanes.

## Verification receipt

- six of six Feynman validators passed;
- eleven Mermaid diagrams rendered;
- 27 Bash fences parsed in Bash and zsh and passed ShellCheck;
- the exact current structured sample passed wrong-context/source/freshness/selector/backend/Application regression fixtures;
- relative links and tested secret-shaped-value checks passed;
- operational, goal-fidelity, fresh-reader, and assurance reviews are recorded with no hidden promotion of future evidence.

No cluster-changing command was executed.
