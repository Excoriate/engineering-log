---
task_id: 2026-05-12-003
agent: sherlock-holmes
timestamp: 2026-05-12T14:05:00+02:00
status: complete
summary: |
  Adversarial attack on AADSTS650057 hypothesis-set completeness for johnson.lobo
  AVD E2E test failure. Found FOUR new hypotheses not falsified by current evidence,
  THREE of which change the recommended fix if confirmed. Verdict: REQUEST_PROBE
  before shipping fix (a)/(b) as advised. The strongest unrevoked alternative is
  H7 (Bruno misconfigured with az CLI client_id) and H8 (teammates riding a
  pre-PR-172140 refresh-token cache that johnson never obtained).
---

# Sherlock Adversarial Receipt — AADSTS650057 Hypothesis Completeness Attack

## Key Findings

- new_hypotheses: 4
- overlaps_h6: 2
- weak: 1
- verdict: REQUEST_PROBE
- top_attack: H7 — Bruno misconfigured with `client_id=04b07795` (Azure CLI's well-known id) instead of `0abb4cf9-...`
- second_attack: H8 — Teammate refresh-token cache predates tenant state; johnson is the only one hitting the fresh interactive consent path

## Frame of Attack

Win condition: surface a hypothesis whose truth changes the recommended fix
(option-a Bruno / option-b E2E SP client credentials). Verification of the
existing hypothesis set is OUT of scope; this is a completeness demolition.

The shipped fix assumes **the request was made by Microsoft Azure CLI directly
on behalf of johnson.lobo, and the failure is due to client choice**. Every
attack below tries to break ONE link in that chain:

| Link | What if broken |
|------|----------------|
| "Client was actually Microsoft Azure CLI" | Fix (a)/(b) misidentifies the actor |
| "Teammates succeed because they use Bruno or E2E SP" | Teammate success has a different cause; fix (a)/(b) may not work for johnson either |
| "preAuth empty is THE blocker" | A different control plane (CA, MSAL cache, broker) is gating the request |
| "All clients see the same AAD state" | johnson's environment differs in a way that changes the token-acquisition shape |

---

## Findings

### Finding H7 — Bruno (or E2E harness) misconfigured to reuse Azure CLI client_id

- **Finding**: johnson.lobo's E2E harness or Bruno config may have `client_id=04b07795-8ddb-461a-bbee-02f9e1bf7b46` (Azure CLI's well-known public client id) instead of the BTM Hermes API's own id `0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3`. The Azure CLI client_id is a famous "copy-paste from Stack Overflow" footgun because it's pre-consented in every tenant for `https://management.azure.com` and people assume it works for arbitrary custom APIs. The error string `Client app ID: 04b07795-...` then surfaces verbatim even though the user never typed `az`.
- **Falsifying probe**:
  ```bash
  # Ask johnson.lobo to paste the EXACT command/config he ran. Specifically:
  # 1. If using bruno: open the E2E collection's Auth tab and check client_id
  # 2. If using a shell wrapper: cat the script and grep for the client_id
  # 3. If using az: capture `az config get` and the full command line + flags
  # Discriminator: client_id == 04b07795 in Bruno config → CONFIRMED H7
  ```
- **If confirmed → fix changes to**: Do NOT advise "use Bruno" generically.
  Advise: "**Verify your Bruno collection uses client_id=0abb4cf9-...
  (BTM Hermes API's own appId), NOT 04b07795 (Azure CLI). The redirect URI
  http://localhost/bruno/callback only works when paired with the API's own
  client_id.**" Option (b) E2E SP credentials also requires explicit appId
  callout — if johnson copied an old script that used `04b07795`, swapping to
  Bruno without correcting the client_id changes nothing.
- **Classification**: **NEW**

### Finding H8 — Teammates ride cached refresh tokens from pre-PR-172140 state; johnson is the only one on a fresh interactive path

- **Finding**: AAD refresh tokens, once issued under a consent state, remain
  redeemable for the resource even if the underlying preAuth/consent state
  later changes (until revocation or 90-day inactivity). Hypothesis: at some
  prior point (e.g., before PR 172140 cleaned up the app registration, or
  during a window where preAuth contained Azure CLI), teammates obtained
  refresh tokens for `api://0abb4cf9-.../Device.Write`. Their `az` invocations
  silently redeem the cached RT and succeed. Johnson — having never been
  through that window — hits the fresh interactive path which now correctly
  enforces the (currently empty) preAuth list and fails.
  This hypothesis EXPLAINS the otherwise-paradoxical observation that
  teammates succeed with az despite `preAuthorizedApplications: []`.
- **Falsifying probe**:
  ```bash
  # Probe one or two teammates' MSAL cache state:
  # macOS: cat ~/.azure/msal_token_cache.json | jq '.RefreshToken | keys'
  # Linux: same path under $HOME/.azure
  # Windows: %USERPROFILE%\.azure\msal_token_cache.json
  # Discriminator: search for entries with client_id 04b07795 AND
  # target_or_resource containing 0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3.
  # Alt probe: ask teammate to run `az account clear && az login` THEN retry the
  # E2E command. If teammate now ALSO gets AADSTS650057 → H8 CONFIRMED.
  ```
- **If confirmed → fix changes to**: The ROOT cause is **misconfigured app
  registration that worked by accident via refresh-token grace**, not "wrong
  client choice." Fix shifts from advising johnson to switch clients to
  **adding `preAuthorizedApplications` containing `04b07795` (Azure CLI) OR
  fixing the IaC to add `knownClientApplications` to make this convention
  explicit**. Otherwise, all teammates will eventually rotate cache and the
  whole team will hit johnson's error within 90 days.
- **Classification**: **NEW** — and high-blast-radius if true.

### Finding H9 — Per-user OAuth2PermissionGrant (delegated consent) exists for teammates but not johnson

- **Finding**: AAD permits `oAuth2PermissionGrants` (delegated consent records)
  on a per-user `principalId` OR tenant-wide (`consentType: AllPrincipals`).
  If preAuth is empty BUT a tenant admin previously granted user-scoped
  consent on `04b07795 → api://0abb4cf9-.../Device.Write` for individual
  teammates (`consentType: Principal`), those teammates would succeed via az
  CLI. Johnson, lacking the per-principal grant, fails with the literal error
  shown — because preAuth/knownClient ALSO empty means there's no other
  bypass path. Note: a `principalId`-scoped grant is consistent with the
  empty preAuth + `appRoleAssignmentRequired=false` + working-for-some-users
  pattern.
- **Falsifying probe**:
  ```bash
  # Graph query:
  az rest --method GET \
    --uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?\$filter=clientId eq '<SP-objectId-of-Azure-CLI-in-tenant>' and resourceId eq '<SP-objectId-of-BTM-Hermes-API>'"
  # Then list principalIds returned; if all working teammates' object IDs
  # appear and johnson's does NOT → H9 CONFIRMED.
  # SP object id (not appId) for Azure CLI tenant SP:
  az ad sp show --id 04b07795-8ddb-461a-bbee-02f9e1bf7b46 --query id -o tsv
  ```
- **If confirmed → fix changes to**: Add johnson's `principalId` to the
  delegated grant, OR (preferred) convert to tenant-wide
  `consentType: AllPrincipals`, OR fix IaC properly with
  `preAuthorizedApplications`. Advising Bruno/E2E-SP would mask the real
  configuration drift and create future surprises (e.g., new joiners failing
  for the same reason).
- **Classification**: **NEW**

### Finding H10 — Resource-string canonicalization: `api://` URI vs GUID resource

- **Finding**: AAD has known quirks where requests using the `api://<guid>`
  URI form vs the bare `<guid>` form vs the resource's verified domain
  (`https://hermesapi.eneco.com` if any) are normalized differently by the
  v1.0 token endpoint. The error literally echoes
  `Resource value from request: api://0abb4cf9-...` — meaning johnson's
  client sent that string. If teammates send `<guid>` or a custom App ID URI
  form, normalization may match a different code path. WEAK because the
  Resource app ID echoed (`0abb4cf9`) matches the request, so AAD DID resolve
  it; the failure is genuinely at the preAuth check, not at resource
  identification. Including for completeness — likely OVERLAPS-H6.
- **Falsifying probe**:
  ```bash
  # Have a working teammate run with explicit api:// form:
  az account get-access-token --resource "api://0abb4cf9-70e9-4acf-9ad9-b0a75af7ace3"
  # If teammate also fails with the same string form → H10 falsified, NOT a
  # canonicalization issue. If teammate succeeds → unlikely but worth noting.
  ```
- **If confirmed → fix changes to**: Document required scope form in the E2E
  readme. (Marginal value; this hypothesis is weak.)
- **Classification**: **WEAK / OVERLAPS-H6**

### Finding H11 — AVD WAM broker / Conditional Access device-state interception (the "AVD confound")

- **Finding**: On AVD (Windows multi-session), az CLI ≥2.61 defaults to using
  the WAM (Web Account Manager) broker for token acquisition. WAM uses a
  different redirect URI (`ms-appx-web://Microsoft.AAD.BrokerPlugin/...`) and
  surfaces a different client context to AAD. While WAM does NOT bypass
  preAuth validation, AVD-specific Conditional Access policies (device
  compliance, sign-in frequency, session controls) can pre-empt the token
  request with a different error class — BUT can ALSO, under certain device
  compliance grants, cause AAD to evaluate the request against a *different
  application identity* (the WAM broker app `29d9ed98-a469-4536-ade2-f981bc1d605e`
  Microsoft Authentication Broker) rather than az CLI directly. This is a
  long-shot — AADSTS650057 is normally not the error class CA returns — but
  AVD adds enough environmental complication that a probe is cheap.
- **Falsifying probe**:
  ```bash
  # On johnson's AVD session:
  az version                                   # confirm version
  az config get core.enable_broker             # WAM broker status
  az login --use-device-code                   # bypass WAM entirely
  # Then retry E2E. If WAM bypass changes the error → H11 partial confirm.
  # Also collect: echo $env:WSLENV, hostname, and check if running inside
  # AVD via reg query "HKLM\SOFTWARE\Microsoft\Terminal Server Client".
  ```
- **If confirmed → fix changes to**: Advise johnson to run with
  `az login --use-device-code` to bypass WAM until the AVD CA policy /
  broker configuration is fixed at platform level. Note that this would NOT
  fix the underlying preAuth issue — it would only confirm that the AVD
  broker layer is adding a second failure mode on top.
- **Classification**: **NEW** (does not by itself change the fix, but
  changes the diagnostic message johnson should give the platform team).

### Finding H12 — terraform-azuread provider with `use_cli=true` shape

- **Finding**: The user described "E2E tests on AVD." If the harness invokes
  `terraform plan/apply` against AAD or graph resources (e.g., to seed test
  data), the terraform-azuread provider with `use_cli = true` reuses the
  authenticated az CLI session AND issues token requests using AAD client id
  `a0c73c16-3939-4e62-8e1d-d7c9f4ef38a3` (terraform-azuread's well-known
  client). HOWEVER — the error explicitly names `Client app ID: 04b07795`
  (Azure CLI), so terraform-azuread is NOT the actor unless the provider was
  configured with `client_id = "04b07795-..."` manually (unusual but
  possible). LIKELY-WEAK — listed for completeness on user's lane 3.
- **Falsifying probe**:
  ```bash
  # Check whether E2E framework runs terraform:
  # grep -rE "(terraform|tofu)" <repo>/e2e/
  # If yes, dump provider blocks:
  # grep -rA5 "provider \"azuread\"" <repo>
  # Discriminator: explicit client_id="04b07795" in azuread provider block.
  ```
- **If confirmed → fix changes to**: Remove the explicit client_id override
  from the azuread provider block; let it use its default.
- **Classification**: **WEAK / OVERLAPS-H6**

---

## Search-space audit (what I AM ruling out)

| Lane | Ruled out because |
|------|-------------------|
| Conditional Access policy (lane 4 partial) | CA returns 50xxx/53xxx family; AADSTS650057 is a permission/resource validation failure, not CA. Probing CA further = ROI-negative unless H11 surfaces a CA-AVD interaction. |
| Guest/B2B/external user | Eneco-home UPN, member, externalUserState null — falsified upstream. |
| Tenant boundary / wrong tenant | Resource resolved (`Resource app ID: 0abb4cf9` echoed in error); AAD found the SP in johnson's tenant. |
| Disabled SP or disabled user | If user/SP disabled, error would be AADSTS50057/700016/etc. — different family. |
| Missing api scope | Scope `Device.Write` exists per probe; error explicitly says resource not in client's permission list, not scope-not-found. |

## Meta-Falsifier on my own attack

- Could H7-H11 ALL be wrong and the shipped fix be correct? **YES, plausibly**
  — if johnson literally typed `az account get-access-token --resource
  api://0abb4cf9-...` from a script he wrote himself with no shared cache,
  H6 alone explains it. But the question was "is the hypothesis set
  COMPLETE?" — and given the user explicitly noted that teammates succeed,
  the set is **NOT complete** until at least H8 (cached RT) or H9 (per-user
  consent) is probed, because either would mean the fix is partial.
- Strongest remaining doubt: I have no evidence either way for H7-H12 from
  the prompt. The single highest-ROI probe is asking johnson to paste the
  EXACT command/config — that one artifact decides H6 vs H7 immediately.

## Recommended next action for coordinator (one cheap probe before shipping)

1. AskUserQuestion to relay to johnson.lobo: "Paste the EXACT command or
   Bruno config you ran when you got AADSTS650057, including any client_id
   value." Cost: 1 message. Belief change: discriminates H6 (use a different
   client) from H7 (you're already using Bruno but pointed at the wrong
   client_id) — these have OPPOSITE fixes.
2. In parallel: ask one working teammate to run
   `az account clear && az login && <retry E2E>`. Cost: 2 minutes of their
   time. Belief change: if teammate now fails, H8 confirmed → IaC fix
   required, advisory fix insufficient.

---

SHERLOCK_VERDICT: REQUEST_PROBE
