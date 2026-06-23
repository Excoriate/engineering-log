---
title: Diagnosis Synthesis — Duncan / Jupiter FBE App Configuration 401 (dev-mc)
description: Situation model + ranked hypothesis set for the NEW Slack-Lists record Rec0BC1FTLV35, built from 4 context lanes
summary: >-
  The NEW record (401 on AVD) is a distinct auth-layer failure from the EARLIER by-design
  network ticket. 401 = authentication (token/key), not RBAC (403) or network (403/timeout).
  Ships a 7-way ranked hypothesis set (leading: data-plane auth gap for the AVD identity, H1
  token / H3 role, with H2 access-key as the literal-401 alternative); the collapsing probe
  (exact status + auth body) is AVD-gated, so the diagnosis is a Hypothesis Set, not a
  Verified Root Cause. Includes one-way-door safety gates for the how-to-fix.
type: research
status: complete
task_id: 2026-06-22-006
agent: coordinator
timestamp: 2026-06-22T14:30:00+02:00
---

# Diagnosis Synthesis — Jupiter FBE App Configuration 401 (dev-mc)

Keystone artifact for the RCA + how-to-fix. Every load-bearing claim is A1 FACT
(sidecar/source + quote), A2 INFER (named reasoning over A1), or
A3 UNVERIFIED[blocked: reason] (+ resolving probe). Source lanes:
`context/slack-harvest.md`, `context/fbe-ff-mechanism.md`,
`context/msdocs-appconfig-auth.md`, `context/vault-appconfig-knowledge.md`.

## The two records are NOT the same failure (the central framing)

- **EARLIER (Rec0BBGJ9DMFU, "VPP frontend", 2026-06-18, Status=Done).** Symptom =
  feature-flag fetch works on AVD, **times out** on VPN. **A1** resolution by the
  platform team (Nuno Alves Pereira, 2026-06-19): *"this is how it works by design.
  The App Configuration you are using is private endpointed, so there is no [line]
  of sight outside the VNet. AVD is the way forward here."* (slack-harvest §2a). This
  is a **network/DNS** layer issue and it is **closed by-design**.
- **NEW (Rec0BC1FTLV35, "Asset Optimization", 2026-06-22 12:49, Status=In progress,
  assignee Alex Torres).** Symptom = *"calls for app configuration are failing … FFs
  cannot be set properly … getting 401's. I can see the FFs set properly in the app
  config."* — **401 while ON AVD** (inside the VNet; network reachable). **ZERO replies,
  no stated resolution** (slack-harvest §1a/§2b). This is the OPEN item.

**A2 (load-bearing):** a 401 *on AVD* cannot be the EARLIER by-design network cause —
the network block is a **403 `ip-address-rejected`** or a TCP timeout, never a 401
(msdocs §Q5; vault §2b: "the private-endpoint failure mode is timeout/TCP drop, NOT
HTTP 401"). The RCA must not conflate the two. The new symptom is an **auth-layer**
failure.

## What "401 vs 403" forces (the master discriminator)

From Microsoft Learn (msdocs §Q2/Q3, all A1):

- **401 Unauthorized = authentication failed** (identity not proven): missing/invalid/
  expired Entra token; wrong audience/issuer/tenant; OR access-key (HMAC) problems —
  unknown/deleted key (incl. after `disableLocalAuth`), bad signature, >15-min clock
  skew, stale rotated key.
- **403 Forbidden = authenticated but not authorized**: 403-RBAC (valid token, missing
  `App Configuration Data` role) OR 403-NETWORK (`application/problem+json` with
  `type: …/ip-address-rejected` or `…/nsp-rejected`).
- **These are mutually exclusive signals.** A missing data-plane role is **403, not
  401**. A blocked source IP/VPN is **403/timeout, not 401**.

**Consequence:** if Duncan's "401" is literal, the cause is the **credential/token
itself**, not a missing role and not network. If the tooling is loosely reporting an
auth error that is really a 403, the cause shifts to RBAC. **The single highest-value
probe is therefore: capture the exact status + `WWW-Authenticate` header / problem+json
body of the failing call.** Everything branches on it.

## The two App Configuration code paths (mechanism, A1 from fbe-ff-mechanism)

- **READ path (service consumes FFs at runtime):** `Eneco.Vpp.Configuration.AzureAppConfiguration`
  calls `.Connect(connectionString)` — an **access-key connection string** from Key Vault
  secret `connectionstrings-app-config`. `DefaultAzureCredential` is used ONLY to resolve
  Key Vault references, NOT to authenticate to App Config. **A1**
  (`HostBuilderExtensions.cs`). A 401 here ⇒ the **access key is bad** (deleted via
  `disableLocalAuth`, or stale after rotation).
- **WRITE / set-FF path:** an **ADO Terraform pipeline** (`devmc.pipeline.yml`, service
  connection `eneco-vpp-mc-dev`, pool `self-hosted-mcdev-k8s` inside the VNet) writes
  `azurerm_app_configuration_feature` / `_key` over the **data plane using the SP's Entra
  token** (`use_azuread_auth = true`), requiring **`App Configuration Data Owner`**.
  That role is granted to security group **`sg-vpp-core-release-masters`**
  (`d5a241bf-…`) on `vpp-applicationconfig-d` (`dev.tfvars:1051-1055`). **A1.** A token
  with no data role here ⇒ **403**; an invalid/wrong-tenant token ⇒ **401**.

**A3 discrepancy to surface (do not paper over):** the repo lane found the shared READ
library uses an access-key connection string; the vault lane's three-layer note says the
read path is **managed-identity (AAD)** based, and legacy FBE IaC provisioned a *separate*
FBE-specific App Config store. → Whether the **Jupiter FBE** slot reads the shared
`vpp-applicationconfig-d` via connection-string vs MI, and whether it is even the same
store the vault calls `vpp-appconfig-d`, is **A3** (resolving probe: read the FBE service
`Program.cs`/Helm for `ConnectionStrings:AppConfiguration`; `az appconfig list`).

## Store facts (A1 from fbe-ff-mechanism + vault)

- `vpp-applicationconfig-d` (RG `mcdta-rg-vpp-d-res`, sub `839af51e-…`):
  `public_network_access = "Disabled"` + **private endpoint** in the MC landing-zone
  subnet; **no IP firewall/ACL**. **A1** (`appconfig-mc-lz.tf`).
- **`local_auth` / `disableLocalAuth` is NOT set in IaC** → defaults to enabled (access
  keys live). **No appconfig IaC change in the last ~2 months** (`git log` empty since
  2026-04-22). **A1.** ⇒ an IaC-driven key-disable is NOT the cause; a **portal/manual**
  flip is still possible and is **A3** (probe `az appconfig show --query disableLocalAuth`).
- "I can see the FFs set properly in the app config" = **A2** portal/control-plane
  visibility (ARM `…/configurationStores` Reader), which is **separate** from the
  data-plane permission. Seeing values in the portal does NOT prove data-plane auth works.

## Who is involved (A1 from slack-harvest)

- **Duncan Teegelaar** — Frontend SWE, VPP & Flex Trade Optimizer; a **consumer**, not a
  platform-team member; *"I have not worked on VPP in a bit."* As of 2026-06-19 he had
  ArgoCD on acc & prd but **NOT dev-mc** (CMC ticket pending, handled by Michael Ströh).
  **A3**: no message links that dev-access gap to the App-Config 401 — candidate enabling
  factor only.
- **Jupiter** = a named **feature-branch FBE slot** (`environmentPrefix=jupiter.`,
  `jupiter.dev.vpp.eneco.com`). **A1.**

## Precedents (A1 from slack-harvest)

- **2025-07-03 (Fabrizio):** AVD-based dev getting 403 from Key Vault — *"it was using the
  AVD VM Identity … these AVD are recreated time to time."* → AVD VM managed-identity
  **drift after recreation** is a known inside-AVD auth-failure cause.
- **2025-01-30 (Nykyta):** 401 to dev-mc App Config from laptop, works from AVD → canonical
  answer "use AVD; MC networking is locked down." (laptop, not AVD).
- **2025-09-18 (Duncan himself):** FBE Kidu FF "not showing" → root cause = the App
  Configuration **pipeline was waiting for approval**; once approved, the FF appeared.
  (FF-not-present ≠ 401, but shows the approval-gated set path.)
- **Vault direct match:** *"Azure Portal 401 on App Configuration … Edge has known problems
  with private endpoint resources. Fix: use Firefox or Chrome … Ensure you are on AVD."*

## Ranked hypothesis set (NONE confirmed — live AVD-gated probe required)

Ordered by fit to the literal evidence ("401", "on AVD", "can see FFs in portal", FE
consumer, returning-to-VPP).

| # | Hypothesis | Predicts 401? | Fit | Decisive probe |
|---|-----------|--------------|-----|----------------|
| **H1** | **Interactive AVD identity not authenticated to the data plane for the set/fetch** — Duncan runs an `az appconfig`/tool from AVD with a stale/wrong-tenant `az login` (or the AAD token is invalid) | **Yes (401)** — invalid/wrong-issuer token | **High** | exact error: `401 invalid_token`/"wrong issuer" → re-`az login` to the dev-mc tenant; check `az account show` |
| **H2** | **Access-key (connection-string) read path broken** — `disableLocalAuth` flipped at portal (deletes keys) OR `connectionstrings-app-config` KV secret is stale after a key rotation | **Yes (401)** "Invalid Credential" | **High** | `az appconfig show --query disableLocalAuth`; compare KV secret vs live primary key; LL-006 rotation class |
| **H3** | **Data-plane RBAC gap** — the identity (Duncan / pipeline SP / AVD VM identity) lacks `App Configuration Data Owner` on `vpp-applicationconfig-d` (not in `sg-vpp-core-release-masters`) | **No → 403** (unless token also invalid) | **High *if* the error is actually 403** | `az role assignment list --scope <appConfigId>`; **read the exact status** |
| **H4** | **Azure Portal browser quirk** — Duncan viewing FFs in the **portal** on **Edge** hits the Edge+private-endpoint 401 | Yes (portal 401) | **Medium** (cheap to test/fix) | switch to Chrome/Firefox on AVD; vault direct-match recipe |
| **H5** | **AVD VM managed-identity drift** — the call uses the AVD VM identity, which lost its role/assignment after an AVD rebuild (Fabrizio 2025-07-03) | 401 or 403 | **Medium** | which identity made the call; `az account show`; role list on that identity |
| **H6** | **RBAC propagation delay** — a role was just granted (cf. Duncan's pending dev-mc access) and is <15 min old | transient 403 | **Low** | wait 15 min + retry; msdocs §Q6 |
| **H7** | **Network recurrence (EARLIER issue)** — AVD DNS zone not linked for this store | timeout, NOT 401 | **Very low** (excluded by literal 401) | `nslookup …azconfig.io` from AVD (private IP?) |

**Leading reading (A2):** the symptom is a **data-plane authentication/authorization
gap for the identity Duncan is using from AVD** — most likely **H1** (token) or **H3**
(role), with **H2** (access key) as the strong alternative that uniquely explains a
*literal* 401 on the connection-string read path. The **exact status code + auth error
body is the one probe that collapses the set** — it cleanly splits {H1,H2,H4} (401) from
{H3,H6} (403) from {H7} (timeout).

## Diagnosis classification

**Hypothesis Set** (per the rca-holistic claim gate + LL-009) — NOT a Verified Root
Cause. The enabling probes are live and **AVD-gated** (`mc-avd-execution-boundary`): the
agent cannot run `az`/`oc` against MC dev. Resolution path is owned by the on-call
(Alex Torres) or platform team executing the discriminator probe from AVD, or pasting
the exact failing-call error.

## Safety gates that bind the how-to-fix (one-way doors)

- **`disableLocalAuth` toggle / access-key regeneration is destructive** — disabling
  deletes ALL keys; *every* caller still using a connection string breaks with 401
  (msdocs §Q1). Re-enabling mints NEW keys; old strings still fail. → HALT for platform
  authorization before flipping; treat as platform-review change (vault §4).
- **`public_network_access` flip** — never "open up networking" on an MC store to make
  VPN work; the canonical posture is "everything through AVD" (slack precedents). Opening
  it is a security one-way door requiring platform sign-off.
- **Do NOT grant `App Configuration Data Owner` reflexively** to a frontend consumer —
  least-privilege is `Data Reader` for read; `Data Owner` only for the set/apply identity.
- **AVD-execution boundary** — all `az`/`oc` MC dev probes are executed by the on-call
  from AVD (or authorized computer-use); the agent provides the commands, not the run.
- **Verify by EFFECT** (H-EFFECT-1) — a fix is closed only when the actual call returns
  200 / the FF loads, never on an exit code.
