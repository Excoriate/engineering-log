---
task_id: 2026-07-19-003
agent: codex
status: in_progress
summary: Context Universe and lane ledger for the independent fix review.
---

# Context Universe — fix review

## Decision target

Decide whether each prescribed change in `how-to-fix.md` is technically viable and sufficient for Duncan's first-creation outcome, and identify any false path, command, source reference, or unproved runtime claim.

## System and consumer chain

```text
FBE-create ADO pipeline -> Terraform App Configuration/store/keys
                        -> ArgoCD/Helm Deployment
                        -> SecretProviderClass CSI mount
                        -> Kubernetes application-secret
                        -> init-myservice snapshot/appconfig.js
                        -> frontend feature-flag requests
```

Feedback loop: App Configuration recreation changes a connection string; CSI rotation may update the Kubernetes Secret; a rollout mechanism must observe that change and recreate pods; the init container then snapshots the new value. If any event is missed or ordered incorrectly, the pipeline can be green while the frontend retains the stale endpoint.

## Context lanes

| Lane | Surface | Status | Why it matters |
|---|---|---|---|
| Requested fix | `output/how-to-fix.md` | selected | Claims, paths, commands, acceptance promise |
| Mechanism context | `output/rca.md` | selected, context only | Defines the dependency chain; separate reviewer owns mechanism correctness |
| Runtime evidence | `context/live-probe-findings.md` | selected | Only locally available live observations; no new cluster access |
| Pipeline producer | `azure-pipelines-featurebr-env.yml` | selected | Trigger route, stage/job credentials, ordering, blind wait |
| Helm consumer | frontend `templates/deployment.yaml` | selected | Secret mount, init snapshot, annotation placement surface |
| Helm values | frontend Sandbox `values.yaml` | selected | Existing annotations/values knobs and deployment inputs |
| FBE Terraform caller | `terraform/fbe/app-config.tf` | selected | Module ref and key value selected for Key Vault |
| App Config module | `Eneco.Infrastructure/*/terraform/modules/appconfig/{main,output}.tf` | selected | Output existence and ForceNew/value semantics |
| Other adversarial receipts | parent manifest lanes | skipped | Prevent conclusion inheritance and cross-lane contamination |
| Live Sandbox cluster | unavailable | blocked | Required for definitive CSI rotation/Reloader/event-order behavior |
| Network/vendor docs | unavailable and out of scope | blocked | Cannot establish installed CSI/Reloader version semantics from local docs alone |

## Canonical versus derived surfaces

- Canonical source: local ADO clones named by the user.
- Derived proposal: `how-to-fix.md` snippets and line references.
- Consumer/validator: ADO YAML job schema/credentials, Helm render/YAML shape if tooling is available, Terraform static/provider schema evidence if locally available, and ultimately the live Sandbox FBE runtime.
- Blocked residual: no source-only proof can certify that the installed CSI driver updates `secretObjects` on rotation or that Stakater Reloader is installed/configured to watch the namespace.

## Main ambiguity and route-flip falsifier

The key ambiguity is whether P1 is a deterministic wait-for-current-secret followed by restart, or only a time-shifted restart. If the source shows no Kubernetes credentials and no value/resourceVersion discriminator—or the create route does not traverse the job—P1 is broken as written. If both are present for every recreate path, P1 may survive source review, subject to live verification.

## Map delta and history

- Existing task context contains live and source extracts, but the user explicitly requires direct checks against the named files; extracts will not substitute for direct reads.
- Recent path history contains only repository commit `372e933`; the current incident outputs and task artifacts are uncommitted parent work.
- The worktree contains unrelated user changes; this reviewer owns only `context/codex-fix-review-*`, its sentinel, and the exact receipt.
