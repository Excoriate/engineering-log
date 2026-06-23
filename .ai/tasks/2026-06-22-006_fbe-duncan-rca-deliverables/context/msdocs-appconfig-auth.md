---
title: "Azure App Configuration data-plane auth semantics (401 vs 403) — Microsoft Learn reference"
type: research
agent: librarian
status: complete
task_id: 2026-06-22-006
timestamp: 2026-06-22T00:00:00Z
summary: |
  Authoritative Microsoft Learn data for distinguishing HTTP 401 vs 403 on Azure App
  Configuration data-plane calls. 401 = authentication failure (no/invalid/expired token,
  wrong audience/issuer, bad HMAC credential/signature, >15min clock skew, stale rotated key).
  403 = authorization failure, split into 403-RBAC (missing App Configuration Data role) and
  403-NETWORK (verbatim azconfig.io problem+json: ip-address-rejected / nsp-rejected when public
  network access disabled). disableLocalAuth deletes all access keys; key-auth attempts then fail
  (doc says "Microsoft Entra ID becomes the sole authorization method"); exact status for a
  connection-string attempt post-disable is INFER (401 Invalid Credential by HMAC error table),
  not stated verbatim. RBAC: Data Reader = read, Data Owner = read/write/delete; feature flags
  are key-values, need no extra role beyond the key-value roles.
---

# Azure App Configuration — Data-Plane Auth Semantics (401 vs 403)

Reference data for an on-call RCA. Generic Azure semantics only (NOT Eneco-specific).
Every load-bearing claim is labeled A1 FACT (Microsoft Learn URL + quote), A2 INFER
(derived from A1 via named reasoning), or A3 UNVERIFIED (what was searched, why blocked).

## Context Ledger

| Term | Definition | Relevance |
|------|-----------|-----------|
| Data plane | Requests sent to the store endpoint (`{store}.azconfig.io`) for App Config DATA (key-values, feature flags, snapshots). | This is where 401/403 on data reads/writes occur. |
| Control plane | Requests sent to Azure Resource Manager (ARM) for the App Config RESOURCE (properties, keys, networking). | Different role set; `listKeys` lives here. |
| `disableLocalAuth` | API/property that turns off access-key (local) auth. CLI `--disable-local-auth true`. | Crux of "keys disabled" scenarios. |
| Local auth | Access keys / connection string (HMAC-SHA256). Non-Entra. | One of two data-plane auth modes. |
| Microsoft Entra ID auth | AAD bearer token + Azure RBAC data roles. | The other data-plane auth mode. |
| HMAC-SHA256 | Signing scheme used by connection-string (access-key) data-plane auth. | Determines 401 error shapes for key auth. |
| Network security perimeter (NSP) | Security boundary governing public network access; in Enforced mode overrides the store's public-network-access setting. | Produces a distinct 403 variant. |

---

## Q1 — Authentication modes + what `disableLocalAuth` does, and the status when keys are disabled but a connection string is still used

**Two data-plane authentication modes** (A1 FACT):
> "Every request to an Azure App Configuration resource must be authenticated. By default, requests can be authenticated with either Microsoft Entra credentials, or by using an access key."
— https://learn.microsoft.com/azure/azure-app-configuration/howto-disable-access-key-authentication

(a) Access keys / connection string = **HMAC-SHA256** signing (A1 FACT):
> "You can authenticate HTTP requests by using the HMAC-SHA256 authentication scheme. (HMAC refers to hash-based message authentication code.)"
— https://learn.microsoft.com/azure/azure-app-configuration/rest-api-authentication-hmac

(b) Microsoft Entra ID = AAD token + RBAC (A1 FACT):
> "When you use Microsoft Entra authentication, authorization is handled by role-based access control (RBAC). RBAC requires users to be assigned to roles in order to grant access to resources."
— https://learn.microsoft.com/azure/azure-app-configuration/rest-api-authorization-azure-ad

**What `disableLocalAuth` / disabling access keys does** (A1 FACT):
> "Disabling access key authentication deletes all access keys. If any running applications are using access keys for authentication, they'll begin to fail once access key authentication is disabled. Only requests that are authenticated using Microsoft Entra ID will succeed. ... Enabling access key authentication again generates a new set of access keys and any applications attempting to use the old access keys will still fail."
— https://learn.microsoft.com/azure/azure-app-configuration/howto-disable-access-key-authentication#disable-access-key-authentication

CLI form (A1 FACT): `az appconfig update --name <n> --resource-group <rg> --disable-local-auth true` — "The `--disable-local-auth` option is set to `true` to disable access key-based authentication." (same URL).

Naming note (A1 FACT, cross-service): "The API parameter used to disable local authentication is called, appropriately so, `disableLocalAuth`." — https://learn.microsoft.com/azure/event-grid/authenticate-with-microsoft-entra-id#disable-key-and-shared-access-signature-authentication

**Status code when keys are disabled but a connection string is still used — what the docs DO say:**

- A1 FACT — disabling deletes all keys, so HMAC auth has no valid credential to present; applications "begin to fail" and only Entra succeeds (quote above).
- A1 FACT — the HMAC error table defines the failure for an unknown/absent Access Key ID:
  > `HTTP/1.1 401 Unauthorized` / `WWW-Authenticate: HMAC-SHA256 error="invalid_token" error_description="Invalid Credential", Bearer`
  > **Reason:** The provided [`Host`]/[Access Key ID] isn't found.
  — https://learn.microsoft.com/azure/azure-app-configuration/rest-api-authentication-hmac#errors
- A1 FACT — stale/regenerated keys yield 401:
  > "...when you regenerate your secondary key, the older version of that key stops working immediately, causing clients using the older key to get 401 access denied errors."
  — https://learn.microsoft.com/azure/azure-app-configuration/howto-disable-access-key-authentication#access-key-rotation

**Answer (A2 INFER):** A connection-string (HMAC) request after `disableLocalAuth=true` returns **HTTP 401 Unauthorized**, not 403. Reasoning chain: (1) disabling deletes all keys [A1]; (2) HMAC auth requires a valid Access Key ID + Signature [A1 HMAC scheme]; (3) the documented response when the Access Key ID "isn't found" is `401 ... "Invalid Credential"` [A1 HMAC error table]; (4) the rotation page independently confirms invalid/old keys produce "401 access denied" [A1]. No Microsoft Learn page states the disabled-keys-connection-string status code *verbatim for that exact phrasing*, so the specific number is INFER, not FACT. It is an authentication failure (401), distinct from an authorization/RBAC failure (403).

---

## Q2 — What EXACTLY produces HTTP 401 Unauthorized (data plane)

401 = the request is **not authenticated** (identity not proven). Documented causes:

**Entra (Bearer-token) path** (A1 FACT) — https://learn.microsoft.com/azure/azure-app-configuration/rest-api-authentication-azure-ad#errors :
- No Authorization header / Bearer scheme:
  > `HTTP/1.1 401 Unauthorized` / `WWW-Authenticate: HMAC-SHA256, Bearer`
  > **Reason:** You haven't provided the authorization request header with the `Bearer` scheme.
- Invalid token:
  > `WWW-Authenticate: ... Bearer error="invalid_token", error_description="Authorization token failed validation"`
  > **Reason:** The Microsoft Entra token isn't valid. **Solution:** Acquire a Microsoft Entra token ... and ensure that you've used the proper audience.
- Wrong issuer / wrong tenant:
  > error_description="The access token is from the wrong issuer. It must match the AD tenant associated with the subscription to which the configuration store belongs..."
  > **Reason:** The Microsoft Entra token isn't valid. **Solution:** ... Ensure that the Microsoft Entra tenant is the one associated with the subscription ... This error can appear if the principal belongs to more than one Microsoft Entra tenant.

**HMAC (access-key) path** (A1 FACT) — https://learn.microsoft.com/azure/azure-app-configuration/rest-api-authentication-hmac#errors :
- Missing Authorization header: `401 ... HMAC-SHA256, Bearer` — "Authorization request header with HMAC-SHA256 scheme isn't provided."
- **Clock skew** (>15 min): `401 ... error_description="The access token has expired"` — "`Date` or `x-ms-date` request header is more than 15 minutes off from the current Coordinated Universal Time."
- Missing/invalid date: `401 ... "Invalid access token date"`.
- Missing required Authorization parameter: `401 ... "[Credential][SignedHeaders][Signature] is required"`.
- **Unknown Access Key ID** (incl. keys deleted by disable): `401 ... "Invalid Credential"` — "The provided [`Host`]/[Access Key ID] isn't found."
- Bad signature: `401 ... "Invalid Signature"` — "The `Signature` provided doesn't match what the server expects."
- Missing signed header: `401 ... "Signed request header 'xxx' is not provided"` / `"XXX is required as a signed header"`.

**Corroboration** (A1 FACT): "401 errors often indicate invalid or rotated access keys that haven't been updated in production applications, while 403 errors typically signal missing or incorrect role assignments..."
— https://learn.microsoft.com/azure/azure-app-configuration/secure-azure-app-configuration#logging-and-monitoring

**Summary (A2 INFER from the above):** 401 triggers = missing/malformed Authorization header; invalid/expired/wrong-audience/wrong-issuer Entra token; >15 min clock skew (HMAC); unknown Access Key ID (incl. post-disable / wrong store host); bad HMAC signature; stale rotated key.

---

## Q3 — What EXACTLY produces HTTP 403 Forbidden (data plane) — RBAC vs Network

403 = the request is **authenticated** but **not authorized** (identity proven, permission/policy denies). Two distinct sub-causes:

### 403-RBAC (missing data role) — A1 FACT
> ```http
> HTTP/1.1 403 Forbidden
> ```
> **Reason:** The principal making the request doesn't have the required permissions to perform the requested operation. **Solution:** Assign the role required to perform the requested operation to the principal making the request.
— https://learn.microsoft.com/azure/azure-app-configuration/rest-api-authorization-azure-ad
(A2 INFER: a valid Entra token with no App Configuration **Data** role — e.g., only control-plane Contributor/Reader, or no data role at all — passes 401 but fails 403 here.)

### 403-NETWORK (public access disabled / blocked source) — A1 FACT (verbatim problem+json)
Both variants below come from https://learn.microsoft.com/azure/azure-app-configuration/network-access-errors and are distinguishable by the `type` field:

**IP address rejected:**
> ```http
> HTTP/1.1 403 Forbidden
> Content-Type: application/problem+json; charset=utf-8
> ```
> ```json
> { "type": "https://azconfig.io/errors/ip-address-rejected",
>   "title": "Access to this resource is governed by a network access policy. The client IP address fails to meet the criteria for access. See https://aka.ms/appconfig/network-access-errors for more information.",
>   "status": 403 }
> ```
> **Reason:** The configuration store has public network access disabled and the IP address that the request originates from doesn't meet the criteria for inbound access.
> **Solution:** When a configuration store has public network access disabled, requests must originate from within a virtual network via a private endpoint.

**Rejected by network security perimeter:**
> ```json
> { "type": "https://azconfig.io/errors/nsp-rejected",
>   "title": "Access to this resource is governed by a Network Security Perimeter. The request fails to meet the criteria for inbound access. ...",
>   "status": 403 }
> ```
> **Reason:** The App Configuration store's public network access is governed by a network security perimeter and the request doesn't meet the criteria for inbound access.

### How to tell 403-RBAC apart from 403-NETWORK (A2 INFER from the two A1 bodies above)
- **403-NETWORK** body is `Content-Type: application/problem+json` with a `type` of `azconfig.io/errors/ip-address-rejected` or `nsp-rejected`, and the title references a "network access policy" / "Network Security Perimeter." Fix = network (private endpoint, IP/NSP rule, DNS), NOT a role grant.
- **403-RBAC** body has no such network problem+json `type`; reason is literally "doesn't have the required permissions." Fix = assign an App Configuration **Data** role.
- (Operational corollary, A2 INFER) "blocked from VPN / wrong egress IP" → expect 403-NETWORK `ip-address-rejected`, NOT 401. A 401 means the token/key itself failed; it has nothing to do with source IP.

---

## Q4 — RBAC roles: read vs write, key-values vs feature flags

**Data-plane built-in roles** (A1 FACT) — https://learn.microsoft.com/azure/azure-app-configuration/concept-enable-rbac#azure-built-in-roles-for-azure-app-configuration :
> "**App Configuration Data Owner**: Use this role to give read, write, and delete access to App Configuration data. This role doesn't grant access to the App Configuration resource."
> "**App Configuration Data Reader**: Use this role to give read access to App Configuration data. This role doesn't grant access to the App Configuration resource."

**Underlying actions** (A1 FACT) — https://learn.microsoft.com/azure/azure-app-configuration/rest-api-authorization-azure-ad :
- Data Owner: `Microsoft.AppConfiguration/configurationStores/*/read`, `.../write`, `.../delete`, `.../action`.
- Data Reader: `Microsoft.AppConfiguration/configurationStores/*/read`.
- Key-value actions: `.../keyValues/read`, `.../keyValues/write`, `.../keyValues/delete`.

**Role ID** (A1 FACT): App Configuration Data Reader = `516239f1-63e1-4d78-a4de-a74fb236a071`. App Configuration **Reader** (control-plane, NOT data) = `175b81b9-6e0d-490a-85e4-0d422273c10c`.
— https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#integration

**CRITICAL distinction — control-plane "Reader" is NOT a data role** (A1 FACT):
> "App Configuration Reader ... This role does not grant access to data plane resources such as key-values, snapshots, and feature flags."
— https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/integration#app-configuration-data-reader
(A2 INFER: a principal with only control-plane Contributor/Reader/Owner can read the *resource* but gets 403-RBAC on *data* via Entra — those roles "don't grant direct access to the data using Microsoft Entra ID" per the concept-enable-rbac page.)

**Feature flags** (A2 INFER, well-supported):
- A1 FACT: the official quickstarts/tutorials say to use feature flags via Entra you "assign your credential the **App Configuration Data Reader** role." — e.g. https://learn.microsoft.com/azure/azure-app-configuration/howto-variant-feature-flags-aspnet-core#connect-to-app-configuration-for-feature-management and https://learn.microsoft.com/azure/azure-app-configuration/quickstart-feature-flag-javascript
- A1 FACT: the built-in-roles page lists feature flags alongside key-values/snapshots as "data plane resources" gated by data roles (quote above).
- **Conclusion (A2 INFER):** feature flags are stored as key-values and are covered by the same key-value data roles — **Data Reader to read, Data Owner to write** — with **no extra role required** beyond the key-value data roles. No Microsoft Learn page documents a feature-flag-specific data role (A3 UNVERIFIED: searched "App Configuration feature flag RBAC role permissions"; none exists — consistent with feature flags being key-values).

---

## Q5 — Network controls and the status a blocked NETWORK source gets

**Controls available** (A1 FACT) — https://learn.microsoft.com/azure/azure-app-configuration/concept-network-security :
> "By default, an App Configuration store is reachable over the public internet by any client that has valid credentials. You can restrict or completely disable public network access in two ways: 1. The public network access setting on the store. ... 2. Association with a network security perimeter."
> "If an App Configuration store is associated with a network security perimeter in **Enforced** access mode, public network access is governed entirely by the network security perimeter, and the store's public network access setting is ignored."

Private endpoints (A1 FACT): "By default, when you add a private endpoint to your App Configuration store, all requests for your App Configuration data over the public network are denied." — https://learn.microsoft.com/azure/azure-app-configuration/concept-private-endpoint#conceptual-overview

**Status a blocked network source gets = HTTP 403 Forbidden** with `application/problem+json` body (A1 FACT, full verbatim under Q3 above):
- `azconfig.io/errors/ip-address-rejected` — public network access disabled + source IP not permitted.
- `azconfig.io/errors/nsp-rejected` — NSP governs access + request not within perimeter / no matching inbound rule.
— https://learn.microsoft.com/azure/azure-app-configuration/network-access-errors

**Telling "blocked from VPN" apart from "401 auth" (A2 INFER):** a network block is always a **403** carrying the `azconfig.io/errors/...` problem+json `type` and a "network access policy"/"Network Security Perimeter" title. A 401 never carries that body — 401 is purely a credential/token failure (Q2). So: 403 + `ip-address-rejected` ⇒ source/IP/VPN/DNS problem; 401 ⇒ token/key problem. They are mutually exclusive signals.

---

## Q6 — DefaultAzureCredential: AKS/managed-identity vs interactive (AVD), common 401 causes

**DefaultAzureCredential resolves a credential chain** and Microsoft explicitly warns against it in production because the resolved identity can be non-deterministic (A1 FACT):
> "Use deterministic credentials in production environments: Strongly consider moving from `DefaultAzureCredential` to one of the following deterministic solutions ... A specific `TokenCredential` implementation, like `ManagedIdentityCredential`. ... A pared-down `ChainedTokenCredential` implementation that's optimized for the Azure environment in which your app runs. `ChainedTokenCredential` essentially creates a specific allowlist of acceptable credential options, like `ManagedIdentity` for production and `VisualStudioCredential` for development."
— https://learn.microsoft.com/azure/foundry/foundry-models/how-to/configure-entra-id#use-microsoft-entra-id-in-your-code

(A2 INFER — chain-resolves-to-wrong-identity ⇒ 401 mechanism): DefaultAzureCredential tries credentials in order (env vars → managed identity → developer tools like Azure CLI / VS / VS Code). In AKS/managed-identity the intended credential is the workload/managed identity; in an interactive AVD/desktop session the chain may instead resolve to a developer credential (Azure CLI / VS sign-in) — a *different principal*. That token is still a valid Entra token, so the failure mode depends:
- If the resolved identity's token is for the wrong audience/issuer/tenant → **401** "invalid_token"/"wrong issuer" (Q2, App Config Entra error table) [A1 error table].
- If the resolved identity is valid for the store's tenant but lacks the App Configuration Data role → **403-RBAC** (Q3) [A1].

**Token audience matters** (A1 FACT, supporting the "wrong audience ⇒ 401" mechanism): App Configuration's own Entra error table says "ensure that you've used the proper audience" and flags multi-tenant principals as a wrong-issuer 401 cause — https://learn.microsoft.com/azure/azure-app-configuration/rest-api-authentication-azure-ad#errors . (Note: the explicit audience-string table I quoted is from Application Insights, NOT App Configuration — A3 UNVERIFIED that App Configuration documents a literal audience string the same way; searched "App Configuration token audience scope value"; the App Config docs reference "proper audience" but I did not find a verbatim audience-string table for App Configuration specifically.)

**RBAC propagation delay** — a frequently-missed 401/403-adjacent cause (A1 FACT):
> "After a role assignment is made for an identity, allow up to 15 minutes for the permission to propagate before accessing data stored in App Configuration using this identity."
— https://learn.microsoft.com/azure/azure-app-configuration/concept-enable-rbac#azure-built-in-roles-for-azure-app-configuration
(A2 INFER: a freshly role-assigned managed identity can transiently 403 until propagation completes.)

---

## Negative information (what is conspicuously ABSENT from official docs)

- A3 UNVERIFIED: No Microsoft Learn page states a **verbatim HTTP status** for "access keys disabled + client still sends a connection string." Inferred 401 "Invalid Credential" (Q1) is the best-supported answer but is INFER, not a quoted status.
- A3 UNVERIFIED: No **feature-flag-specific** RBAC data role exists in the docs (consistent with feature flags being key-values, Q4).
- A3 UNVERIFIED: No App-Configuration-specific **token audience string table** found (the audience guidance is qualitative "proper audience"; the literal-string table I saw was Application Insights, Q6).
- A1 FACT (asymmetry worth flagging for the RCA): network blocks are **403** (not 401), and the disabled-keys / bad-token failures are **401** (not 403). Conflating them mis-routes the fix (role grant vs network rule vs token fix).

## Source authority summary

All sources PRIMARY (Tier 1, learn.microsoft.com official). Freshness: CURRENT (fetched 2026-06-22).
Highest-value verbatim pages:
- 401 error catalog (Entra): rest-api-authentication-azure-ad#errors
- 401 error catalog (HMAC/key): rest-api-authentication-hmac#errors
- 403-RBAC: rest-api-authorization-azure-ad
- 403-NETWORK (verbatim problem+json): network-access-errors
- RBAC role definitions: concept-enable-rbac, built-in-roles/integration
- disableLocalAuth behavior: howto-disable-access-key-authentication
- Network controls: concept-network-security, concept-private-endpoint
- 401-vs-403 framing for monitoring: secure-azure-app-configuration#logging-and-monitoring
