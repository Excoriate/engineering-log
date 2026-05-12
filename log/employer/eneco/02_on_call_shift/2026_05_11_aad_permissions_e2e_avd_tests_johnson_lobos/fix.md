---
title: Fix — johnson.lobo AADSTS650057 on Hermes API (dev)
description: Exact commands johnson runs to resolve, plus verification and operator-side options.
version: 1.0
status: stable
category: on-call-fix
updated: 2026-05-12
authors:
  - Alex Torres (Claude Code agent)
---

# Fix — johnson.lobo AADSTS650057

See `rca.md` for the mechanism. This file contains only the commands.

## Constants (used below)

```bash
HERMES_APP_ID="0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3"
HERMES_SP_ID="7521cdca-8b98-4e3f-b77b-7ff11d8b8b8c"
AZ_CLI_APP_ID="04b07795-8ddb-461a-bbee-02f9e1bf7b46"
AZ_CLI_SP_ID="e92e13b0-03a1-465f-82cf-2a9bf5732a72"
JOHNSON_OID="cefb3484-9ef6-40f3-829e-5a4f9717c94c"
TENANT_ID="eca36054-49a9-4731-a42f-8400670fc022"
```

## Fix 1 — Immediate, per-user (RECOMMENDED, johnson runs on her AVD session)

```bash
# Clear stale CLI state so the consent prompt fires cleanly.
az account clear

# Trigger interactive consent for Device.Write on the Hermes API.
az login --tenant eca36054-49a9-4731-a42f-8400670fc022 \
         --scope "api://0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3/Device.Write"
# A browser window opens. Accept the consent screen
# ("Microsoft Azure CLI requests permission to write device data on your behalf").
```

**Verify (still on johnson's session):**

```bash
# The consent record now exists.
az rest --method GET --uri \
  "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?\$filter=clientId eq 'e92e13b0-03a1-465f-82cf-2a9bf5732a72' and resourceId eq '7521cdca-8b98-4e3f-b77b-7ff11d8b8b8c' and principalId eq 'cefb3484-9ef6-40f3-829e-5a4f9717c94c'" \
  --query "value[].{scope:scope, consentType:consentType}"
# Expected: [{"scope": " Device.Write", "consentType": "Principal"}]

# The original failing flow now succeeds.
az account get-access-token --resource api://0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3 \
  --query expiresOn -o tsv
# Expected: ISO timestamp ~1h ahead; no AADSTS error.

# (Optional) Re-run her E2E test suite.
```

**Rollback if needed:**

```bash
GRANT_ID=$(az rest --method GET --uri \
  "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?\$filter=clientId eq 'e92e13b0-03a1-465f-82cf-2a9bf5732a72' and resourceId eq '7521cdca-8b98-4e3f-b77b-7ff11d8b8b8c' and principalId eq 'cefb3484-9ef6-40f3-829e-5a4f9717c94c'" \
  --query "value[0].id" -o tsv)
az rest --method DELETE --uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants/$GRANT_ID"
```

## Fix 2 — Tenant-wide, operational (platform-AAD admin runs, OPTIONAL)

```bash
# Discuss with platform-AAD owner first. This makes Azure CLI usable against
# the Hermes API for EVERY user in the Eneco tenant, with no per-user consent
# required. Audit consequence: drift outside Terraform.
az ad app permission grant \
  --id 04b07795-8ddb-461a-bbee-02f9e1bf7b46 \
  --api 0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3 \
  --scope Device.Write
```

**Verify:**

```bash
az rest --method GET --uri \
  "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?\$filter=clientId eq 'e92e13b0-03a1-465f-82cf-2a9bf5732a72' and resourceId eq '7521cdca-8b98-4e3f-b77b-7ff11d8b8b8c' and consentType eq 'AllPrincipals'" \
  --query "value[].{scope:scope, consentType:consentType}"
# Expected: [{"scope": " Device.Write", "consentType": "AllPrincipals"}]
```

**Rollback:**

```bash
GRANT_ID=$(az rest --method GET --uri \
  "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?\$filter=clientId eq 'e92e13b0-03a1-465f-82cf-2a9bf5732a72' and resourceId eq '7521cdca-8b98-4e3f-b77b-7ff11d8b8b8c' and consentType eq 'AllPrincipals'" \
  --query "value[0].id" -o tsv)
az rest --method DELETE --uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants/$GRANT_ID"
```

## Fix 3 — Tenant-wide, IaC (PR — only if platform-AAD owners endorse)

In `Eneco.Infrastructure/main/terraform/platform/aad/app-registration-btm-b2b.tf`, under the `appreg-mcdta-vpp-btm-hermesapi-id-d` module's `api = { ... }` block, add:

```hcl
pre_authorized_applications = [
  {
    application_id           = "04b07795-8ddb-461a-bbee-02f9e1bf7b46" # Microsoft Azure CLI
    delegated_permission_ids = ["b1959a02-82ed-4349-9ca6-fabf0909f978"] # Device.Write scope id
  },
]
```

Apply via `terraform-cd-rbac.pipeline.yaml`. Replicate to `-a` and `-p` modules if the same fix is wanted for acceptance/prod.

**Caveats (READ BEFORE OPENING THE PR):**

- The CCoE module `terraform-azure-aad-application@v2.0.0` input field name (`pre_authorized_applications`) needs verification against the module source — `A3 UNVERIFIED[blocked]` in this incident.
- This departs from existing BTM convention (no BTM app currently uses `preAuthorizedApplications`). Loop in the platform-AAD owner before merging.
- Security review needed: this widens "who can mint Hermes Device.Write tokens via az" from "two opted-in users" to "every Eneco user."

## Fix 4 — Use a different OAuth client (no AAD change)

### 4a — Bruno (developer GUI)

In Bruno's OAuth2 settings for the Hermes call:

```text
Grant type: Authorization Code (PKCE)
Authority:  https://login.microsoftonline.com/eca36054-49a9-4731-a42f-8400670fc022
Client ID:  0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3    ← the Hermes API itself, NOT 04b07795
Redirect:   http://localhost/bruno/callback
Scope:      api://0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3/Device.Write
```

This is the path PR 172140 enabled. Works because the client IS the resource → no preAuth/consent gate.

### 4b — E2E test SP (machine identity, for CI)

```bash
TOKEN=$(curl -sS -X POST \
  "https://login.microsoftonline.com/eca36054-49a9-4731-a42f-8400670fc022/oauth2/v2.0/token" \
  -d "client_id=8c81ac05-70f6-4afd-9dd8-4763070dc4da" \
  -d "client_secret=$E2E_SP_SECRET" \
  -d "scope=api://0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3/.default" \
  -d "grant_type=client_credentials" \
  | jq -r .access_token)
```

Use `appreg-mcdta-vpp-btm-b2b-e2e-d` (`appId 8c81ac05-...`). Already has the `isOnboardingAdministrator` Application role on Hermes API SP — see RCA L5 runtime-truth section. Secret retrieval is via the team's standard secret store; not in scope of this RCA.

## Recommended order of operations

1. **Now**: Fix 1 → johnson unblocked in minutes.
2. **This week**: post the structural finding in `#team-platform` and lessons-learned (LL-014). Decide with the BTM lead whether a long-term Fix 2/3 makes sense.
3. **If long-term fix endorsed**: Fix 3 (declarative, PR-reviewed) > Fix 2 (operational, drifts outside Terraform).
4. **Onboarding**: document the one-time consent step in BTM developer onboarding guide. The recurring symptom otherwise hits every new joiner.

## Closing the on-call card

After Fix 1 succeeds:

- Update Slack Lists record `Rec0B36SVGD7Y` with: status=resolved, root_cause="user lacked per-user oauth2PermissionGrant for Azure CLI → Hermes API; consented via az login --scope ...", fix_applied=Fix 1 from `rca.md`, durable-follow-up="evaluate Fix 2/3 with platform-AAD".
- Link to this RCA (`log/employer/eneco/02_on_call_shift/2026_05_11_aad_permissions_e2e_avd_tests_johnson_lobos/rca.md`) in the Slack thread.
