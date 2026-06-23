---
title: FBE / VPP Feature-Flag mechanism on Azure App Configuration (dev-mc) — auth, identity, network, recent changes, who sets FFs
type: research
status: complete
task_id: 2026-06-22-006
agent: eneco-context-repos-docs-fetcher
summary: VPP/FBE reads FFs via access-key connection string (Eneco.Vpp.Configuration.AzureAppConfiguration); FFs are SET by an ADO Terraform pipeline using a service principal over the AAD data plane, needing App Configuration Data Owner. dev-mc store vpp-applicationconfig-d is public-access-Disabled + private-endpoint-only (no IP ACL). No appconfig IaC change in last ~2mo; local_auth not disabled in IaC. Leading 401 cause = data-plane RBAC gap for the Jupiter/AVD identity, not connection-string/local-auth.
timestamp: 2026-06-22T00:00:00Z
---

# FBE / VPP Feature-Flag mechanism on Azure App Configuration (dev-mc)

Context fetch for an on-call RCA: a VPP/FBE "Jupiter" slot run/configured through AVD gets HTTP 401 calling
Azure App Configuration store `vpp-applicationconfig-d` (RG `mcdta-rg-vpp-d-res`, dev-mc sub
`839af51e-c8dd-4bd2-944b-a7799eb2e1e4`); FF values are visibly present in the store. Earlier symptom: FF
fetch worked on AVD but not VPN.

Evidence labels: A1 = file:line or cmd output witnessed this session; A2 = inferred via named reasoning;
A3 = UNVERIFIED[blocked: reason] + resolving probe. Local IaC checkout root:
`/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src` (referred to below as `$SRC`). I cannot run live
`az`; all deployed/runtime state is A3.

---

## Headline (read first)

There are TWO distinct App Config code paths, and the 401 is almost certainly on the SECOND:

- **READ path (services consume FFs at runtime):** the .NET library
  `Eneco.Vpp.Configuration.AzureAppConfiguration` connects with an **access-key CONNECTION STRING**
  (`.Connect(connectionString)`), pulled from Key Vault. `DefaultAzureCredential` is used ONLY for Key Vault
  references, not for the App Config endpoint. (A1, see Q1.)
- **WRITE / "set FF" path (what AVD-run Jupiter does):** feature flags are applied by an **Azure DevOps
  Terraform pipeline** that uses `azurerm_app_configuration_feature` / `azurerm_app_configuration_key`
  resources. These hit the App Config **data plane** with the pipeline service principal's **Entra (AAD)
  token** — NOT the connection string — and therefore require the SP to hold the
  `App Configuration Data Owner` RBAC role on the store. The pipeline source carries an explicit comment that
  the SP needs "the correct rights to read appconfig information." (A1, see Q3/Q5.)
- **A2 (most likely root cause):** the identity running the FF apply for the Jupiter slot lacks
  `App Configuration Data Owner` on `vpp-applicationconfig-d` (data-plane RBAC), so AAD-token data-plane
  calls return 401/403 even though the keys/flags are visibly present (control-plane/portal read uses a
  different permission). The store does NOT have local-auth disabled in IaC (Q3), so the connection-string
  read path is unaffected — consistent with "values are visibly present."
- **Network (Q4):** the store is `public_network_access = "Disabled"` with a **private endpoint** in the
  MC landing-zone subnet (A1). That is why AVD (inside the VNet / reaches the PE) historically resolved/
  fetched FFs while VPN did not (VPN egress is not inside the VNet, so the private DNS / PE is unreachable).
  That earlier VPN-vs-AVD symptom is a NETWORK/DNS issue, distinct from the current 401 (which is an
  AUTH/RBAC issue on the data plane).

---

## Q1 — HOW does a VPP/FBE service read/write FFs? Library + auth mode

**Client library + feature-flag engine (A1).**
`$SRC/enecomanagedcloud/myriad-vpp/Eneco.Vpp.Configuration.AzureAppConfiguration/src/Eneco.Vpp.Configuration.AzureAppConfiguration/Extensions/HostBuilderExtensions.cs`
uses `Microsoft.Extensions.Configuration.AzureAppConfiguration` + `Microsoft.FeatureManagement`
(`AddFeatureManagement` in `Extensions/ConfigurationExtensions.cs`, `IsFeatureEnabled`).

**Auth mode = ACCESS-KEY CONNECTION STRING for the App Config endpoint (A1).**
In `HostBuilderExtensions.SetupApplicationConfiguration` (same file):

```csharp
private const string _appConfigConnectionString = "ConnectionStrings:AppConfiguration";
...
var connectionString = configuration.GetValue<string>(_appConfigConnectionString);
if (string.IsNullOrEmpty(connectionString)) { /* "won't be loaded" */ return; }
...
configurationBuilder.AddAzureAppConfiguration(options =>
{
    options.ConfigureKeyVault(kv => kv.SetCredential(credentials))   // DefaultAzureCredential -> Key Vault ONLY
        .Connect(connectionString)                                    // App Config endpoint via CONNECTION STRING
        .Select(KeyFilter.Any, LabelFilter.Null)
        .Select(KeyFilter.Any, label);
    ...
    options.UseFeatureFlags(opts => { ... CacheExpirationInterval = 20s; });
});
```

- `.Connect(connectionString)` (NOT `.Connect(Uri, TokenCredential)`) ⇒ the App Config data plane is
  reached with the **access key** embedded in the connection string. (A1)
- `DefaultAzureCredential` (`Azure.Identity`) is constructed in `GetAzureCredentials(...)` and passed ONLY to
  `ConfigureKeyVault(...)` — i.e. AAD is used to resolve Key Vault references that App Config returns, not to
  authenticate to App Config itself. (A1)
- This library is **READ-only** (loads keys + `UseFeatureFlags` into `IConfiguration`); it has no FF-write API. (A1)

**Where the connection string comes from (A1).**
The connection string is provisioned into Key Vault by IaC:
`$SRC/.../MC-VPP-Infrastructure/main/terraform/appconfig-mc-lz.tf:36-44` —
`module "primary_connectionstring_appconfig"` writes KV secret `connectionstrings-app-config`
= `module.appconfig.app_configuration_primary_write_key_connection_string`. The app config key
`ConnectionStrings:AppConfiguration` is therefore expected to be wired from that KV secret (A2 — exact
appsettings/Helm wiring of `ConnectionStrings:AppConfiguration` for the FBE pod not located this session;
A3 resolving probe below).

**Who consumes it (A1).** FleetOptimizer service wires it in:
`$SRC/.../FleetOptimizer/backlog-prio1/src/FleetOptimizerGateway/FleetOptimizerGateway.API/Program.cs:20`
`builder.Host.AddCommonConfigurationProviders("FleetOptimizer", typeof(Program).Assembly)` (uses the library
above). FBE service code is expected to wire the same library with its own label (A3 — FBE service .cs/Helm
not opened this session).

**A3 / resolving probe (FBE service wiring):** locate the FBE (Flex Budget Engine) application repo and read
its `Program.cs` / `appsettings*.json` / Helm values for `ConnectionStrings:AppConfiguration` and the label.
FBE deploys to AKS (see `$SRC/.../VPP%20-%20Infrastructure/codebase/fbe/aks.tf`, `app-config.tf`); the legacy
FBE IaC `app-config.tf` provisions its OWN store `format("%s-appconfig-fbe-%s-%s", ...)` and KV secret
`connectionstrings-app-config` — so FBE historically had a SEPARATE App Config instance, distinct from the
shared `vpp-applicationconfig-d`. Resolving probe: confirm whether the Jupiter FBE slot reads/writes the
shared `vpp-applicationconfig-d` or the FBE-specific store.

---

## Q2 — WHICH IDENTITY authenticates to `vpp-applicationconfig-d` in dev-mc; what RBAC role

Two identities, by path:

1. **READ path — access key (no AAD identity).** The runtime service authenticates with the **primary
   connection string** (access key) from KV secret `connectionstrings-app-config`. No managed identity / SP /
   user is involved on the App Config endpoint for reads. (A1 — `appconfig-mc-lz.tf:39-40`, `HostBuilderExtensions.cs`.)

2. **WRITE / set-FF path — service principal via AAD, needs data-plane RBAC.**
   `App Configuration Data Owner` is the role granted on the store by IaC:
   `$SRC/eneco-temp/Eneco.Infrastructure/terraform/modules/appconfig/main.tf:12-18` —
   `resource "azurerm_role_assignment" "data_owners" { role_definition_name = "App Configuration Data Owner";
   scope = azurerm_app_configuration.app_configuration.id; principal_id = each.key }` with a code comment
   that Data Owners can "Create, Edit, Delete, Enable and Disable feature flags." (A1)
   For `vpp-applicationconfig-d`, the assigned principal is the security group
   **`sg-vpp-core-release-masters`** = `d5a241bf-f75f-4844-9485-518a6148a5d4`
   (`$SRC/.../MC-VPP-Infrastructure/main/configuration/dev.tfvars:1051-1055`). (A1)
   (The FleetOptimizer store `vpp-applicationconfig-fleetoptimizer-d` grants
   `sg-vpp-fleetoptimizer-developers` = `cef656a6-20bc-4a33-8352-a118ba3a6b09`, dev.tfvars:1057-1061.) (A1)

**Required role to SET FFs: `App Configuration Data Owner`** (Data Reader is read-only and cannot set flags). (A1)

**A2:** For an AVD-run / Jupiter-slot FF apply to succeed, the executing identity (pipeline SP, or the
interactive AVD user if applying manually) must be a member of `sg-vpp-core-release-masters` OR otherwise hold
`App Configuration Data Owner` on `vpp-applicationconfig-d`. If it is not, the AAD data-plane write 401s. The
"works in portal / values visible" observation is consistent: portal/control-plane visibility uses
ARM `Microsoft.AppConfiguration/configurationStores/*` (Reader) permissions, which are separate from the
data-plane `dataPlane/.../keyValues` permission that Data Owner grants.

**A3 / resolving probe (live):** `az role assignment list --scope <appConfigId> --include-inherited -o table`
(via MC dev SP `enecotfvppmclogindev`, read-only) to confirm whether the pipeline SP / Jupiter identity holds
`App Configuration Data Owner` on `vpp-applicationconfig-d`. The pipeline SP for the core store runs under ADO
service connection `eneco-vpp-mc-dev` (see Q5); resolve its objectId and check the role list.

---

## Q3 — RECENT change (last ~2 months) that could cause a 401

**No appconfig IaC change in the MC-VPP-Infrastructure repo within the last ~2 months (A1).**
`git log --since="2026-04-22" -- terraform/appconfig-mc-lz.tf terraform/appconfig-fleetoptimizer.tf` (run in
`$SRC/.../MC-VPP-Infrastructure/main`) returned **empty**. Most recent touches to `appconfig-mc-lz.tf` (with
dates from `git show -s`):

- `432c5a5` PR 157253 "Bump the private_endpoint terraform module" — **2026-01-09** (A1)
- `bb02480` PR 145110 "Restructuring folders... ccoe templates, eneco.infra modules" — 2025-10-21 (A1)
- `93dd532` PR 122067 "Grant vpp-core-release-masters App Configuration Data Owner rights on appconfiguration
  instances." — **2025-04-22** (A1)
- `73ce987` PR 62082 "Updated appconfig-mc-lz.tf to disable public network" — 2023-10-27 (A1)

(PR numbers and dates are A1 from `git log`/`git show` — not invented.)

**Local-auth / disableLocalAuth is NOT set anywhere in this repo's IaC (A1).**
`grep -rn "local_auth\|disableLocalAuth\|disable_local_auth" terraform/ configuration/` returned **no hits**.
The canonical `azurerm_app_configuration` resource
(`Eneco.Infrastructure/terraform/modules/appconfig/main.tf:1-7`) sets only `name`, `resource_group_name`,
`location`, `public_network_access`, `sku`, `tags` — it does NOT set `local_auth_enabled`, so it defaults to
`true` (access keys enabled). ⇒ The "disableLocalAuth flipped" hypothesis is **NOT supported by IaC**. (A1 +
A2 on the azurerm default.)

**A2:** Because local auth is still enabled and the connection-string READ path is intact, a 401 specifically
on the SET-FF path points to a **data-plane RBAC** condition (Q2), not a connection-string rotation or a
local-auth disable. The Jupiter slot is a **feature-branch environment** (see Q5 — pipeline `environmentPrefix`
comment names `jupiter.`); a likely trigger is a new/renamed pipeline SP, an expired/rotated SP secret, or a
group-membership/role-assignment gap for the Jupiter run that was never granted `App Configuration Data Owner`.

**A3 / resolving probe:** check the FF-apply ADO pipeline run history for the Jupiter slot (the
`appconfiguration/devmc.pipeline.yml` run) for the failing run's error; and check ADO for any recent change to
service connection `eneco-vpp-mc-dev` or the SP secret. Also check the App Config store's
`Microsoft.AppConfiguration/configurationStores` for `disableLocalAuth` live
(`az appconfig show -n vpp-applicationconfig-d --query disableLocalAuth`) to rule out a portal/manual flip not
captured in IaC.

---

## Q4 — dev-mc NETWORK model for `vpp-applicationconfig-d`; why VPN ≠ AVD

**Public access DISABLED + private endpoint only (A1).**
`$SRC/.../MC-VPP-Infrastructure/main/terraform/appconfig-mc-lz.tf:9-12`:
`app_configuration_sku_and_networking = { sku = "standard"; public_network_access = "Disabled" }`.
`appconfig-mc-lz.tf:20-34` `module "private_endpoint_appconfig_mc_lz"` creates a private endpoint
(subresource `configurationStores`) bound to `data.azurerm_subnet.default_subnet_mc_lz.id` (the MC landing-zone
default subnet). (A1)

**No IP firewall / network ACL in IaC (A1).** `grep "network_acls\|ip_rules\|firewall"` over `appconfig*.tf`
returned only the two `public_network_access = "Disabled"` lines — there is NO IP-allowlist on the store.
Access is binary: inside-VNet via the private endpoint, or blocked. (A1)

**A2 — why VPN differed from AVD (earlier fetch symptom):** With `public_network_access = Disabled`, the store
is reachable only by resolving its private DNS (`*.azconfig.io`) to the private-endpoint IP and routing inside
the VNet. AVD session hosts live inside (or peered to) the MC landing-zone VNet, so they resolve the PE and
reach the store; the VPN client's egress is NOT inside that VNet and (typically) does not get the private DNS
zone / PE route, so the same call fails at the network/DNS layer. That earlier symptom is **network**, distinct
from the current **401 = auth**. The two should not be conflated in the RCA.

**A3 / resolving probe (live):** `az appconfig show -n vpp-applicationconfig-d -g mcdta-rg-vpp-d-res
--query "{pna:publicNetworkAccess, dla:disableLocalAuth}"` and `nslookup vpp-applicationconfig-d.azconfig.io`
from AVD vs VPN to confirm PE resolution; `az network private-endpoint list -g mcdta-rg-vpp-d-res` to confirm
the PE exists as deployed.

---

## Q5 — WHO sets FFs and HOW

**An Azure DevOps Terraform pipeline sets FFs (A1).** The core store is driven by:
`$SRC/.../Myriad%20-%20VPP/development/azure-pipeline/pipelines/appconfiguration/devmc.pipeline.yml`
(plus the FleetOptimizer-store variant
`$SRC/.../FleetOptimizer/backlog-prio1/azure-pipeline/appconfiguration/devmc.pipeline.yaml`).

Core-store pipeline parameters (A1, devmc.pipeline.yml):
- `appConfigurationName: vpp-applicationconfig-d`, `appConfigurationResourceGroupName: mcdta-rg-vpp-d-res`
- `serviceConnection: eneco-vpp-mc-dev` (the ARM service connection ⇒ a **service principal**)
- `pool: self-hosted-mcdev-k8s` (agent runs INSIDE the MC dev k8s cluster ⇒ inside the VNet ⇒ can reach the PE)
- `trigger: none` (manual run), `terraformStatefileName: vpp.core.appconfiguration.tfstate`
- approval gate via ADO environment `vpp-core-appconfiguration-devmc`

**How the apply touches App Config (A1).** The shared template
`$SRC/.../Eneco.Pipelines/azure-appconfiguration/mc.pipeline.template.yml` runs Terraform from
`$SRC/.../Eneco.Pipelines/azure-appconfiguration/appconfiguration/main.tf`, which declares the FF/config as
data-plane resources:
- `azurerm_app_configuration_key "configs"` (main.tf:114)
- `azurerm_app_configuration_key "key_vault_references"` (main.tf:124)
- `azurerm_app_configuration_feature "feature_flags"` (main.tf:134)
all with `configuration_store_id = var.app_configuration_id`. (A1)
The azurerm provider writes these through the **App Config data plane using the SP's AAD token** (provider block
`main.mc.tf`, azurerm 3.61.0; backend `use_azuread_auth = true`). (A1)

**The smoking-gun comment (A1).** `appconfiguration/main.tf:1-7` and the
`mc.pipeline.template.yml` `appConfigurationId` parameter doc both state the SP must be "assigned the correct
rights on the azure appconfig service" to read/write App Config — i.e. the apply is gated on the SP holding
`App Configuration Data Owner`. If that role is missing for the identity running the Jupiter apply, the
`azurerm_app_configuration_feature` write returns 401/403. (A1 → A2 on the 401 mechanism.)

**Jupiter = a feature-branch environment / slot (A1, strong).** The template parameter doc:
`mc.pipeline.template.yml` `environmentPrefix` — *"Parameter value should be followed by a period (e.g.
jupiter.) ... currently used for feature branch environments that have a prefix before .dev.vpp.eneco.com
(e.g. jupiter.dev.vpp.eneco.com)"*. So "Jupiter" is a named feature-branch slot whose FFs are set through this
same App Config pipeline (with `environmentPrefix=jupiter.`). (A1)

**Other ways FFs could be set (A2/A3):** a human could `az appconfig feature set` interactively from AVD using
their own AAD identity — which would ALSO need `App Configuration Data Owner` and would 401 without it.
Whether the Jupiter incident was a pipeline run or a manual AVD `az appconfig` is **A3** — resolving probe:
the failing 401 call's source (ADO pipeline run log vs an interactive `az` from the AVD session).

---

## Hypothesis scoreboard (for the coordinator — do not converge prematurely)

- **H1 disableLocalAuth flipped → connection-string reads 401:** NOT supported by IaC (Q3, no local_auth flag;
  defaults true) and inconsistent with "FF values visibly present / reads work." Likely FALSE. Confirm live with
  `az appconfig show ... --query disableLocalAuth` (rules out a portal-only flip). (A2)
- **H2 network (PE/DNS) → unreachable:** explains the EARLIER VPN-vs-AVD fetch symptom, NOT the current 401
  (401 = auth, not connectivity; a network failure would be a timeout/NXDOMAIN/connection-refused, not 401).
  Likely a SEPARATE earlier issue. (A2)
- **H3 data-plane RBAC gap → AAD 401 on SET-FF (LEADING):** the Jupiter/AVD identity (pipeline SP `eneco-vpp-mc-dev`
  or interactive AVD user) lacks `App Configuration Data Owner` on `vpp-applicationconfig-d`. Strongly consistent
  with all observations (set fails, values present, reads via key unaffected). Confirm with the live role-assignment
  probe in Q2. (A2 — leading hypothesis, not yet confirmed by live RBAC read.)

---

## Evidence index (paths witnessed this session)

- App Config IaC (store + PE + KV connection string): `$SRC/.../MC-VPP-Infrastructure/main/terraform/appconfig-mc-lz.tf`
- FleetOptimizer store IaC: `$SRC/.../MC-VPP-Infrastructure/main/terraform/appconfig-fleetoptimizer.tf`
- data_owners values: `$SRC/.../MC-VPP-Infrastructure/main/configuration/dev.tfvars:1051-1061`
- store-name vars (`project=vpp`, `environmentShort=d`): `dev.tfvars:3-6`
- canonical appconfig module (RBAC role + no local_auth): `$SRC/eneco-temp/Eneco.Infrastructure/terraform/modules/appconfig/main.tf`, `variables.tf`
- client read library: `$SRC/.../Eneco.Vpp.Configuration.AzureAppConfiguration/src/.../Extensions/HostBuilderExtensions.cs`, `ConfigurationExtensions.cs`
- FleetOptimizer service wiring: `$SRC/.../FleetOptimizer/backlog-prio1/src/FleetOptimizerGateway/FleetOptimizerGateway.API/Program.cs:8,20`
- core FF pipeline: `$SRC/.../Myriad%20-%20VPP/development/azure-pipeline/pipelines/appconfiguration/devmc.pipeline.yml`
- FleetOptimizer FF pipeline: `$SRC/.../FleetOptimizer/backlog-prio1/azure-pipeline/appconfiguration/devmc.pipeline.yaml`
- FF apply Terraform (data-plane resources + SP-rights comment): `$SRC/.../Eneco.Pipelines/azure-appconfiguration/appconfiguration/main.tf`, `mc.pipeline.template.yml`, `main.mc.tf`
- legacy FBE-specific App Config IaC: `$SRC/.../VPP%20-%20Infrastructure/codebase/fbe/app-config.tf`, `aks.tf`

Note: where multiple working-branch copies of the same file exist (e.g. FleetOptimizer `backlog-prio1`,
`hotfix`, `pr-review1`), I cited one representative copy; they are duplicates of the same pipeline/program.
