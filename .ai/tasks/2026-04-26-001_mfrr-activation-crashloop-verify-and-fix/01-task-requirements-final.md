---
task_id: 2026-04-26-001
agent: coordinator
status: complete
summary: Final requirements after Phase 2 mapping — refines targeting, adds Verification Strategy, narrows hypotheses
---

# 01 — Task Requirements (Final)

## What changed vs initial

| Item | Initial (Phase 1) | Final (Phase 3) | Why it changed |
|---|---|---|---|
| Fix-target path | `VPP - Infrastructure/2026-04-24-...` | `VPP%20-%20Infrastructure/2026-04-24-ootw-fix-mfrr-activation-crashloop/` (literal `%20`) | Phase 2 mapping found the worktree only at the literal path. |
| Branch | `2026-04-24-ootw-fix-mfrr-activation-crashloop` | `fix/NOTICKET/mfrr-activation-crashloop` | The directory name and branch name differ; `git worktree list` confirmed. |
| Module file count | 1 (`terraform/fbe/event-hub.premium.tf`) | 2 (FBE module + sandbox wiring at `terraform/sandbox/event-hub.premium.tf`) | Phase 2 surfaced both. Phase 4 must confirm the iteration path runs end-to-end, not just module-side. |
| H3 elimination | "RBAC / network / wrong helm string" | Add: "azurerm_storage_container declared elsewhere (e.g., `terraform/sandbox/storage-account.tf`) for the same CG" | Concrete: a duplicate would create plan churn or already provision the resource via a different code path. |

## Refined Hypotheses (with concrete elimination conditions)

- **H1 (leading)** — Single tfvars hunk on `dispatcher-output-1.consumerGroups."activation-mfrr"` produces exactly two resource adds via the FBE module pair. **Eliminate-if** ANY of:
  - `sandbox.tfvars` already contains `"activation-mfrr"` under `dispatcher-output-1.consumerGroups` (Phase-4 grep).
  - `terraform/fbe/event-hub.premium.tf` does NOT define paired CG + container modules iterating the same flattened local (Phase-4 read).
  - The container-name expression is NOT `"${eh}-${cg}"` (Phase-4 read).
  - `terraform/sandbox/event-hub.premium.tf` does not invoke the FBE module for `vpp-evh-premium-sbx` (Phase-4 read).
  - Another `azurerm_storage_container` resource creates `dispatcher-output-1-activation-mfrr` (Phase-4 grep).

- **H2 (parameter-error variant)** — Same shape as H1 but the entry must go in a different tfvars block (different EH name) or under a different scope. **Eliminate-if** the diagnosis-cited Event Hub `dispatcher-output-1` is the unique key matching the failing pod's App Config `EventHubName` — and the cited App Config evidence row holds. Since the App Config probe is the diagnosis author's runtime probe (INFER for me), I will not relabel it FACT but will accept it conditionally because the IaC change is reversible if proven wrong.

- **H3 (root-cause-elsewhere)** — The crashloop has a non-IaC root cause (RBAC, network, helm string mismatch). **Eliminate-if** the diagnosis-cited pod log line `Azure.RequestFailedException: ContainerNotFound (Status 404)` inside `BlobCheckpointStoreInternal.ListOwnershipAsync` is genuine (cited verbatim with kubectl evidence) AND the IaC contains no provisioning of that container. The first part is INFER from the diagnosis; the second part is what Phase 4 verifies.

## Decision logic for Phase 5

- All three H1 sub-falsifiers PASS in Phase 4 ⇒ commit the tfvars hunk on the worktree.
- ANY H1 sub-falsifier FAILS ⇒ STOP, escalate to user with the specific evidence; do not write the hunk.

## Verification Strategy

| What | How (Phase 4 / Phase 8) | Acceptance | Falsifier | Owner |
|---|---|---|---|---|
| `sandbox.tfvars` has `dispatcher-output-1.consumerGroups` block, missing `activation-mfrr` | Phase 4: `rg` for `dispatcher-output-1` block + read line range | Block exists, lists `cgadxdo`, `monitor`, `assetmonitor`, `tenant-gateway-nl`; no `activation-mfrr` key | Block missing OR `activation-mfrr` already present | coordinator |
| FBE module instantiates BOTH `azurerm_eventhub_consumer_group` and `azurerm_storage_container` from one input map | Phase 4: read `terraform/fbe/event-hub.premium.tf` start-to-end | One `module` or `resource` block per kind, both iterating same local; container `name` = `"${eh}-${cg}"` | Decoupled lists OR different naming | coordinator |
| Sandbox wires the FBE module for `vpp-evh-premium-sbx` | Phase 4: read `terraform/sandbox/event-hub.premium.tf` | `module "eventhub_premium"` (or equivalent) source = `../fbe`, var-flow includes consumer-groups input | No wiring OR static resource | coordinator |
| No duplicate `azurerm_storage_container` for `dispatcher-output-1-activation-mfrr` exists elsewhere | Phase 4: `rg "dispatcher-output-1-activation-mfrr"` across worktree | Zero hits in `*.tf` (or only the one we add) | Existing block found | coordinator |
| Patch causes ONLY +1 CG + +1 container in plan | Phase 8: `terraform init && terraform plan` against sandbox backend | Plan shows `+ 2 to add, 0 change, 0 destroy`; both keys reference `activation-mfrr` and `dispatcher-output-1` | Plan touches anything else, or fewer/more adds | coordinator + (if Azure auth available) live plan |
| All three deliverables exist + cite paths | Phase 8: `test -s` + read each file | All three files non-empty, each cites at least the worktree path + the Slack thread + the diagnosis doc | Any file missing or hand-wavy | coordinator |
| No git mutation without explicit auth | Phase 8: `git status --porcelain` on each touched repo | Only the tfvars edit is uncommitted; no commit/push performed | Any commit/push attempted without per-class authorization | coordinator |

## Acceptance criteria (final)

1. Phase 4 falsifiers all PASS before Phase 5 commits to the hunk shape.
2. Three deliverables produced in `02_on_call_shift/2026_04_21_stefan_vpp_infrastructure_mfrr/`:
   - `explanation-of-fix-and-issue-holistic.md`
   - `pr-description.md`
   - `slack-response.md`
3. tfvars hunk applied on worktree; **no commit, no push** unless user explicitly authorizes both class and target.
4. Verification artifact (`phase-8-results.md`) records:
   - the executed tfvars-grep + module-read evidence,
   - the resulting `git diff` (numerically: 1 file, ~7 lines added),
   - terraform-plan output OR an explicit `[UNVERIFIED[blocked: Azure auth not loaded in this session]]` note (R=1 acceptable to defer plan to operator),
   - adversarial review by `socrates-contrarian` and code review by `terraform-code-hcl-expert` (both as separate dispatched subagents — never coordinator self-review).
5. Activation Checklist artifact in `verification/activation-checklist.md`.
