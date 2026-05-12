---
task_id: 2026-05-12-003
agent: claude-code
status: complete
summary: Sherlock + Russell both surfaced H9 (oauth2PermissionGrants user consent). Discriminating probe ran; consent gap is the true mechanism. Initial Bruno/E2E-only diagnosis was under-discriminated.
---

# Adversarial Synthesis — Final Diagnosis

## Receipts received

| Reviewer | Verdict | Top finding |
|----------|---------|-------------|
| sherlock-holmes | `REQUEST_PROBE` | H9 — per-user `oauth2PermissionGrant` may exist for teammates but not johnson; would change fix from "use Bruno/E2E SP" to "complete user-consent" or "tenant-wide admin consent" |
| bertrand-russell | `NEEDS_REPAIR` | A2 equivocation — `preAuthorizedApplications` (admin-consent shortcut) was conflated with `oauth2PermissionGrants` (per-user delegated consent). C was under-discriminated. |

Both reviewers converged on the same discriminating probe.

## Discriminating probe — RESULT (A1)

`GET /v1.0/oauth2PermissionGrants?$filter=clientId eq '<azure-cli-sp>' and resourceId eq '<hermes-api-sp>'`:

```json
[
  {"clientId": "e92e13b0-...(Azure CLI SP)", "consentType": "Principal", "principalId": "754f018b-..." (Niels.Witte@eneco.com), "scope": " Device.Write"},
  {"clientId": "e92e13b0-...(Azure CLI SP)", "consentType": "Principal", "principalId": "4a715c47-..." (Anastasia.Zenchik@eneco.com), "scope": " Device.Write"}
]
```

`GET /v1.0/oauth2PermissionGrants?$filter=principalId eq '<johnson-lobo-id>' and resourceId eq '<hermes-api-sp>'` → `[]`.

`GET /v1.0/oauth2PermissionGrants?$filter=... and consentType eq 'AllPrincipals'` → `[]` (no tenant-wide grant).

`oauth2PermissionScope.type` for `Device.Write` = `User` (user-consent allowed).

## Resolved hypothesis grid

| H | Status | Evidence |
|---|--------|----------|
| H1 Enterprise App requires assignment | FALSIFIED | `appRoleAssignmentRequired: false` |
| H2 User missing from group | FALSIFIED | group member check `{value: true}` |
| H3 Stale az token cache | NOT PRIMARY | per-user consent record absence is deterministic; cache state doesn't change it |
| H4 Guest/B2B | FALSIFIED | member, home-tenant UPN |
| H5 Conditional Access | RULED OUT | distinct AADSTS family |
| H6 Wrong client (Bruno/SP) | **DOWNGRADED** — a valid alternative path, NOT the root cause |
| H7 Bruno misconfigured with az client_id | STILL POSSIBLE secondary | requires user's exact command/config to fully eliminate; orthogonal to fix |
| H8 Teammates ride cached refresh tokens | RECAST — teammates ride durable per-user **consent records**, not cached tokens |
| **H9 Missing per-user `oauth2PermissionGrant`** | **CONFIRMED** | Niels + Anastasia have grants; johnson does not; no `AllPrincipals` grant |
| H10 api:// canonicalization | FALSIFIED | `identifierUris: ["api://0abb4cf9-..."]` matches exactly |
| H11 AVD WAM broker | NOT REACHED | grant-absence is upstream; broker behavior is downstream |
| H12 terraform-azuread misconfigured | OUT OF SCOPE | she's running E2E tests, not terraform |

## Final causal chain (all A1 except where flagged)

```
johnson.lobo runs `az account get-access-token --resource api://0abb4cf9-.../...`
        │  (A3 — exact command unverified; AADSTS650057 confirms client = 04b07795 = Azure CLI)
        ▼
Azure CLI silent token acquisition: POST /oauth2/v2.0/token with refresh_token
        │
        ▼
AAD lookup, in order:
   • preAuthorizedApplications[04b07795 in 0abb4cf9.api.preAuthorizedApplications]? → NO (A1: [])
   • Tenant-wide oauth2PermissionGrant[clientId=Azure CLI SP, resourceId=Hermes SP, AllPrincipals]? → NO (A1: [])
   • Per-user oauth2PermissionGrant[clientId=Azure CLI SP, resourceId=Hermes SP, principalId=johnson.lobo]? → NO (A1: [])
        │
        ▼
No authorization path exists; silent flow cannot trigger interactive consent prompt
        │
        ▼
AAD returns AADSTS650057. Trailing "List of valid resources from app registration: ."
   reflects Azure CLI's own manifest never listing Eneco custom APIs (Microsoft can't pre-list them).
   The actual missing entity is the per-user consent grant for johnson.lobo, NOT a missing entry in Azure CLI's manifest.
```

Counterfactual proof: replace `principalId=johnson.lobo` with `principalId=Niels.Witte`. The Principal-scoped grant is found → AAD issues token → 200 OK.

## Why teammates succeed (revised, A1-grounded)

Path α (revised): Niels and Anastasia at some point ran an INTERACTIVE consent flow — likely:

```bash
az login --scope api://0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3/Device.Write
# (browser opens, "Do you allow Microsoft Azure CLI to access ... Device.Write?" → Accept)
```

This created their Principal-scoped `oauth2PermissionGrant`. After that, silent `az account get-access-token --resource api://0abb4cf9-...` works because the grant is durable until revocation.

Path β (Bruno) and Path γ (E2E SP client credentials) are still real alternatives but explain different flows (interactive GUI; CI machine).

## Fix recommendations (ordered)

1. **Immediate (johnson-only, no IaC change)** — johnson runs once on her AVD session:
   ```bash
   az login --scope api://0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3/Device.Write
   ```
   Accept the consent prompt. Subsequent `az account get-access-token --resource api://0abb4cf9-...` will succeed.
2. **Durable, operational** — admin grants tenant-wide consent for Azure CLI → Hermes API `Device.Write`:
   ```bash
   az ad app permission grant --id 04b07795-8ddb-461a-bbee-02f9e1bf7b46 \
     --api 0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3 --scope Device.Write
   ```
   Creates a single `AllPrincipals` `oauth2PermissionGrant`; every Eneco user can call from `az` CLI without per-user consent. **Security review required** — this widens the access surface.
3. **Durable, IaC** — add `preAuthorizedApplications` block to the BTM Hermes API module in `Eneco.Infrastructure/main/terraform/platform/aad/app-registration-btm-b2b.tf`. Tenant-wide pre-authorization, no consent prompt, declarative. Same security implication as (2) but reviewed via PR. NOTE: Eneco convention across BTM apps currently does NOT use `preAuthorizedApplications` (probe G result `[]`), so this would be a NEW pattern — needs platform-AAD owner sign-off.
4. **Bruno** — already documented in PR 172140; works because the API acts as its own public client. Tell johnson to use Bruno with `clientId=0abb4cf9-...` (NOT Azure CLI's `04b07795`) and redirect `http://localhost/bruno/callback`. Good for ad-hoc exploration.
5. **E2E SP (CI)** — for machine identity, `appreg-mcdta-vpp-btm-b2b-e2e-d` (appId `8c81ac05-...`) with client credentials. The team likely already uses this in CI.

## Residual uncertainty (A3)

- Exact command johnson runs is not captured (assumption: direct `az account get-access-token --resource api://0abb4cf9-...` or equivalent; AADSTS650057 + `Client app ID: 04b07795` is necessary and sufficient evidence that the active client identity is Azure CLI, regardless of which wrapper invokes it).
- AAD activity log at error time (2026-05-12 10:30:43Z) not pulled — would corroborate causal chain but is not load-bearing.
- Whether AVD specifically affects WAM broker behavior is irrelevant once we identify the consent-record absence.

## Verdict

Diagnosis: VERIFIED-ROOT-CAUSE — depth 1 (proximate: missing per-user consent grant), depth 2 (enabling: API has no preAuthorizedApplications + no tenant-wide grant), depth 3 (design: convention to rely on per-user consent rather than admin-managed pre-authorization).

Fix: SHIP option (1) as immediate unblock; surface options (2)/(3) to platform-AAD owners as durable improvement; document Bruno path (4) for ad-hoc use.
