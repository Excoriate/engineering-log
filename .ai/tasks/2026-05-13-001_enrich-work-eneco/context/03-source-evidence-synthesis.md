---
task_id: 2026-05-13-001
agent: codex
status: working
summary: Extracted durable knowledge candidates from 2026-05-12 Eneco on-call sources.
---

# Source Evidence Synthesis

## Candidate 1: Hermes Azure CLI AADSTS650057 Consent Gap

Evidence class: extraction from `2026_05_12_aad_permissions_e2e_avd_tests_johnson_lobos/rca.md` and `fix.md`.

Durable mechanism: VPP group role membership can be necessary but insufficient for Azure CLI token acquisition against Hermes. Azure CLI needs a delegated consent grant for the Hermes API scope; users with prior grants succeed, a new user without `oauth2PermissionGrant` sees `AADSTS650057`.

Knowledge operation: create BTM mechanism/runbook note because no existing BTM or work-eneco note covers this error class.

## Candidate 2: FBE Jupiter ArgoCD Source Credential Gap

Evidence class: extraction from `2026_05_12_fbe_jupiter_argocd_image_auth_error/rca.md` and existing vault note.

Durable mechanism: ApplicationSet can be healthy while per-Application source fetch fails when one source URL lacks a matching repo or repo-creds template. The consumer surface is the generated Application's source access, not the generator status.

Knowledge operation: link-only. Existing `fbe-errors/2026-05-12-jupiter-source1-credential-gap.md` already captures the RCA, fix, pattern, and recipe.

## Candidate 3: Rootly Otel Collector CPU Throttling Recurrence

Evidence class: extraction from `2026_05_12_rootly_alert_cpu_throtling/rca-2026-05-12-followup.md`.

Durable mechanism: A docs-only or alert-routing PR does not change runtime CPU throttling. The 2026-05-12 recurrence expanded the alert pattern to ACC and dev memory alerts, so the existing four-hypothesis discriminator remains the right action.

Knowledge operation: update existing Rootly note with May 12 recurrence and source caution.

## Candidate 4: FTO Service Bus Strike-Price Subscription Realization Gap

Evidence class: extraction from `2026_05_12_topic_not_found/rca.md` and `feynman-explanation.md`.

Durable mechanism: topic existence and pipeline success do not prove every YAML-declared subscription exists in Azure. For a single missing subscription after successful CD, the first discriminator is Terragrunt state membership against the environment backend.

Knowledge operation: update Service Bus operating model and operational how-to. Do not create a separate incident note unless future recurrences justify an incident-class page.

