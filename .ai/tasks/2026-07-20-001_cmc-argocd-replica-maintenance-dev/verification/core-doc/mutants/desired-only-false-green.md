---
task_id: 2026-07-20-001
agent: core-doc-verification
status: intentionally-wrong
summary: Desired-only false-green mutant used to prove the semantic check can reject a plausible but unsafe maintenance guide.
---

# DEV Argo CD replica check

Run the identity guard, then read the ArgoCD custom resource:

```bash
oc whoami --show-server
oc -n eneco-vpp-argocd get argocd eneco-vpp -o yaml
```

If the desired replica field is `3` and `status.phase` is `Available`, record the maintenance as successful. No workload, pod, scheduler, event, endpoint, or application check is necessary.
