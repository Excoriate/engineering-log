---
task_id: '2025-12-22-001'
type: 'scratchpad'
description: 'File role: Cognitive capture for LEARNINGS. Task context: 5 lessons, 3 realizations, key insight about finalizers.'
last_updated: '2025-12-22 12:30'
---

# Scratchpad

## Lessons

| When | What Happened | Root Cause | Prevention |
|------|---------------|------------|------------|
| [2025-12-22 10:50] | ArgoCD CLI failed with "server address unspecified" | Subagent didn't know CLI was already logged in | Pass server flags: `--server argocd.dev.vpp.eneco.com --grpc-web` |
| [2025-12-22 11:00] | `argocd app get alarmengine` permission denied | Child apps require elevated permissions | Use kubectl: `kubectl get applications.argoproj.io -n afi` |
| [2025-12-22 11:15] | Pipeline shows "succeeded" but no pods | Pipeline verifies API acceptance, not deployment completion | Add health check: `argocd app wait --health` in pipeline |
| [2025-12-22 11:20] | Namespace stuck in Terminating for 6 days | 5 Applications with stuck finalizers | Monitor finalizer age, alert if >1h |
| [2025-12-22 11:30] | ArgoCD controller healthy but ignoring stuck apps | Controller "forgot" about orphaned finalizers | Investigate controller logs at deletion time |

## Realizations

- [2025-12-22 11:10] Kubernetes namespace deletion is NOT atomic - it depends on ALL children completing their finalizers
- [2025-12-22 11:15] The `resources-finalizer.argocd.argoproj.io` is ArgoCD's contract: "I'll clean up managed resources before you delete me"
- [2025-12-22 11:25] GitOps is "fire and forget" by default - verification is not built-in, must be added explicitly

## Important Codebase Places

| Location | Why Important |
|----------|---------------|
| `log/employer/eneco/troubleshooting/cicd-green-but-failed-error/investigation-report.md` | Main deliverable with 11 evidence-backed claims |
| `log/employer/eneco/troubleshooting/cicd-green-but-failed-error/initial-antecedents.md` | Original context from user report |

## User Corrections

- [2025-12-22 11:45] User: "linus torvals wise, rigorous, and complete" → Applied: Rewrote report with technical depth, ASCII diagrams, verification commands
- [2025-12-22 12:00] User: "everything needs to be backed up by evidence" → Applied: Added Section 3 with 11 claims, each with command + expected output + rationale
- [2025-12-22 12:30] User: "Ignore the markdown linter issues" → Applied: Stopped fixing lint warnings, focused on memory protocol

## Notes

Key commands for future similar investigations:

```bash
# Check if namespace is stuck
kubectl get ns <ns> -o jsonpath='{.status.phase}'

# Find stuck finalizers
kubectl get ns <ns> -o json | jq '.status.conditions'

# Get Application CRDs with finalizers
kubectl get applications.argoproj.io -n <ns> -o json | \
  jq '.items[] | {name: .metadata.name, finalizers: .metadata.finalizers, deletionTimestamp: .metadata.deletionTimestamp}'

# Remove finalizer (remediation)
kubectl patch application <app> -n <ns> -p '{"metadata":{"finalizers":null}}' --type=merge
```
