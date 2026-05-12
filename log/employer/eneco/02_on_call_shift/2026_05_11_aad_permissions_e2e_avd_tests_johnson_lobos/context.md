---
title: AAD permissions — E2E AVD tests — johnson.lobo
description: Zero-context investigation primer for the AADSTS650057 incident on 2026-05-12.
version: 1.0
status: stable
category: on-call-incident
updated: 2026-05-12
authors:
  - Alex Torres (Claude Code agent)
---

# Context — johnson.lobo AADSTS650057 on AVD E2E tests

## What happened

On 2026-05-12 at 10:30:43 UTC, Johnson Lobo (Eneco BTM developer) tried to run an end-to-end test suite from her Azure Virtual Desktop (AVD) session. The test needed an access token for the **BTM Hermes API (dev)** — Eneco's custom OAuth-protected API used by onboarding and B2B integration flows. Azure CLI rejected her token request with:

```text
AADSTS650057: Invalid resource. The client has requested access to a resource which is
not listed in the requested permissions in the client's application registration.
Client app ID: 04b07795-8ddb-461a-bbee-02f9e1bf7b46 (Microsoft Azure CLI).
Resource value from request: api://0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3.
Resource app ID: 0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3.
List of valid resources from app registration: .
Timestamp: 2026-05-12 10:30:43Z.
```

She reported she was already in the right AAD group and that teammates can run the same test from the same AVD image — so the failure looked user-specific. The Slack triage card is the source of truth: `https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0B36SVGD7Y`.

## Why this matters

The BTM Hermes API powers customer onboarding flows for Eneco's behind-the-meter (BTM) battery program. Local E2E tests are how developers validate device-write paths before merging. A single developer blocked on local auth is annoying; the **same gap will block every new joiner** until the underlying mechanism is documented or the platform team adopts a different pattern. This incident is the second time in three weeks the team has tripped over the same gap — PR 172140 added a Bruno redirect URI ("Fix not being able to get tokens from public clients (bruno) for btm b2b api") for similar reasons. The mechanism is structural, not a one-off.

## The two app registrations that matter

| Name | App ID | Object ID | Role |
|------|--------|-----------|------|
| `appreg-mcdta-vpp-btm-hermesapi-id-d` | `0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3` | SP: `7521cdca-8b98-4e3f-b77b-7ff11d8b8b8c` | **The protected API** (resource). |
| Microsoft Azure CLI (public client, Microsoft-owned) | `04b07795-8ddb-461a-bbee-02f9e1bf7b46` | SP in Eneco tenant: `e92e13b0-03a1-465f-82cf-2a9bf5732a72` | **The client** doing the token request. |

The Hermes API IaC lives at `Eneco.Infrastructure/main/terraform/platform/aad/app-registration-btm-b2b.tf:1-84` (dev module).

## The two AAD entities people confuse

| Entity | What it is | Where it lives |
|--------|-----------|----------------|
| `preAuthorizedApplications` | Admin-time shortcut on the **resource API** that pre-consents specific clients tenant-wide. Bypasses the user-consent prompt. | `application.api.preAuthorizedApplications[]` (manifest of the API app reg). |
| `oauth2PermissionGrant` | Runtime delegated-consent record created when a user (or admin) accepts a consent prompt. Per-user (`consentType: Principal`) or tenant-wide (`consentType: AllPrincipals`). | Directory object queried via `GET /oauth2PermissionGrants`. |

A user can be issued a token if **either** mechanism produces a path. The Hermes API has neither admin-pre-auth nor a tenant-wide grant; the only path is per-user consent — which has been completed by exactly two users in this tenant.

## Investigation surfaces consulted

- Slack intake (raw): `slack-intake.txt`
- Eneco IaC repo: `Eneco.Infrastructure/main/terraform/platform/aad/app-registration-btm-b2b.tf`
- Git history: `git log -- terraform/platform/aad/` (PR 172140 commit `e5d3282` is causally related)
- Live AAD (read-only): `az ad app show`, `az ad sp show`, `az ad user show`, `az ad group member check`, Microsoft Graph `/v1.0/oauth2PermissionGrants` and `/v1.0/servicePrincipals/.../appRoleAssignedTo`
- Lessons learned: LL-002 (ArgoCD three-plane RBAC) provided the structural reminder that "user is in group" is insufficient for token issuance when the issuance path itself depends on multiple AAD planes
- Adversarial review: sherlock-holmes (hypothesis completeness) + bertrand-russell (inference-chain logic)

Full evidence and probe outputs: `.ai/tasks/2026-05-12-003_oncall-aad-permissions-johnson-lobo-avd-e2e/context/p4-live-aad-probes.md` and `.ai/tasks/2026-05-12-003_oncall-aad-permissions-johnson-lobo-avd-e2e/verification/adversarial-synthesis.md`.

## Quick orientation for the next reader

1. The error message is misleading: it points at the **client's** app registration but the missing entity is on the **resource** side (no admin pre-auth) and in a **separate directory object** (no per-user consent grant for this user).
2. Group membership grants the **role** that ends up in a token (`isOnboardingAdministrator`). It does NOT grant the right to ACQUIRE the token. Those are two different gates.
3. Two teammates' `az` CLI works because they completed an interactive consent **once** in the past — creating a durable per-user record. The token they get is then issued silently in future. This is not "a hack"; it is the AAD-native user-consent flow.
4. The fix has three flavors — pick by stakes: immediate (per-user consent for johnson), tenant-wide (admin consent or IaC `preAuthorizedApplications`, both widen the security surface), or alternative client (Bruno / E2E SP).
