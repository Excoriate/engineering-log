---
task_id: 2026-04-26-001
agent: coordinator
status: complete
summary: Discovery notes — quirks and unknowns surfaced during Phase 2 mapping
---

# Discovery map

## Confirmed facts (Phase 2, FACT)

- Worktree `2026-04-24-ootw-fix-mfrr-activation-crashloop` exists at the literal `%20` path under `myriad-vpp/VPP%20-%20Infrastructure/`, on branch `fix/NOTICKET/mfrr-activation-crashloop`, HEAD `4dbaf72`, clean status.
- Branch `fix/NOTICKET/mfrr-activation-crashloop` matches the same commit as origin/main (4dbaf72), so the diff to be applied is exactly the tfvars hunk + nothing else.
- Two instances of the repo on disk: bare-repo+worktree layout (`VPP%20-%20Infrastructure`) AND a separate plain clone (`VPP - Infrastructure`). Both at 4dbaf72. **The user explicitly named the worktree path; that is the fix-target.** The plain clone is read-only context and must not be edited.
- 935-line `sandbox.tfvars`. 150-line `terraform/fbe/event-hub.premium.tf`. Phase 4 will cite specific lines.

## Surprises / quirks

1. **Two `event-hub.premium.tf` files** — one in `terraform/fbe/` (claimed by diagnosis as the module body), one in `terraform/sandbox/` (likely the wiring file that instantiates the FBE module for sandbox-only Event Hub namespaces). Phase 4 must read both to confirm the iteration path.
2. **Branch name** is `fix/NOTICKET/mfrr-activation-crashloop`, not `2026-04-24-ootw-fix-mfrr-activation-crashloop`. The latter is just the worktree directory name.
3. **No worktree at the path the user typed verbatim** (`VPP - Infrastructure/2026-04-24-...`). The actual path uses `VPP%20-%20Infrastructure`. User likely copy-pasted from a URL bar; the worktree itself is correctly prepared.

## Open hypotheses for Phase 4 to resolve

- **H1 confirmation path**: read sandbox.tfvars line range covering `dispatcher-output-1.consumerGroups`; confirm `activation-mfrr` absent + 4 expected siblings present (`cgadxdo`, `monitor`, `assetmonitor`, `tenant-gateway-nl`).
- **H1 module path**: read `terraform/fbe/event-hub.premium.tf` to confirm both modules — `eventhub_namespace_premium_eventhubs_consumer_groups` AND `eventhub_namespace_premium_eventhubs_consumer_groups_storage_containers` — iterate the SAME flattened `local` and produce one resource each per declared CG.
- **H1 naming**: confirm container name expression = `"${eventhub_name}-${consumer_group_name}"`.
- **H2 falsifier**: search the entire tfvars for any pre-existing `activation-mfrr` entry under `dispatcher-output-1` (would indicate diagnosis error).
- **H3 falsifier**: check whether `azurerm_storage_container` with the expected name already lives in another file (e.g., `terraform/sandbox/storage-account.tf`) — if so, the missing resource is not solely produced by the FBE module pair and the fix is incomplete.

## Out-of-scope for this verification (acknowledged residuals)

- ESP / Axual Kafka outage on the R145 pod (separate ticket per diagnosis §6). NOT part of the fix.
- MC environment image propagation (separate pipelines).
- Live Azure runtime probes — accepted from the diagnosis author's prior FACT classification, downgraded to INFER, and not re-probed (would require Azure CLI auth + on-call session). The IaC fix is correct iff the IaC currently matches the missing-CG state, regardless of any runtime drift in non-IaC tooling.
