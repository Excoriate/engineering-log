---
task_id: 2026-07-20-002
agent: codex
status: active
summary: Read-only live investigation plan with independent causal and operational attacks.
---

# Plan

1. Pin and prove DEV identity. If the server is not `api.eneco-vpp-dev.ceap.nl:6443`, stop and select the DEV context.
2. Capture both Argo CD Application states and revisions. If either is OutOfSync or has comparison/reconciliation errors, expand the GitOps-control-plane hypothesis.
3. Capture workloads, pod container waiting messages, images, and events. If both report registry `manifest unknown`, treat missing image artifacts as the shared immediate mechanism.
4. Capture Argo CD control-plane desired/ready counts, pods, restarts, and recent warnings. If control-plane readiness regressed or reconciliation errors align with the failures, keep the maintenance hypothesis live; otherwise weaken it.
5. Compare timestamps. A post-maintenance timestamp without a mechanism is correlation only.
6. Record finding, proof ceiling, and exact missing ownership/change evidence.

## Adversarial challenges

- Causal attack: could `Synced Degraded` be a consequence of a control-plane change even if the leaf error is registry-related? The discriminator is whether the maintenance altered the desired image reference or merely replica fields.
- Operational attack: could healthy Argo CD component pods hide a reconciliation defect? Application conditions, revisions, and events must be checked separately.
- Verification-method failure: terminal tabs share one kubeconfig; a DEV-labelled tab can query ACC. Every batch reasserts the API identity.
- False-green path: listing Application cards alone can hide the leaf-resource message; pod/container events must supply the mechanism.
- False-blame path: time adjacency can look causal. Causality requires a plausible path from replica change to wrong image reference or failed registry resolution.
- Runtime/version claim: execute `oc whoami --show-server` and live resource queries in the authorized AVD.

## Sidecars

- `codex-sherlock-holmes` isolated causal frame → `subagent-outputs/causal-attack.md`; if it identifies an untested connecting mechanism, add the discriminating probe.
- `codex-sre-maniac` isolated operator frame → `subagent-outputs/operator-attack.md`; if it identifies a false-green control-plane condition, add the probe.
- Slack context lane → `subagent-outputs/slack-context.md`; if an independent application release is reported, downgrade maintenance causation.
- Repo/history context lane → `subagent-outputs/repo-context.md`; if the desired image tag changed with the maintenance commit, strengthen the relation hypothesis.
- Prior-knowledge lane → `subagent-outputs/vault-context.md`; memory remains contextual until live evidence confirms it.

