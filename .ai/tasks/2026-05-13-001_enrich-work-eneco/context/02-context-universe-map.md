---
task_id: 2026-05-13-001
agent: codex
status: working
summary: Context universe map for 2026-05-12 Eneco knowledge enrichment.
---

# Context Universe Map

## Consumer Surfaces

- Primary consumer: the Obsidian `work-eneco` knowledge neighborhood.
- Human consumer: Alex during future Eneco on-call, troubleshooting, and recall.
- Validator surfaces: target folder `_index.md` contracts, wikilink resolution, Obsidian CLI read-back, build ledger verifier, focused knowledge-check report verifier.

## Source Surfaces

- Engineering-log source root: `/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift`.
- Date-selected source folders:
  - `2026_05_12_aad_permissions_e2e_avd_tests_johnson_lobos`
  - `2026_05_12_fbe_jupiter_argocd_image_auth_error`
  - `2026_05_12_rootly_alert_cpu_throtling`
  - `2026_05_12_topic_not_found`
- Vault constitution: `/Users/alextorresruiz/Documents/obsidian/llm-wiki/memory/knowledge-axiomatic-principles.md`.
- Skill protocols: `2ndbrain-obsidian`, `2ndbrain-knowledge-build`, `2ndbrain-knowledge-check`.

## Target Neighborhood

- Eneco work index: `/Users/alextorresruiz/Documents/obsidian/2-areas/work-eneco/_index.md`.
- BTM target: `eneco-vpp-btm/` for Hermes/AAD local E2E delegated-consent knowledge.
- Platform target: `eneco-vpp-platform/` for shift-level on-call synthesis and Rootly alert recurrence.
- Service Bus target: `eneco-vpp-service-bus/` for subscription-manager operating-model mechanics.
- How-to target: `eneco-howto/` for operational remediation steps.

## Existing Canonical Owners

- FBE Jupiter credential gap is already canonicalized in `eneco-vpp-platform/fbe-errors/2026-05-12-jupiter-source1-credential-gap.md`.
- Rootly CPU throttling has an existing 2026-05-11 note: `eneco-otel-collector-cpu-throttling-dev-cluster.md`.
- Service Bus subscription manager has an existing mechanism note and how-to.
- No existing Hermes/AADSTS650057 Azure CLI delegated-consent note was found in BTM or work-eneco searches.

## Lane Ledger

| Lane | Status | Evidence | Route impact |
|---|---|---|---|
| Source file inventory | selected | `rg --files` over 2026-05-12 folders | Established four incident clusters. |
| Vault folder contracts | selected | Read work-eneco, BTM, platform, Service Bus, how-to indexes | Prevented routing BTM/AAD into generic resources. |
| Existing note search | selected | Focused `rg` for Jupiter, AADSTS650057, strike-price, Rootly, Service Bus | Chose update/link-only where canon exists and create only where absent. |
| Git history | blocked | `git status`/`git log` command rejected by runtime policy despite approval mode never | Residual: history+precedent lane is incomplete; mitigated by current files and source logs. |
| External live runtime | skipped | User asked for vault enrichment from repo logs, not live Eneco probe | Claims are framed as source-derived knowledge, not current production state. |

## Main Ambiguity

The route-flip question was whether the May 12 evidence justified new notes or only backlinks. The discriminating evidence was existing-canon search: FBE, Rootly, and Service Bus had canonical owners; Hermes/AAD did not.

## Missing-Angle Question

What if the source RCAs contain sensitive identifiers that should not be replicated into the vault? The planned note uses app IDs/scope strings only where operationally necessary and avoids tokens, credentials, private payloads, and pasted Slack content.

