---
task_id: 2026-07-20-002
agent: codex
status: diagnosis-complete-no-fix
summary: Both DEV applications failed their new image rollout because the configured latest tags do not exist; no causal link to the Argo CD replica maintenance was observed.
---

# SRE intake

## Identity ledger

- Environment/API: DEV, `https://api.eneco-vpp-dev.ceap.nl:6443`.
- Applications: `espmessageproducer-eneco-vpp`, `marketinteraction-eneco-vpp`.
- Namespace: application objects in `eneco-vpp-argocd`; workloads in `eneco-vpp`.
- Shared desired-state revision: `VPP-Configuration` commit `b219de782de8ad12c234fd809b964ca4d11514af` plus Helm chart versions `0.2.0` and `0.3.0` respectively.

## Mechanism

The One-For-All `20260720.1` pipeline used a release variable group that lacked both service variables. Its generated Bash treated unresolved `$(service)` tokens as command substitutions, wrote empty image tags, and still pushed revision `b219de...`. Both charts default an empty tag to `appVersion: latest`; ACR has no matching `latest` manifests, so the new pods entered `ImagePullBackOff`. Old `0.158.0` ReplicaSets remained Ready.

## Read-only proof

- `oc whoami --show-server`
- `oc -n eneco-vpp-argocd get applications.argoproj.io espmessageproducer-eneco-vpp marketinteraction-eneco-vpp -o wide`
- `oc -n eneco-vpp get deploy espmessageproducer-eneco-vpp marketinteraction-eneco-vpp -o wide`
- ReplicaSet and pod selection by each application's labels/template hash.
- `oc -n eneco-vpp describe pod <new-marketinteraction-pod>` and the Argo CD UI detail for the new espmessageproducer pod.
- `oc -n eneco-vpp-argocd describe application <name>` for source revisions and automated-sync events.
- Argo CD Deployments, StatefulSets, and pods for maintenance-plane stability.

## Human decision gates

- No fix was authorized or performed.
- Application/configuration owner must first prove which immutable image tags exist, then select the intended recovery tags/digests.
- Pipeline owner should fail the build on missing/empty release variables; chart owner should remove or guard the fail-open `latest` fallback.
- Do not force a new sync until the desired reference resolves; another sync cannot create a missing registry artifact.
- Close only after new pods are Ready and both Applications are `Synced Healthy`.
