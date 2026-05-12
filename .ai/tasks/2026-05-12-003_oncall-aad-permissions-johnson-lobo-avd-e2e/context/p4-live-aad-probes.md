---
task_id: 2026-05-12-003
agent: claude-code
status: complete
summary: Live A1 AAD probes; falsifies H1/H2/H4; confirms preAuthorizedApplications empty → AADSTS650057 expected for az CLI client.
---

# P4 Live AAD Probes

Tenant: `eca36054-49a9-4731-a42f-8400670fc022` (Eneco). Operator identity: Alex.Torres@eneco.com (delegated tenant read).

## Hermes API (dev) — App Registration `0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3`

A1 FACT (probe `az ad app show --id 0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3`):

| Property | Value | Significance |
|----------|-------|--------------|
| `displayName` | `appreg-mcdta-vpp-btm-hermesapi-id-d` | BTM Hermes API, **dev** environment |
| `appId` | `0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3` | Matches `Resource value` in the slack error |
| `preAuthorizedApplications` | `[]` (empty) | **AAD has no client pre-authorized to acquire tokens for this API.** This is the EXACT condition AADSTS650057 reports. |
| `knownClientApplications` | `[]` (empty) | No combined-consent client linkage either. |
| `oauth2PermissionScopes[].value` | `Device.Write` | Single delegated scope. |
| `appRoles[].value` | `isOnboardingAdministrator` | Single Application/User role. |
| `publicClient.redirectUris` | `["http://localhost/bruno/callback"]` | The API is wired to act as **its own public client** (Bruno OAuth flow). |
| `spa.redirectUris` | `https://func-api-b2b-vpp-btm-dev.azurewebsites.net/swagger/oauth2-redirect.html`, `http://localhost:5155/swagger/oauth2-redirect.html` | Swagger UI flow. |

## Hermes API (dev) — Enterprise Application (Service Principal `7521cdca-8b98-4e3f-b77b-7ff11d8b8b8c`)

A1 FACT (`az ad sp show --id 0abb4cf9-...`):

| Property | Value | Significance |
|----------|-------|--------------|
| `appRoleAssignmentRequired` | `false` | **H1 FALSIFIED** — the Enterprise App does NOT require explicit user assignment. |
| `signInAudience` | `AzureADMyOrg` | Single-tenant. |
| `accountEnabled` | `true` | SP is live. |

## User `johnson.lobo@eneco.com`

A1 FACT (`az ad user show`):

| Property | Value | Significance |
|----------|-------|--------------|
| `id` | `cefb3484-9ef6-40f3-829e-5a4f9717c94c` | Member user object id. |
| `userPrincipalName` | `Johnson.Lobo@eneco.com` | Home-tenant UPN. |
| `externalUserState` | `null` | **H4 FALSIFIED** — not a guest/B2B account. |
| `creationType` | `null` | Internal member, not invited. |

## Group `sg-vpp-btm-developers` (id `06419929-4eb0-49fb-add5-e0ff850e5ac8`)

A1 FACT (`az ad group member check`): johnson.lobo IS a member (`{"value": true}`). **H2 FALSIFIED** — the user IS in the IaC-declared group.

## Hermes API SP — `appRoleAssignedTo` graph

A1 FACT (Graph `/v1.0/servicePrincipals/.../appRoleAssignedTo`):

| Principal | Type | Role | Notes |
|-----------|------|------|-------|
| `sg-vpp-btm-developers` (06419929-...) | Group | `isOnboardingAdministrator` (2ba76c52-...) | johnson.lobo inherits transitively. |
| `sb-onboarding-orchestrator-api-sb` (0d484c90-...) | ServicePrincipal | `isOnboardingAdministrator` | sandbox onboarding SP. |
| `d-onboarding-orchestrator-api-d` (63376df1-...) | ServicePrincipal | `isOnboardingAdministrator` | dev onboarding SP. |
| `appreg-mcdta-vpp-btm-b2b-e2e-d` (58d11a6e-...; appId `8c81ac05-70f6-4afd-9dd8-4763070dc4da`) | ServicePrincipal | `isOnboardingAdministrator` | **E2E test app SP — Application permission grant.** |
| `Admin Rajat Singh` (c5653b3a-...) | User | `00000000-0000-0000-0000-000000000000` (default access) | Placeholder assignment; no real role. |

## Convention probe — preAuthorizedApplications across BTM apps

A1 FACT (`az rest /v1.0/applications?$filter=startswith(displayName,'appreg-mcdta-vpp')` → filtered for non-empty preAuth): result `[]`. **No Eneco BTM app uses `preAuthorizedApplications` as a convention.** The team's auth pattern is "API-as-own-public-client" (Bruno) or dedicated test SP with client credentials.

## Causal Chain (A2 INFER from above A1 facts)

```
johnson.lobo runs `az account get-access-token --resource api://0abb4cf9-...` (or equivalent)
        │
        ▼
Azure CLI (clientId 04b07795-8ddb-461a-bbee-02f9e1bf7b46) requests token for resource 0abb4cf9
        │
        ▼
AAD evaluates: is 04b07795 in 0abb4cf9.api.preAuthorizedApplications? → NO (empty array, A1)
        │
        ▼
AAD evaluates: is 04b07795 in 0abb4cf9.api.knownClientApplications? → NO (empty array, A1)
        │
        ▼
AAD has no admin/user consent path that authorizes 04b07795 for this resource
        │
        ▼
AADSTS650057 returned with "List of valid resources from app registration: ." (empty)
```

The error string `Resource value from request: api://0abb4cf9-...` + `List of valid resources from app registration: .` is precisely the trace AAD produces for a `clientApp not in resource.preAuthorizedApplications` scenario when the client is a Microsoft public client like Azure CLI.

## Why teammates succeed

A2 INFER (from convention probe + Bruno redirect URI + E2E SP role grant):

1. **Path α (Bruno / interactive OAuth)**: developer configures Bruno with `clientId=0abb4cf9-...`, redirect=`http://localhost/bruno/callback`, scope=`api://0abb4cf9-.../Device.Write` (or `.default`). The OAuth client identity IS the API identity → no preAuth gate. Group membership grants `isOnboardingAdministrator` role claim in the token.
2. **Path β (E2E SP client credentials)**: test runner uses `appId=8c81ac05-70f6-4afd-9dd8-4763070dc4da` + client secret with `client_credentials` grant, scope=`api://0abb4cf9-.../.default`. AAD issues an Application token carrying the `isOnboardingAdministrator` role (already granted to the E2E SP at `appRoleAssignedTo`).

Either path bypasses the preAuth gate. Direct `az` CLI does not.

## Falsifier Status

| Hypothesis | Status | Evidence |
|------------|--------|----------|
| H1: Enterprise App requires assignment, user not assigned | **FALSIFIED** | `appRoleAssignmentRequired: false` |
| H2: User missing from group | **FALSIFIED** | group member check `{value: true}` |
| H3: Stale `az` token cache / wrong tenant | **NOT THE PRIMARY CAUSE** | The error is deterministic for ANY az CLI request against this resource in this tenant; cache state does not change preAuth lookup |
| H4: Guest/B2B/cross-tenant | **FALSIFIED** | UPN home-tenant; `externalUserState: null` |
| H5: Conditional Access | **NOT REACHED** | CA returns a different AADSTS family (50xxx, 53xxx); not 650057 |
| **H6 (emergent)**: Wrong client (using Azure CLI instead of Bruno or E2E SP) | **CONFIRMED** | `preAuthorizedApplications: []` + Bruno redirect URI configured + E2E SP role grant exists |
