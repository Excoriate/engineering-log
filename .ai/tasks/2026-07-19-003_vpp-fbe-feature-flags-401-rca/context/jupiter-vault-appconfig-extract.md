---
title: "Jupiter FBE feature-flag 401 — live-probe + vault + MS Learn extract"
description: "Precision extraction from 4 prior-task artifacts grounding the FBE feature-flag 401 mechanism: browser-direct HMAC to a per-slot Sandbox App Config store, appconfig.js injection, store naming/provenance, branch-vs-main appconfig delta, and MS Learn 401-vs-403 data-plane semantics."
type: research
status: complete
task_id: 2026-07-19-003
timestamp: 2026-07-19T00:00:00Z
agent: general-purpose
summary: >-
  Extracted for the 2026-07-19 FBE feature-flag 401 RCA from four source artifacts (Jupiter live-probe
  findings, Duncan vault research, MS Learn 401-vs-403 reference, voltex appconfig branch/main capture).
  KNOWN (live-probed 2026-06-26): the failing caller is the browser SPA doing a direct HMAC-SHA256 call to
  a per-slot Sandbox store vpp-appconfig-fbe-<slot>-<rand>.azconfig.io; the frontend init container writes
  the store connection string into a browser-served appconfig.js; the store is healthy (disableLocalAuth=false,
  keys present); a bad-HMAC GET returns HTTP 401 + www-authenticate: HMAC-SHA256, Bearer. INFERRED: the
  morning 401 was a provisioning-window credential-freshness issue, not a standing fault. appconfig-main.yaml
  is a genuine 0-byte capture from a DIFFERENT incident (voltex) so no branch-vs-main auth delta is derivable.
---

# Jupiter FBE feature-flag 401 — live-probe + vault + MS Learn extract

## Source ledger (what was read, in full)

| # | Path | State |
|---|------|-------|
| S1 | `.ai/tasks/2026-06-26-004_enrich-jupiter-fbe-appconfig-probe/findings.md` | Read in full (93 lines) — LIVE PROBE, decisive |
| S2 | `.ai/tasks/2026-06-22-006_fbe-duncan-rca-deliverables/context/vault-appconfig-knowledge.md` | Read in full (250 lines) — vault research |
| S3 | `.ai/tasks/2026-06-22-006_fbe-duncan-rca-deliverables/context/msdocs-appconfig-auth.md` | Read in full (232 lines) — MS Learn reference |
| S4 | `.ai/tasks/2026-06-04-001_rca-fbe-voltex-recreation/context/appconfig-branch.yaml` | Read in full (205 lines, 16k) — SERVICE key-value seed content |
| S5 | `.ai/tasks/2026-06-04-001_rca-fbe-voltex-recreation/context/appconfig-main.yaml` | **0 bytes** — empty (git blob size 0; genuinely empty, not truncated) |
| S5b | siblings `ae-branch.yaml`/`ae-main.yaml`, `evidence-and-diagnosis.md` | Read to interpret S4/S5 (different incident: voltex finalizer deadlock) |

Belief labels below: **KNOWN** = live-probed / MS Learn A1 quote; **INFERRED** = A2 reasoning; **GAP** = unprobed.

---

## Item 1 — LIVE-PROBED mechanism (which principal, which store, HMAC vs RBAC, exact 401)

**KNOWN (S1, witnessed 2026-06-26 via kubectl on Sandbox AKS `vpp-aks01-d` + `az`):**

- **Failing principal = the browser SPA (front-end JavaScript), NOT a pod/managed identity.** It authenticates **browser-direct via HMAC** — "the actual failing caller is the browser SPA doing a direct HMAC call" (S1 P5, diagnosis). Evidence: `HMAC-SHA256` + `x-ms-content-sha256` in the `azure-*.js` bundle; `featureFlags-*.js` references the connection-string var (S1 P5, bundle grep).
- **Auth mode = HMAC (access-key / connection-string), NOT AAD/RBAC.** The SPA holds the store connection string and signs requests itself.
- **Store called = `vpp-appconfig-fbe-jupiter-qvc.azconfig.io`** (per-slot Sandbox store, RG `rg-vpp-app-sb-401`) — **NOT** the dev-mc shared `vpp-applicationconfig-d`/`vpp-appconfig-d` the earlier RCA assumed (S1 P2).
- **Exact 401 captured (S1 P9):** an unauthenticated/bad-HMAC GET returns exactly `HTTP 401` + response header `www-authenticate: HMAC-SHA256, Bearer` — matches Duncan's "401's". (This is the generic host response to bad HMAC, reproduced by probe — not necessarily Duncan's byte-exact morning request.)
- **CORS is open (S1 P8):** `access-control-allow-origin: *` on both OPTIONS preflight and the 401 response → browser is not blocked and literally sees the 401.
- **Store health at probe time (S1 P6):** `disableLocalAuth=false`, Primary+Secondary keys present, `publicNetworkAccess=null`, `provisioningState=Succeeded`, created `09:29:36Z`. The exact FBE connection string returns **200 + real feature flags** (`AdditionalAssetPlanningSeries`, …) via `az appconfig kv list --connection-string "$CS"` (S1 P7).
- **CONFIRMED by Duncan's browser capture (S1 diagnosis):** the `.appconfig.featureflag/*` calls "before these were giving 401's … now it's not a problem anymore" → returns 200 with no store-side change.

---

## Item 2 — appconfig.js structure and location

**KNOWN (S1 P3, P4):**

- **Location:** `/etc/nginx/html/appconfig/appconfig.js` inside the frontend pod (nginx-served static asset → downloaded by the browser).
- **Content = a single global assignment of the FULL App Config connection string:**
  `window.VUE_APP_AZ_CONFIG_CONNECTION_STRING = "${connectionstrings_appconfig}"`
- Probed live: a **valid, non-empty 206-byte** connection string, `Id=h30k` (S1 P4). Endpoint form = `Endpoint=https://vpp-appconfig-fbe-jupiter-qvc.azconfig.io;Id=...;Secret=...` (Vue SPA reads `window.VUE_APP_AZ_CONFIG_CONNECTION_STRING`).
- **Security note (S1):** this exposes the **full read/write Primary-key connection string to the browser**; anyone opening the FBE can read `window.VUE_APP_AZ_CONFIG_CONNECTION_STRING`. Out of scope for the 401 but a real finding.

---

## Item 3 — What writes appconfig.js and when

**KNOWN (S1 P3):** the frontend **init container** writes it at pod start via:
`echo window.VUE_APP_AZ_CONFIG_CONNECTION_STRING = "${connectionstrings_appconfig}" > /etc/nginx/html/appconfig/appconfig.js`
Source: `kubectl -n jupiter get deploy frontend -o yaml`.

- Trigger = **every frontend pod (re)start** (init container), NOT ArgoCD/pipeline directly. The connection-string value `${connectionstrings_appconfig}` comes from the K8s `application-secret` (field `connectionstrings_appconfig`, S1 P2), which is synthesized from Key Vault via the SecretProviderClass CSI (see Item 4 / S2 three-layer stack).
- **INFERRED (S1):** because the value is re-materialized on each pod rebuild, a stale/early-provisioning value gets corrected by a later rebuild — the 20:17:18 pod rebuild rewrote appconfig.js (S1 timeline).

---

## Item 4 — Store naming, RG, disableLocalAuth, connection-string provenance

**KNOWN (S1):**

- **Naming pattern:** one store per slot = `vpp-appconfig-fbe-<slot>-<rand>` (S1 P10, "Topology is normal"). Jupiter = `vpp-appconfig-fbe-jupiter-qvc`. Random suffix (`qvc`) per slot.
- **Resource group:** `rg-vpp-app-sb-401` (Sandbox). Subscription = Sandbox (`vpp-aks01-d` cluster).
- **disableLocalAuth = false** (local/key auth ENABLED — that is why browser HMAC works) (S1 P6).
- **Provenance of the connection string:** injected into `application-secret.connectionstrings_appconfig` (K8s Secret) → written into appconfig.js by init container. The K8s secret is synthesized by the CSI SecretProviderClass (`secret-provider-kv`) using Azure Workload Identity (`userAssignedIdentityID 419ef759-...`) pulling from Key Vault `vpp-aks-d` for Sandbox (S2 §1a, three-layer stack note). **GAP:** the exact Key Vault secret NAME holding the FBE App Config connection string was not captured verbatim in S1 (only the resolved value + `Id=h30k`/`Id=h30k`-class id).

**Contrast — dev-mc shared store (S2, for disambiguation):** intake named `vpp-applicationconfig-d`; vault only knows `vpp-appconfig-d` (`https://vpp-appconfig-d.azconfig.io`). S2 flags this as a **load-bearing discriminator** — the FBE does NOT use either; it uses its own Sandbox store. dev-mc stores are `publicNetworkAccess=Disabled`, private-endpoint-only, AAD/MI auth; Sandbox is the public `0.0.0.0/0` exception.

---

## Item 5 — appconfig-branch.yaml vs appconfig-main.yaml delta

**KNOWN (S4/S5, but with a strong caveat):**

- **These files are from a DIFFERENT incident** (2026-06-04-001 voltex FBE recreation, a finalizer deletion deadlock — S5b evidence-and-diagnosis.md), not the Jupiter 401. They are a Helm/ArgoCD value capture comparing the app-of-apps render on feature branch `feature/fbe-826335-update-appconfig-with-new-tso` vs main.
- **`appconfig-main.yaml` = 0 bytes (empty), confirmed empty in git (blob size 0)** — so **no meaningful branch-vs-main auth/endpoint/connection-string delta is derivable from this pair.** Do not assert one.
- **`appconfig-branch.yaml` (16k)** is the **backend .NET service key-value SEED content** loaded INTO the App Config store — NOT the store's auth config. It contains: Azure AD instance, Swagger/AAD scopes (`api://ea5f10d6-...`), App Insights, CosmosDB, ServiceBus topics (~130 topic mappings), Event Hubs, Kafka certs, gRPC endpoints. **All secret values are templated Key Vault URIs** `https://${keyVaultName}.vault.azure.net/secrets/...`.
- **Only 3 template vars are used:** `${keyVaultName}`, `${environment}`, `${alternateEnvironmentSuffix}` — these are the per-slot substitution points (each FBE slot substitutes its own KV name / env suffix). **This is the real "branch vs slot" mechanism: the SAME appconfig content is re-templated per slot via these vars**, not a hand-edited branch/main auth difference.
- **Crucially: appconfig-branch.yaml contains NO App Config connection string, NO endpoint, NO auth-mode field.** It is the DATA the store serves, confirming the auth/endpoint lives elsewhere (the init-container-written appconfig.js of Item 2/3), not in the GitOps appconfig manifest.
- Sibling `ae-branch.yaml`/`ae-main.yaml` show only an alarmengine image-tag diff (`0.153.feat.49017e3` vs `0.117.dev.93afed2`) — unrelated to App Config auth.

---

## Item 6 — MS Learn App Config data-plane auth facts (401 vs 403)

**KNOWN (S3, all A1 with learn.microsoft.com URLs):**

- **401 = authentication failure (identity not proven); 403 = authorization/network failure (identity proven, denied).** Mutually exclusive signals (S3 Q2/Q3/Q5).
- **HMAC 401 causes** (S3 Q2, `rest-api-authentication-hmac#errors`): missing Authorization header; **clock skew >15 min** (`Date`/`x-ms-date` off UTC) → 401 "access token has expired"; missing/invalid date; missing signed param; **unknown Access Key ID** (incl. keys deleted by disable, OR wrong store host) → 401 "Invalid Credential"; **bad signature** → 401 "Invalid Signature"; missing signed header.
- **The exact 401 body the FBE returns matches** `WWW-Authenticate: HMAC-SHA256, Bearer` — this is the documented "missing/invalid HMAC authorization" shape (S3 Q2 + S1 P9 corroborate each other).
- **disableLocalAuth** deletes all access keys; connection-string (HMAC) requests then get **401 "Invalid Credential"** (INFER per MS docs — number not stated verbatim, S3 Q1). Re-enabling generates NEW keys; old keys still fail 401.
- **Key rotation → 401** immediately for clients on the old key (S3 Q1, `#access-key-rotation`).
- **403 (NOT 401) is the network signal:** public-access-disabled / wrong IP → `403 Forbidden` + `application/problem+json` `type=azconfig.io/errors/ip-address-rejected` (or `nsp-rejected`). "Blocked from VPN / wrong egress IP" ⇒ **403**, never 401 (S3 Q3/Q5). A 401 means the network path SUCCEEDED and the credential failed.
- **Feature flags are key-values** — read = App Configuration **Data Reader**, write = **Data Owner**; no feature-flag-specific role. Control-plane "Reader" is NOT a data role (S3 Q4). RBAC role propagation up to **15 min** (S3 Q6). *(These RBAC facts apply to the AAD path; the Jupiter FBE browser uses HMAC, so RBAC is not the failing lane here.)*

---

## Item 7 — Timing / provisioning-window evidence

**KNOWN timeline (S1, UTC 2026-06-22):**

| Time | Event |
|------|-------|
| 09:29:36 | FBE store `vpp-appconfig-fbe-jupiter-qvc` **created** |
| 10:03:42 | Feature flags written into the store (flags DID exist) |
| 10:26:31 | `frontend` ReplicaSet created → first morning pod inits appconfig.js |
| ~10:49 | Duncan files ticket Rec0BC1FTLV35 ("401's", 12:49 CEST) |
| 20:17:18 | Healthy frontend pod **rebuilt** → appconfig.js rewritten (path healthy) |

**INFERRED (S1, A2 — not byte-proven):** the morning 401 was a **provisioning-window credential-freshness issue** — the browser held a stale/early appconfig.js value (or a cached copy) while the store key was still settling; store-side key was valid by 10:03 but Duncan tested against a ~23-min-old pod. Path self-resolved by the 20:17 rebuild. **This is the leading hypothesis, not a witnessed root cause.** The one probe that would close it 100% (only Duncan can run): DevTools Network tab capture of the failing request — request host, `Id=` in Authorization header, response status + `WWW-Authenticate`, `Date`/`x-ms-date` — plus a hard refresh to rule out a stale cached appconfig.js.

**Key race fact:** the store key **existed and was valid** by 10:03:42, well before the frontend pod (10:26:31) and Duncan's report (~10:49) — so a pure "key didn't exist yet" race is NOT supported; the freshness gap is on the browser/appconfig.js side or clock-skew, not store creation.
</content>
</invoke>
