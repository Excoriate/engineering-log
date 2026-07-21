---
task_id: 2026-07-20-001
agent: codex
status: complete
summary: Pipeline success, Argo CD sync, and workload health are independent proof surfaces.
---

# Green is not one thing

The post-maintenance application incident exposed a reusable three-layer distinction:

1. A green pipeline means its steps returned success.
2. `Synced` means Kubernetes live configuration matches Argo CD desired configuration.
3. `Healthy` means the resulting resources satisfy Argo CD's runtime health assessment.

The pipeline generated an empty image tag and still succeeded. Helm treated the empty tag as absent and defaulted to `latest`. Argo CD correctly applied the resulting Deployment, so the Application was Synced. The registry lacked a `latest` manifest, so new Pods could not start and the Application was Degraded.

Reusable rule: never use one green surface as proof for another. Validate generated values, desired/live agreement, and runtime realization separately.
