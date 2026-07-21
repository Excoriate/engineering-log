---
task_id: 2026-07-19-003
agent: eneco-sre (coordinator)
status: complete
summary: Consolidated A1 live evidence ledger for FBE feature-flag 401 RCA — cluster, Azure, and repo facts.
timestamp: 2026-07-19T00:00:00Z
---

# Live-Probe Findings — FBE feature-flag 401 (consolidated A1 evidence)

All probes run 2026-07-19 by the coordinator against live Sandbox AKS `vpp-aks01-d`
(kube-context `vpp-aks01-d`, authinfo `clusterUser_rg-vpp-app-sb-401`) and the Sandbox
subscription `7b1ba02e-bac6-4c45-83a0-7f0d3104922e`. Secrets redacted throughout.

## A1 — the browser→App Config credential chain (frontend pod)

- Frontend Deployment `frontend` (Helm chart `frontend-0.4.2`, ArgoCD tracking-id
  `<slot>_frontend`) has init container **`init-myservice`** whose sole command is:
  `echo window.VUE_APP_AZ_CONFIG_CONNECTION_STRING = "${connectionstrings_appconfig}" > /etc/nginx/html/appconfig/appconfig.js`
- `connectionstrings_appconfig` env ← `secretKeyRef{name: application-secret, key: connectionstrings_appconfig}`
  (same on init AND main container).
- `appconfig.js` is written into volume **`mydir` (emptyDir: {})** mounted at `/etc/nginx/html/appconfig`
  → frozen once at pod start; regenerated ONLY on pod (re)start.
- Live read of `jupiter` pod `frontend-7db976fcb-g8sbw`:
  `window.VUE_APP_AZ_CONFIG_CONNECTION_STRING = "Endpoint=https://vpp-appconfig-fbe-jupiter-vlt.azconfig.io;Id=[REDACTED];Secret=[REDACTED]"`
- CSI `SecretProviderClass secret-provider-kv` (provider=azure, keyVault=`vpp-fbe-jupiter-vlt`)
  `secretObjects` maps KV `connectionstrings-app-config` → K8s `application-secret[connectionstrings_appconfig]`.
- Browser SPA calls App Config data plane `/.appconfig.featureflag/*` over **HMAC** — `401 = credential`,
  not RBAC 403, not network 403.

## A1 — NO refresh mechanism exists

- `podAnnotations: {}` (chart default) and none set in `VPP-Configuration/Helm/frontend/sandbox/values.yaml`
  → **no `reloader.stakater.com/*` annotation, no config-checksum annotation.**
- Stakater Reloader controller: **absent** cluster-wide (`kubectl get deploy -A | grep -i reload` → none;
  repo grep for `stakater`/`reloader.stakater.com` → no results).
- Frontend `readinessProbe`/`livenessProbe` = `httpGet /healthz` only → a pod serving a dead credential
  still reports **Ready** (probe does not validate App Config).
- CSI secrets-store driver (ns `csi`) args: **`--enable-secret-rotation=true --rotation-poll-interval=2s`**
  → the driver keeps `application-secret` current, but rotation NEVER re-runs the init container
  (init-once + emptyDir), so `appconfig.js` stays frozen.

## A1 — FROZEN-SNAPSHOT DRIFT reproduced live across the fleet (2026-07-19)

Per-slot comparison of the running pod's BAKED `appconfig.js` endpoint vs the CURRENT
`application-secret` endpoint (SHA-256 of the full connection string; secret bytes never printed):

| slot | pod started | restarts | BAKED store (frozen in pod) | CURRENT store (secret/KV) | drift |
|------|-------------|----------|-----------------------------|---------------------------|-------|
| boltz  | 2026-07-08 | 0 | `vpp-appconfig-fbe-boltz-qzz`  | `vpp-appconfig-fbe-boltz-tec`  | **DRIFT** |
| ishtar | 2026-07-13 | 0 | `vpp-appconfig-fbe-ishtar-oyn` | `vpp-appconfig-fbe-ishtar-xql` | **DRIFT** |
| kidu   | 2026-07-16 | 0 | `vpp-appconfig-fbe-kidu-dfm`   | `vpp-appconfig-fbe-kidu-gqk`   | **DRIFT** |
| thor   | 2026-07-16 | 0 | `vpp-appconfig-fbe-thor-dyf`   | `vpp-appconfig-fbe-thor-ubn`   | **DRIFT** |
| veku   | 2026-07-17 | 0 | `vpp-appconfig-fbe-veku-ckg`   | `vpp-appconfig-fbe-veku-xsy`   | **DRIFT** |
| jupiter| 2026-07-07 | 0 | `vpp-appconfig-fbe-jupiter-vlt`| `vpp-appconfig-fbe-jupiter-vlt`| match (healthy) |

All drifted pods have `restarts=0` → they still hold the ORIGINAL baked credential;
`application-secret` has since moved to a newer store. **5 of 7 active FBE slots are, at the time
of investigation, serving a stale credential** and would show Duncan's 401 / missing-Tennet-NL symptom
until their frontend pod is restarted.

## A1 — the baked stores are GONE from Azure (proves the failure)

`az resource list -g rg-vpp-app-sb-401 --resource-type Microsoft.AppConfiguration/configurationStores
--subscription 7b1ba02e-...`:

- EXIST (live): `vpp-appconfig-fbe-{boltz-tec, ishtar-xql, jupiter-vlt, kidu-gqk, thor-ubn, veku-xsy}`
- GONE (baked into pods, deleted): `vpp-appconfig-fbe-{boltz-qzz, ishtar-oyn, kidu-dfm, thor-dyf, veku-ckg}`

## A1 — HTTP behaviour discriminates the two surface variants

Unauthenticated `GET https://<store>/kv?api-version=1.0`:

- LIVE store (`…boltz-tec`, `…jupiter-vlt`) → DNS `appconfigservice-production-westeurope.trafficmanager.net`,
  **HTTP 401 `www-authenticate: HMAC-SHA256`** ← exactly Duncan's reported symptom (store exists, credential rejected).
- DELETED store (`…boltz-qzz`) → does not resolve, `HTTP=000` (connection fails).

→ Duncan's clean **401** corresponds to the variant where the pod presents a stale/rotated HMAC
credential to a store that still resolves (rotated keys / brief store overlap). The aged-fleet variant
(store fully deleted) surfaces as a connection error. **Same root cause, two timing variants.**

## A1 — Terraform: why store identity changes (`VPP - Infrastructure/terraform/fbe/`)

- `app-config.tf`:
  - `app_configuration_name = format("%s-appconfig-fbe-%s-%s", var.project-prefix, var.environment, random_string.random.result)`
  - `key_vault_secret_name = "connectionstrings-app-config"`,
    `key_vault_secret_value = module.appconfig.app_configuration_primary_write_key_connection_string`
    → the browser is handed the **primary WRITE key** (security smell).
- `common.tf`: `random_string.random` length=3, `keepers = { id = "<prefix>-random-fbe-<environment>" }`
  (environment = slot). Keeper is stable per slot → suffix is stable WITHIN a Terraform state;
  it regenerates only when the slot's state is torn down and rebuilt (**delete pipeline `2629`
  `terraform destroy` → create `2412`**), producing a **new store name + new HMAC keys** (ForceNew).
- appconfig module `Eneco.Infrastructure/terraform/modules/appconfig/output.tf` currently exposes ONLY
  `app_configuration_primary_write_key_connection_string` (→ `azurerm_app_configuration…primary_write_key[0].connection_string`).

## A1 — Pipeline ordering (from GitOps source extract, sidecar gitops-pipeline-source-extract.md)

- Create pipeline `azure-pipelines-featurebr-env.yml`: `DeployInfra` (TF writes KV secret) →
  `keyvaultandappconfigentries` → `DeployServices` → `DeployFBEInArgoCD` (commits `{slot}.yaml`,
  triggers ArgoCD, then a **blind 180s sleep**). First-create ordering is CORRECT.
- The credential reaches the pod out-of-band (TF→KV→CSI→secret→init→emptyDir), so it is **invisible to
  the Deployment manifest ArgoCD reconciles** → on a store recreate ArgoCD sees no diff → **never rolls
  the frontend pod** → frozen appconfig.js.
- ApplicationSet `VPP.GitOps/argocd-configuration/applicationsets/vpp-feature-branch-environments.yaml`
  (git generator, automated prune+selfHeal, no sync-wave).

## Fix-target files (all pulled to latest 2026-07-19)

- Frontend chart template: `Myriad - VPP/azure-pipeline/Helm/frontend/templates/deployment.yaml` (chart 0.4.2)
- FBE frontend env values: `VPP-Configuration/Helm/frontend/sandbox/values.yaml`
- FBE App Config TF: `VPP - Infrastructure/terraform/fbe/app-config.tf` (+ module output in `Eneco.Infrastructure/terraform/modules/appconfig/output.tf`)
- FBE create pipeline: `Myriad - VPP/.../azure-pipelines-featurebr-env.yml`
- Reloader install (if chosen): `VPP.GitOps` ArgoCD application

## Precedent / prior knowledge

- Jun-2026 RCA `log/.../2026_june/2026_06_22_003_feature_flags_fbe_duncan/rca.md`: same symptom, framed as
  TRANSIENT provisioning-window that SELF-RESOLVED on pod rebuild; **no permanent fix shipped**; left open
  "why the credential was rejected while the store key was valid." This RCA closes that gap.
- Vault `fbe-failure-modes-catalog.md` F22: documents the transient variant; fix of record "wait for rebuild";
  no permanent fix documented → the permanent fix here is net-new engineering.
