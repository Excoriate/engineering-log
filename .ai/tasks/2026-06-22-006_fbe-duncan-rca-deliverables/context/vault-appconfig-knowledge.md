---
title: Vault Knowledge — App Configuration 401 / Feature-Flag Fetch VPN-vs-AVD (Duncan/FBE)
type: research
status: complete
task_id: 2026-06-22-006
timestamp: 2026-06-22T00:00:00.000Z
agent: claude-code
summary: Vault research for App Config 401 / feature-flag VPN-vs-AVD symptom. One direct match (portal 401 = Edge+private-endpoint, fix Chrome/Firefox+AVD); full VPN-vs-AVD private-endpoint+DNS pattern; AAD/MI auth model; no exact service-401 incident. Key GAPS for live probe: disableLocalAuth state, data-plane RBAC, exact store name vpp-applicationconfig-d vs vault's vpp-appconfig-d.
---

# Vault Knowledge — App Configuration 401 / Feature-Flag Fetch (VPN-vs-AVD)

Read-only research over the Eneco VPP Obsidian vault for prior records relevant to:
HTTP 401 against Azure App Configuration on dev-mc when fetching/setting a feature flag, plus the
earlier "feature-flag fetch works from AVD but not from VPN" symptom.

**Scope searched:** `2-areas/work-eneco/eneco-vpp-platform/` (+ `fbe/`, `fbe-errors/` subtrees) and
`llm-wiki/` (`learnings/`, `patterns/`, `episodes/`, `context/`). Vault root resolved to
`/Users/alextorresruiz/Documents/obsidian`.

**Belief labels:** Known = note path + verbatim quote from that note. Inferred = my reasoning over
Known facts. Assumed = unprobed. No note path or quote below is invented; where the vault is silent
it is marked an explicit GAP.

---

## Naming caveat (READ FIRST — Inferred)

The intake names the resource `vpp-applicationconfig-d`. The vault consistently names the dev/Sandbox
App Configuration store **`vpp-appconfig-d`** (endpoint `https://vpp-appconfig-d.azconfig.io`), and the
private-endpoint pattern note shows a BTM store FQDN `appcs-vpp-btm-dev.azconfig.io`. **Inferred:** the
vault has no note literally containing `vpp-applicationconfig-d`; the RCA must confirm the exact store
name on dev-mc by live probe (`az appconfig list`). Do not assume the vault's `vpp-appconfig-d` is the
same store as the intake's `vpp-applicationconfig-d` without verification — this is a load-bearing
discriminator.

---

## 1. How VPP services auth to App Configuration + dev-mc network model

### 1a. Auth model — managed identity (AAD) is primary; API-key is a bootstrap-only gate (Known)

`llm-wiki/patterns/workflows/argocd-helm-oci-plus-appconfig-plus-kv-csi-three-layer-config-stack.md`:

> ".NET host reads `ConnectionStrings__AppConfiguration` from env and binds the
> `Azure.Extensions.AspNetCore.Configuration.AppConfig` provider. At startup it pulls keys from
> `vpp-appconfig-d` (endpoint `https://vpp-appconfig-d.azconfig.io`) using the MI credentials from
> Layer 2."

Same note, Layer 2:

> "SecretProviderClass (`secret-provider-kv`) uses Azure Workload ID
> (`userAssignedIdentityID 419ef759-...`) to pull secrets from Azure Key Vault (`vpp-aks-d` for Sandbox)
> and synthesize the `application-secret` K8s Secret."

`eneco-vpp-shared-runtime-library-contracts.md` (Azure AD auth/authorization contract):

> "`ApiKeyAuthorizationAttribute` adds a bootstrap gate for seeding-style paths: it requires an
> `X-ApiKey` header and validates it against the `SeedingApiKey` configuration value."

and

> "seeding or bootstrap endpoints may still use API-key gating even when the wider service uses Azure AD"

**Inferred:** The workload's App Config read path is AAD/managed-identity based (a `connectionstrings_appconfig`
string + MI), NOT an App Config access key per se — the `X-ApiKey`/`SeedingApiKey` gate is a service-level
bootstrap header, a different concept from an Azure App Configuration data-plane access key. A 401 from App
Configuration itself is therefore most plausibly an AAD/RBAC-data-plane or `disableLocalAuth` issue, not the
service's `X-ApiKey` gate. This is an inference, not a vault fact — confirm against the failing call.

### 1b. dev-mc / higher-env network model — private-endpoint, public access disabled (Known)

`eneco-azure-private-endpoint-dns-workstation-access-pattern.md`:

> "DEV, ACC, and PROD Azure resources (Postgres Flexible Server, App Config, CosmosDB, Storage, Key Vault,
> Service Bus) are deployed with `publicNetworkAccess = Disabled` and a private endpoint pinned to a
> workload VNet subnet. The public FQDN — `pg-fto-d.postgres.database.azure.com`, `appcs-vpp-btm-dev.azconfig.io`,
> etc. — still exists and still resolves over the public internet, but the public IP it points to is firewalled
> shut. Sandbox is the exception: it is public with a `0.0.0.0/0` firewall allowlist".

`eneco-vpp-build-agents-non-ephemeral-architecture.md`:

> "Every Azure PaaS resource the pipelines touch — Key Vault, PostgreSQL Flexible Server, Storage Accounts
> (including Terraform state), App Configuration — has public network access disabled and is exposed only via
> private endpoints inside the MC VNet. Microsoft-hosted agents, which sit on the public internet, have no
> network path to these resources."

**Inferred:** On dev-mc, App Configuration is private-endpoint-only with public access disabled. A workstation
or agent on the public internet (Mac, VPN, MS-hosted agent) has no network path; only VNet-integrated callers
(AVD linked to the private DNS zone, or in-cluster pods) reach it on the private path.

---

## 2. Prior incident matching "App Config 401" or "feature flags work on AVD not VPN"

### 2a. DIRECT MATCH — Azure Portal 401 on App Configuration (Known)

`eneco-vpp-platform-troubleshooting.md`, section **"Azure Portal 401 on App Configuration resources"**:

> "**Azure Portal 401 on App Configuration resources**
> Root cause: browser-specific issue. Edge has known problems with private endpoint resources. Fix: use Firefox
> or Chrome instead. Ensure you are on AVD (VNet-integrated resources have no public access)."

This is the closest existing record. **Scope caveat (Inferred):** it is framed as a *portal/browser* 401
(Edge + private-endpoint quirk) plus the AVD requirement — NOT explicitly a *service/SDK* 401 from a workload
fetching a feature flag programmatically. It supplies two resolution levers (use Chrome/Firefox; be on AVD) but
does not address `disableLocalAuth` or RBAC data-plane role grants. Treat the browser fix as one hypothesis; the
"be on AVD / private-endpoint" fact is the durable, transferable part.

### 2b. "Works on AVD not VPN" — covered as a general access pattern, not an App-Config-specific incident (Known)

`eneco-azure-private-endpoint-dns-workstation-access-pattern.md` — the workstation access table:

> "| Mac, no VPN | Public IP (`20.x`, `40.x`, `52.x`) | TCP drop → timeout |
> | Mac on Eneco VPN | Public IP — VPN does not inject private DNS | TCP drop → timeout |
> | AVD with zone linked | Private IP (`10.x.x.x`) | Connection succeeds |
> | AVD *without* zone linked for this endpoint | Public IP | TCP drop → timeout |"

and (quoting Fabrizio Zavalloni, VPN architect, in the note):

> "From the VPN you will not be able to access any resource of our DEV/ACC/PROD environments. You can only access
> the FBE and sandbox from the VPN."

and (quoting Roel van de Grint):

> "You should be able to log into the DB's from AVD (not from local machine at home)."

The note's Provenance explicitly cites an App Config / AVD DNS Slack thread:

> "Anton Kultsov Jun 16 2025 (App Config BYOD/AVD DNS transition)"

**Resolution this note gives (Known quote):** the symptom of "resolves to a public IP / times out" off-AVD is the
intended posture, and the operational fix for AVD-but-still-failing is the hostfile workaround until DNS zone
registration is done —

> "You can add the IP/FQDN to your AVD's hostfile for now and I'll register the private endpoint with DNS so it
> works without the hostfile entry in the future." (Roel, endorsed)

**Important discriminator (Inferred):** the private-endpoint note's failure mode is **timeout / TCP drop**, NOT
**HTTP 401**. A 401 means the network path SUCCEEDED (you reached the App Config endpoint) but auth/authorization
was rejected. So the intake's 401 symptom is *distinct* from the classic VPN-vs-AVD *timeout* symptom — they may be
two different layers. If the Duncan symptom is a true HTTP 401 (not a timeout), the VPN/AVD DNS note explains the
*VPN-can't-reach* half but does NOT by itself explain a 401; that points at auth (local-auth disabled / missing
data-plane RBAC) rather than networking. This separation is the highest-value finding for the RCA.

### 2c. No exact "feature flag 401" incident note exists (Known — negative)

Searches for `disableLocalAuth`, `local_auth`, `DefaultAzureCredential`, `vpp-applicationconfig`, and
`401 Unauthorized` (over the platform subtree) returned **no note describing a prior incident of a feature-flag
fetch/set returning HTTP 401 from App Configuration**. The `401` hits in `fbe/` and `fbe-errors/` are the Sandbox
resource-group suffix `rg-vpp-app-sb-401` (a subscription/RG name), not HTTP 401 — confirmed false positives.
The one genuine HTTP-401 incident in the vault is `eneco-vpp-terraform-apply-aadsts700024-stale-assertion.md`
(a Terraform-apply WIF stale-assertion 401, unrelated to App Config feature flags).

---

## 3. Recipes / runbooks relevant to App Config access, local-auth, private-endpoint-from-VPN/AVD, RBAC data-plane

| Topic | Vault coverage | Note (Known) |
|---|---|---|
| App Config value read for IaC authoring | YES — exact `az appconfig kv list` recipe | `llm-wiki/learnings/lessons/read-azure-appconfig-values-before-authoring-terraform-pr.md` |
| Three-layer config stack (ArgoCD→KV CSI→App Config) + Layer-oriented diagnosis | YES | `llm-wiki/patterns/workflows/argocd-helm-oci-plus-appconfig-plus-kv-csi-three-layer-config-stack.md` |
| Private-endpoint-from-workstation (AVD/VPN), DNS probes, hostfile workaround | YES (full recipe) | `eneco-azure-private-endpoint-dns-workstation-access-pattern.md` |
| Portal 401 on App Config (browser + AVD fix) | YES (short) | `eneco-vpp-platform-troubleshooting.md` |
| Connect to private-endpointed PaaS from AVD (env + token pattern) | YES (Postgres-shaped, App-Config-adjacent) | `eneco-vpp-platform-faq.md` (Entra ID → PostgreSQL section) |
| App Config access-key disablement (`disableLocalAuth`) recipe | **NONE** | — (GAP, see §5) |
| App Config data-plane RBAC role grant (App Configuration Data Reader/Owner) recipe | **NONE** | — (GAP, see §5) |

The highest-value reusable probe (Known) — `read-azure-appconfig-values-before-authoring-terraform-pr.md`:

> "```bash
> az appconfig kv list --name vpp-appconfig-d --key \"<service-name>:*\" -o table
> ```"

Layer-oriented diagnosis discipline (Known) — three-layer config stack note:

> "**Layer 3 issue** (App Config misconfigured or referencing missing resources): symptom = pod starts, then
> crashes on specific Azure resource SDK call ... This is the most common class of Eneco VPP on-call ticket."

**Inferred:** a 401 *from* App Config itself is a Layer-3 *auth* failure (the MI/identity is rejected by App Config),
which is upstream of the Layer-3 *key-content* failures the note catalogs. The note's layer model is the right frame
but the specific 401-auth sub-case is not yet documented.

---

## 4. Safety gates / one-way doors for App Configuration changes (Known + GAP)

**No vault note states an App-Configuration-specific one-way-door (ForceNew/destroy) gate.** Adjacent safety
records that the RCA should treat as the closest precedent:

- `eneco-vpp-platform-troubleshooting.md`:
  > "Never apply a plan that shows `must be replaced` on a database resource without platform team review."
- Project memory (from this repo's MEMORY.md, not a vault note) flags KV/App-Config **ForceNew** as a one-way-door
  class under the `eneco-sre` skill. **Inferred:** toggling `disableLocalAuth` or `public_network_access` on an
  Azure App Configuration store via Terraform is an in-place update on the live store and is the kind of change
  that needs platform-team review + an explicit safety gate; the vault does not yet record this gate. Confirm the
  exact Terraform behavior (in-place vs ForceNew) by live `terraform plan` before acting — do NOT assume.

GAP: no recorded recipe for safely flipping App Config `local_auth` / `public_network_access`, and no recorded
blast-radius note for "what breaks when access keys are disabled" (e.g. any caller still using a connection-string
access key rather than AAD would start failing with 401 — exactly the intake symptom shape).

---

## 5. Explicit GAPS — what the vault does NOT have (RCA needs live probes)

1. **Exact store name / existence of `vpp-applicationconfig-d`.** Vault knows `vpp-appconfig-d` and
   `appcs-vpp-btm-dev`. GAP: whether the intake's `vpp-applicationconfig-d` is a real distinct store on dev-mc.
   Probe: `az appconfig list -o table` (and `az appconfig show -n <name>`).

2. **`disableLocalAuth` state of the store.** No note records whether dev-mc App Config has local (access-key)
   auth disabled. This is the single most likely 401 root cause if the caller uses an access-key/connection-string.
   Probe: `az appconfig show -n <name> --query "disableLocalAuth"`.

3. **Data-plane RBAC role assignments** (App Configuration Data Reader/Owner) for the workload MI / the human
   identity doing the feature-flag set. No vault note enumerates these. Probe: `az role assignment list --scope
   <appconfig-resource-id>` and check the calling identity has `App Configuration Data Reader/Owner`.

4. **Whether the 401 is a true HTTP 401 vs a timeout mislabeled.** §2b shows the VPN/AVD pattern produces
   *timeouts*, not 401s. GAP: the actual error string/status from Duncan's failing call. Probe: capture the raw
   SDK/CLI error (status code + `WWW-Authenticate` header if present).

5. **Public network access setting** of the store on dev-mc (the FAQ says higher envs are `publicNetworkAccess =
   Disabled` generally, but the specific store is unprobed). Probe:
   `az appconfig show -n <name> --query "publicNetworkAccess"`.

6. **Three dangling wikilinks** referenced by `eneco-vpp-shared-runtime-library-contracts.md` do NOT exist as notes:
   `eneco-flex-trade-optimizer-app-configuration-deployment-contract`, `eneco-platform-aad-landscape`,
   `eneco-flex-trade-optimizer-app-configuration-deploy`. The FTO App-Config *deployment contract* knowledge the
   library note points at is therefore NOT in the vault — a content GAP, not just a broken link.

7. **No "Duncan" / "Jupiter FBE" + App Config 401 record.** "Duncan" appears once in the vault
   (`fbe-errors/recipe-resolve-nu1902-nu1903-build-failure.md`, a NuGet CVE build failure on Duncan's branch —
   unrelated). No App-Config-401 incident is tied to Duncan or Jupiter.

---

## Source ledger (notes read in full)

- `eneco-azure-private-endpoint-dns-workstation-access-pattern.md` (A1 — full read)
- `eneco-vpp-shared-runtime-library-contracts.md` (A1 — full read)
- `eneco-vpp-build-agents-non-ephemeral-architecture.md` (A1 — full read)
- `eneco-vpp-platform-faq.md` (A1 — full read)
- `eneco-vpp-platform-troubleshooting.md` (A1 — full read)
- `fbe/fbe-security-and-compliance.md` (A1 — full read; Per-FBE App Configuration = sandbox-tier, config copied)
- `llm-wiki/patterns/workflows/argocd-helm-oci-plus-appconfig-plus-kv-csi-three-layer-config-stack.md` (A1)
- `llm-wiki/learnings/lessons/read-azure-appconfig-values-before-authoring-terraform-pr.md` (A1)
- `vpp-feature-flags-tracker.md` (A1 — lifecycle tracker only; no auth/network/401 content)
- Negative searches (A1 — returned empty over platform subtree): `disableLocalAuth`, `local_auth`,
  `DefaultAzureCredential`, `vpp-applicationconfig`. `get_notes_info` confirmed the 3 dangling links above do not exist.
