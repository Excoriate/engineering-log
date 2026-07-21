---
task_id: 2026-07-20-002
agent: codex
status: complete
summary: Live incident lesson connecting environment identity, green-pipeline false positives, mutable-tag fallbacks, and source-to-runtime causality.
---

# Shared kubeconfig and fail-open generation

- A terminal label is not a context boundary; use the API server as identity proof.
- `Synced Degraded` often means Argo CD applied a bad desired state correctly. Inspect the unhealthy child before blaming Argo CD.
- A successful pipeline is not semantic proof. Missing variables can be converted into valid-looking empty configuration if scripts do not fail closed.
- Helm's `default` can move hidden complexity: an empty tag silently became `latest`, so the source file contained no literal `latest` even though Kubernetes did.
- For causality, connect generator → commit → Application sync → ReplicaSet → pod event. A shared timestamp or two red tiles is not enough.

