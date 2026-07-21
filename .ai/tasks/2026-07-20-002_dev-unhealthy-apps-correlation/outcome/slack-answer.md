---
task_id: 2026-07-20-002
agent: codex
status: ready-to-send
summary: Concise evidence-backed Slack response for the two DEV application degradations.
---

# Slack answer

I’ve cross-checked this in DEV. This is not related to the Argo CD replica increase.

The root cause is the One-For-All `20260720.1` pipeline. The release variable group did not contain values for `espmessageproducer` or `marketinteraction`; the script treated the unresolved names as shell commands, wrote empty image tags, and still pushed a successful configuration commit. Both Helm charts then fell back from an empty tag to `latest`, but those `latest` images do not exist in ACR. Argo CD correctly auto-synced that configuration, and the new pods failed with `ImagePullBackOff / manifest unknown`; the older `0.158.0` pods remain running.

I verified this with the Application sync history, Deployment/ReplicaSet images, pod events, and the Argo CD control plane. Argo CD itself remains healthy: server `3/3`, repo server `2/2`, Redis HA `3/3`, and all 12 Argo CD pods are Running with zero restarts.
