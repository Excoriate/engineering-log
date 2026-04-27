---
task_id: 2026-04-26-001
agent: coordinator
status: draft
summary: Initial pre-flight + requirements for verifying mFRR activation CrashLoopBackOff diagnosis and applying fix on VPP-Infrastructure worktree.
---

# 01 — Task Requirements (Initial)

## Pre-Flight (mirror)

- **Phase**: 1 | **Brain**: 67.4.0 | **task_id**: 2026-04-26-001
- **Request**: Verify the existing diagnosis at `systemic-diagram-and-verified-diagnosis.md` for an mFRR activation pod CrashLoopBackOff in sandbox; if confirmed, apply the IaC fix on the prepared VPP-Infrastructure worktree branch `2026-04-24-ootw-fix-mfrr-activation-crashloop`; produce three explanatory deliverables (`explanation-of-fix-and-issue-holistic.md`, `pr-description.md`, `slack-response.md`).
- **USER PRE-FRAMING**: Phrases used: "check it, and confirm it" / "full, holistic understanding" / "step by step fix" / "I can also replicate the diagnosis" / "Simple, clear, comprehensive, complete". My read: NOT minimizing — explicit demand for verification rigor and reproducibility, while still asking for clean, clear deliverables. Phase gates remain in force.
- **DOMAIN-CLASS**: investigation (verify diagnosis) → implementation (terraform tfvars edit) → knowledge (3 deliverables). Primary verb `verify` then `fix`.
- **ROOT-ARTIFACT**: n. The tfvars edit is in-scope sandbox config; the deliverables are task-scoped explanations, not shared brain/harness.
- **CRUBVG**: C=2, R=1, U=2, B=1, V=1, G=2 — Total **9 (+1 for G≥1) = 10**. HIGH.
  - C=2 — cross-repo: Eneco.Vpp.Core.Dispatching (helm/SDK) ↔ VPP-Infrastructure (terraform) ↔ VPP.GitOps (ArgoCD) ↔ VPP-Configuration (helm app-of-apps) ↔ Pipeline 1413.
  - R=1 — terraform-add of consumer group + blob container is reversible by removing entries, but apply touches sandbox; not trivial.
  - U=2 — must verify that "activation-mfrr" is genuinely absent from sandbox.tfvars, on the right Event Hub, that the Terraform module derives blob container name from consumer group name, and that nothing else creates it.
  - B=1 — sandbox only.
  - V=1 — `terraform plan` plus pod-status are deterministic falsifiers.
  - G=2 — no canonical IaC↔SDK contract doc available locally; cross-repo coupling is undocumented.
- **System view**:
  - Consumers: TenneT (external REST), mFRR Dispatcher pods (Event Hub consumers).
  - Operators: on-call (Stefan); platform team owning VPP-Infra.
  - Boundaries: L4 ↔ L3.5 ↔ L3; IaC ↔ runtime; sandbox.tfvars ↔ module instantiation; consumer-group-name (string) ↔ blob-container-name (string).
  - Time: SDK invariant is checked at pod startup (boot-time crash, not runtime).
  - Derived surfaces: pipeline 1413 plan/apply state, ArgoCD synced helm release, blob-container existence, consumer-group existence.
- **Counterfactual**: If I skip verification and apply the user's diagnosis as-is, I risk: (a) wrong consumer-group string variant, (b) wrong Event Hub (not `dispatcher-output-1`), (c) wrong tfvars file (sandbox vs another env), (d) the resource is created elsewhere (helm/argocd) and adding it in TF causes conflict, (e) Terraform module does NOT auto-derive container name from consumer group name (separate decoupled list). Each of these silently breaks the fix or creates plan churn.
- **Hypotheses**:
  - **H1** — User diagnosis is correct: missing `"activation-mfrr"` in `sandbox.tfvars` `dispatcher-output-1.consumerGroups`, and the TF module auto-creates a matching blob container. *Eliminate-if*: the entry already exists, OR the module does not bind container-name to consumer-group-name, OR another Event Hub owns this consumer group.
  - **H2** — Diagnosis is structurally right, parameter is wrong (different Event Hub, different env-tfvars, different consumer group string, or container created in a separate decoupled list). *Eliminate-if*: tracing module + tfvars proves a direct 1:1 binding to `"activation-mfrr"` on `dispatcher-output-1` in `sandbox.tfvars`.
  - **H3** — Diagnosis is wrong: root cause is RBAC on the storage account, missing storage account, helm values pointing to a non-matching consumer group name, or network policy. *Eliminate-if*: (i) cited pod logs match `Azure.RequestFailedException: ContainerNotFound` and (ii) IaC trace shows the binding from tfvars → consumer-group resource → blob-container resource.
- **Triggers**: LIBRARIAN: n (defer — Azure SDK behavior is described; Phase 4 may add Context7 if container-naming convention needs canonical confirmation) | CONTRARIAN: y (CRUBVG≥5, review domain) | EVALUATOR: y (CRUBVG≥4, actionable deliverable, root-cause claim) | COGNITIVE: n (not a brain/prompt failure) | DOMAIN: y (terraform-code-hcl-expert at edit time; investigation-specialist at verification time; el-demoledor for fix break-attempt) | TOOLS: n.
- **BRAIN SCAN**:
  - Most dangerous assumption: "the Terraform module ties blob-container-name 1:1 to the consumer-group-name string declared in `dispatcher-output-1.consumerGroups`."
  - Falsifier/probe: read the relevant TF module under `VPP - Infrastructure` (likely `terraform/modules/eventhub*` or similar) and locate either `azurerm_storage_container` with `name = each.value.consumer_group_name` (or a `for_each` loop derived from the consumer-groups input). If the container is named differently, or if it lives outside this module, the fix string changes.
  - Likely failure if wrong: the tfvars hunk creates the consumer group but no blob container, the SDK still throws `ContainerNotFound`, the crashloop persists, and the PR ships a half-fix.

## Source-of-Truth References

- Diagnosis under verification: `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_04_21_stefan_vpp_infrastructure_mfrr/systemic-diagram-and-verified-diagnosis.md`
- VPP-Infra worktree (fix lives here): `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/VPP - Infrastructure/2026-04-24-ootw-fix-mfrr-activation-crashloop`
- Companion repos (read-only context): `Eneco.Vpp.Core.Dispatching`, `VPP.GitOps`, `VPP-Configuration` under `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/`

## Deliverables

1. IaC fix: tfvars edit on the existing worktree (no git push without explicit authorization; bundled-authorization is forbidden by NN-4).
2. `explanation-of-fix-and-issue-holistic.md` in the on-call shift folder — full, repo-by-repo explanation with diagrams, sufficient to teach and replicate.
3. `pr-description.md` in the on-call shift folder — production-grade PR description (problem, root cause, fix, blast radius, verification).
4. `slack-response.md` in the on-call shift folder — short, clear update for the team thread.

## Acceptance (initial — refined in Phase 3)

- All three hypotheses elimination-conditioned with evidence (FACT/INFER) before plan execution.
- Terraform `plan` (or staged HCL diff if plan unavailable) shows ONLY the expected adds: 1 consumer group + 1 blob container, both keyed on `"activation-mfrr"`.
- All deliverables cite file paths or evidence; no hand-wavy prose.
- No git mutations on any repo without explicit per-class authorization.
