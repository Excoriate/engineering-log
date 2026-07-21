---
title: FBE frontend appconfig.js "frozen-once" 401 — GitOps/Pipeline/Terraform source extract
status: complete
timestamp: 2026-07-19T00:00:00Z
task_id: 2026-07-19-003
agent: eneco-context-repos source-extraction sidecar
summary: Verbatim ADO source extract answering Q1-Q6 for the FBE feature-flag 401 RCA — frontend Helm chart (no reloader/checksum/sync-wave/appconfig-probe), KV connection-string write ordering, App Config key-recreate mechanism, CSI rotation absence, and the idiomatic fix surfaces.
---

# FBE feature-flag 401 — GitOps / Pipeline / Terraform source extract

## Provenance

- ADO org `enecomanagedcloud`, project `Myriad - VPP`. Fetched live via `eneco-context-repos` scripts (`AZURE_DEVOPS_PAT` present). All fetches used each repo's DEFAULT branch unless noted.
- Evidence labels: **A1 FACT** = quoted from source fetched this session; **A2 INFER** = derived from A1 + named reasoning; **A3 UNVERIFIED[blocked/unknown]**.
- Repos touched: `Myriad - VPP` (86MB monorepo — frontend chart + pipelines), `VPP.GitOps` (ArgoCD ApplicationSet + per-slot files), `VPP - Infrastructure` (`/terraform/fbe`), `Eneco.Infrastructure` (appconfig module), `VPP-Configuration` (frontend env values).
- NOTE: there is **no** `Eneco.Vpp.FeatureBranchEnvironment`, `Eneco.Vpp.Frontend`, or `Eneco.Vpp.GitOps` repo. The FBE machinery is split across the four repos above (A1 — `ado-list-repos`/`ado-repo-search` returned no such repos).

---

## Q1 — Frontend Helm chart: init container + reload/probe surfaces

**Chart identity (A1):** `Myriad - VPP` repo, `/azure-pipeline/Helm/frontend/Chart.yaml`:

```yaml
apiVersion: v2
name: frontend
version: 0.4.2
appVersion: latest
```

**Init container writes appconfig.js into emptyDir (frozen-once) — CONFIRMED A1.**
`Myriad - VPP` repo, `/azure-pipeline/Helm/frontend/templates/deployment.yaml`:

```yaml
      initContainers:
      - name: init-myservice
        image: "{{ .Values.image.registry }}/{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        env:
          - name: connectionstrings_appconfig
            valueFrom:
              secretKeyRef:
                name: application-secret
                key: connectionstrings_appconfig
        command: ["/bin/sh"]
        args:
          - -c
          - >-
            echo window.VUE_APP_AZ_CONFIG_CONNECTION_STRING = \"${connectionstrings_appconfig}\" > /etc/nginx/html/appconfig/appconfig.js
        {{- with .Values.volumeMounts }}
        volumeMounts:
        {{- toYaml . | nindent 10 }}
        {{- end }}
```

**The `mydir` mount IS an emptyDir (A1).** `VPP-Configuration` repo, `/Helm/frontend/sandbox/values.yaml` (the FBE/sandbox values — contains `feature_flags_featurebranch`, so this is the file applied to FBE slots):

```yaml
volumes:
  - name: vpp-vue-config-volume
    configMap:
      name: vpp-vue-config
  - name: secrets-store-inline
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: secret-provider-kv
  - name: mydir
    emptyDir: {}

volumeMounts:
  - name: vpp-vue-config-volume
    mountPath: /etc/nginx/html/config.js
    subPath: config.js
  - name: mydir
    mountPath: /etc/nginx/html/appconfig
  - name: secrets-store-inline
    mountPath: "/mnt/secrets-store"
    readOnly: true
```

So the init container writes `/etc/nginx/html/appconfig/appconfig.js` into the `mydir` **emptyDir** → written exactly once at pod init, never re-written for the pod's lifetime. A2: nginx serves that static file; the browser reads `window.VUE_APP_AZ_CONFIG_CONNECTION_STRING` from it.

**What IS present (A1):**
- readiness/liveness probes — but they hit nginx `/healthz`, NOT the App Config data plane. Same `sandbox/values.yaml`:

```yaml
readinessProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: 3
  periodSeconds: 5
livenessProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: 3
  periodSeconds: 5
```

So a pod with a STALE/invalid connection string still passes probes and reports Ready — the 401 is invisible to k8s health (A2).

**What is NOT present (A1 negatives):**
- **No Stakater Reloader annotation** — `reloader.stakater.com/*` does not appear in the chart template, in default `values.yaml` (`podAnnotations: {}`), nor in `sandbox/values.yaml` (no `podAnnotations` block at all). Project-wide `ado-repo-search` for `stakater` and `reloader.stakater.com` = **NO RESULTS** across the entire `Myriad - VPP` project.
- **No checksum/config-hash pod-template annotation.** The only `metadata.annotations` on the Deployment is a legacy `pod.beta.kubernetes.io/init-containers` string; the pod template annotations are `{{- with .Values.podAnnotations }}` and no env supplies a config hash.
- **No `argocd.argoproj.io/sync-wave`** anywhere in the frontend chart template or the ApplicationSet.
- Default chart `values.yaml` (A1): `startupProbe: {}`, `readinessProbe: {}`, `livenessProbe: {}`, `podAnnotations: {}`, `volumes: []`, `volumeMounts: []` — every reload/probe/volume surface is values-driven, and the FBE values file supplies none of a reload trigger.

**Q1 verdict (A2):** appconfig.js is frozen-once in an emptyDir; nothing (reloader / checksum / sync-wave / connection-string probe / CSI rotation) forces a pod restart or a rewrite when the underlying KV secret changes. A running pod serves a stale connection string until it is manually rebuilt.

---

## Q2 — Where/when the App Config connection string is written to the per-slot KV, and ordering vs ArgoCD

**The write (A1).** `VPP - Infrastructure` repo, `/terraform/fbe/app-config.tf`:

```hcl
module "appconfig" {
  source = "git::.../Eneco.Infrastructure//terraform/modules/appconfig?ref=v0.1.0"
  app_configuration_name = format("%s-appconfig-fbe-%s-%s", var.project-prefix, var.environment, random_string.random.result)
  app_configuration_sku_and_networking = var.app_configuration_sku_and_networking
  ...
}

module "primary_connectionstring_appconfig" {
  source = "git::.../Eneco.Infrastructure//terraform/modules/keyvaultsecret?ref=v0.1.0"
  key_vault_secret_name  = "connectionstrings-app-config"
  key_vault_secret_value = module.appconfig.app_configuration_primary_write_key_connection_string
  key_vault_id           = module.key_vault.key_vault_id
  depends_on = [module.key_vault]
}
```

Load-bearing: the KV secret `connectionstrings-app-config` value is the App Configuration store's **primary WRITE key** connection string. The SPA authenticates to the App Config data plane over HMAC with this write key (A2).

**CSI mapping (A1).** `Myriad - VPP` repo, `/azure-pipeline/Helm/secretprovider/templates/secretprovider.yaml` — SecretProviderClass `{{ .Values.name }}` (mounted as `secret-provider-kv`), `secretObjects` block:

```yaml
      - key: connectionstrings_appconfig
        objectName: connectionstrings-app-config
      ...
      secretName: application-secret
      type: Opaque
```

Chain (A2): KV `connectionstrings-app-config` → CSI SecretProviderClass `secret-provider-kv` → K8s Secret `application-secret` key `connectionstrings_appconfig` → init-container env → appconfig.js. `secretObjects` is mount-coupled (the K8s Secret only exists/refreshes while a pod mounts the SPC).

**Pipeline ordering (A1).** `Myriad - VPP` repo, `/azure-pipelines-featurebr-env.yml` (create pipeline, `trigger: none`). Stage graph:

1. `CheckBranch` (branch must be `feature/fbe-*`).
2. `PrepareRepositories` — lease-table register + create feature branches in dispatch/gitops/config repos.
3. `DeployInfra` — `TerraformCLI@1 apply` (`retryCountOnTaskFailure: 3`) in `VPP - Infrastructure/terraform/fbe` → **creates App Config store + writes the KV secret** (app-config.tf above). Emits `keyvaultname`, `appconfig` outputs.
4. `keyvaultandappconfigentries` (`dependsOn: DeployInfra`) — `azure-appconfiguration/sandbox.template.yml` with `isFeatureBranchEnvironmentFirstLoad: true` → **loads feature-flag key-values INTO the App Config store**.
5. `DeployServices` (`dependsOn: keyvaultandappconfigentries`) — `TriggerBuild@4` for each service incl. `frontend` (`pipelineid: "1562"`), `waitForQueuedBuildsToFinish: true` → builds/pushes frontend image.
6. `DeployFBEInArgoCD` (`dependsOn: PrepareRepositories, DeployInfra, DeployServices`) — **commits the per-slot file that triggers ArgoCD** (see Q-topology below), then a fixed `Start-Sleep`/countdown of **180 seconds**.
7. `Infra_tests` (Pester `FBE.FunctionalTests.ps1`), then `Slacknotify`.

**Ordering verdict (A2):** On a clean first create the ordering is CORRECT — the KV secret (step 3) and App Config flag values (step 4) are written BEFORE the ArgoCD slot file is committed (step 6, transitively depends on both). So a first-create frontend pod should bake a valid write-key connection string. The only intra-create guard after the ArgoCD trigger is a blind `180s` sleep (no readiness gate on the flag endpoint) (A1).

**ArgoCD topology (A1).** `VPP.GitOps` repo, `/argocd-configuration/applicationsets/vpp-feature-branch-environments.yaml`:

```yaml
kind: ApplicationSet
metadata: { name: vpp-feature-branch-environments }
spec:
  generators:
    - git:
        repoURL: .../VPP.GitOps
        files:
          - path: feature-branch-environments/*.yaml
  template:
    metadata:
      name: "{{.environment}}-app-of-apps"
    spec:
      project: vpp-core
      sources:
        - repoURL: .../VPP-Configuration
          targetRevision: "{{.branch}}"
          path: Helm/vpp-core-app-of-apps
          helm:
            valuesObject:
              global:
                featureBranchEnvironment:
                  enabled: true
                  branch: "{{.branch}}"
                  name: "{{.environment}}"
                  keyVaultName: "{{.keyVaultName}}"
        - repoURL: .../Eneco.Vpp.Core.Dispatching.GitOps
          targetRevision: "{{.branch}}"
          path: app-of-apps
          ...
      syncPolicy:
        automated: { prune: true, selfHeal: true }
        syncOptions: [ PruneLast=true ]
```

Per-slot generator file (A1), `VPP.GitOps` `/feature-branch-environments/jupiter.yaml`:

```yaml
branch: feature/fbe-856615-Overwrite-PTUs-for-ELIA-Activation-and-RTS
environment: jupiter
keyVaultName: vpp-fbe-jupiter-vlt
```

The commit that creates this file (A1, `DeployFBEInArgoCD` stage): `cat template | yq '.branch=...' | yq '.environment=...' | yq '.keyVaultName=...' > $(featurebranchName).yaml; git commit; git push origin HEAD:main`. There is **no ArgoCD sync-wave ordering** between the CSI/secret and the frontend inside the app-of-apps — `syncPolicy.automated{prune,selfHeal}` only.

---

## Q3 — Does the App Config access key rotate/regenerate on apply / re-create?

**appconfig module (A1).** `Eneco.Infrastructure` `/terraform/modules/appconfig/main.tf`:

```hcl
resource "azurerm_app_configuration" "app_configuration" {
  name                  = var.app_configuration_name
  resource_group_name   = var.resource_group_name
  location              = var.location
  public_network_access = var.app_configuration_sku_and_networking.public_network_access
  sku                   = var.app_configuration_sku_and_networking.sku
  tags                  = var.tags
}
```

No explicit key-regeneration resource (no `azurerm_*_access_key` regen, no `null_resource` rotating keys). Azure App Configuration primary/secondary keys are creation-time computed attributes; a plain `terraform apply` does NOT rotate them (A2).

**random_string keeper (A1).** `VPP - Infrastructure` `/terraform/fbe/common.tf`:

```hcl
resource "random_string" "random" {
  length  = 3
  special = false
  upper   = false
  numeric = false
  keepers = {
    id = format("%s-random-fbe-%s", var.project-prefix, var.environment)
  }
}
```

The store name suffix is `random_string.random.result`. The keeper is `{prefix}-fbe-{environment}` — stable for a given slot. So **within an existing state**, re-apply keeps the same suffix → same store → same primary key → connection string unchanged (A2).

**Delete → recreate DOES change the key (A2, strong).** Delete pipeline `Myriad - VPP` `/azure-pipeline-fbe-del.yml` has stage `DestroyAppConfiguration` with `isTerraformDestroy: "true"` (A1). A full delete destroys the fbe Terraform state; a subsequent create (pipeline 2412) starts from empty state, so `random_string.random` is generated fresh → **new store name → new App Config store → new primary write key → new `connectionstrings-app-config` KV value**. Any previously-running frontend pod that had baked the OLD connection string would then 401 until rebuilt. This is the recurrence mechanism the frozen-once init container cannot self-heal (A2).

**Q3 verdict:** keys are stable across ordinary re-apply of a live slot; they DO change on a delete-then-recreate of the same slot name (fresh random suffix ⇒ new store ⇒ new key).

---

## Q4 — CSI secret rotation

- `ado-repo-search` for `enableSecretRotation` across `Myriad - VPP` = **NO RESULTS** (A1).
- The SecretProviderClass (`secretprovider.yaml`, Q2) sets `usePodIdentity: "false"`, `useVMManagedIdentity: "true"`; it defines `secretObjects` (mount-coupled K8s Secret sync) but no rotation poll interval (A1).
- **Q4 verdict (A2):** CSI secret auto-rotation is NOT configured, and the frontend does not rely on it. Even if rotation were enabled, it would refresh the mounted `application-secret`, but would NOT re-run the init container that writes appconfig.js — so rotation alone cannot fix the frozen file.

---

## Q5 — Does a Stakater Reloader deployment exist?

- `ado-repo-search` for `stakater` and `reloader.stakater.com` across the whole `Myriad - VPP` project (which contains `VPP.GitOps`, `platform-gitops`, `VPP-Configuration` — all FBE/cluster GitOps) = **NO RESULTS** (A1).
- **Q5 verdict (A2):** there is no Reloader controller in this project. A `reloader.stakater.com/*` annotation added today would be inert — the controller must be deployed first. (A3 scope caveat: search was project-scoped to `Myriad - VPP`; CCoE/platform projects were not searched, but the Sandbox `vpp-aks01-d` platform stack is sourced from this project.)

---

## Q6 — Idiomatic fix surface

Assessment of each candidate against the confirmed layout:

- **(a) Reloader annotation on the frontend Deployment.** File(s): add `podAnnotations` in `VPP-Configuration/Helm/frontend/sandbox/values.yaml` (and dev/acc/prod) — but ALSO requires deploying the Stakater Reloader controller (absent today, Q5). **BLOCKED as a one-liner** — annotation alone does nothing. Even with Reloader, Reloader watches Secret/ConfigMap CHANGES; the CSI-synced `application-secret` change would trigger a rollout that re-runs the init container = correct behavior, but this is a new controller dependency + blast radius across all frontend envs. Risk: MEDIUM-HIGH (new cluster controller; affects dev/acc/prod values too).

- **(b) ArgoCD sync-wave ordering frontend after the App Config credential.** File: the app-of-apps templates under `VPP-Configuration/Helm/vpp-core-app-of-apps` (child `frontend` Application) — add `argocd.argoproj.io/sync-wave`. **Does NOT fix the real failure:** ordering only helps first-create; it cannot restart an already-running pod when the KV value changes later (delete→recreate / key change). Risk: LOW but INEFFECTIVE for recurrence. (A3: exact app-of-apps template file not fetched this session; inferred from ApplicationSet source `path: Helm/vpp-core-app-of-apps`.)

- **(c) Make appconfig.js dynamic — serve the CSI-mounted value at request time instead of init-once emptyDir.** File(s): `Myriad - VPP/azure-pipeline/Helm/frontend/templates/deployment.yaml` (drop the init-container echo; mount the secret directly) + nginx config so `/appconfig/appconfig.js` is generated per-request from the mounted secret, + `VPP-Configuration/Helm/frontend/*/values.yaml` (volumeMounts). **This is the root-cause fix** (removes the frozen-once coupling entirely) but is the largest change and touches the nginx image/config and all frontend envs. Risk: MEDIUM (changes the app's config-delivery mechanism; must verify nginx serves the file with correct MIME/caching).

- **(d) Pipeline ordering gate so KV string is final before ArgoCD deploys frontend.** File: `Myriad - VPP/azure-pipelines-featurebr-env.yml`. Ordering is ALREADY correct on first create (Q2); the blind `180s` sleep is the only weak point. **Does not address the delete→recreate key-change recurrence.** Risk: LOW but INEFFECTIVE for the main failure mode.

- **(e) Init/readiness probe that fails until the flag endpoint returns 200.** File(s): `Myriad - VPP/azure-pipeline/Helm/frontend/templates/deployment.yaml` + `VPP-Configuration/Helm/frontend/sandbox/values.yaml` (replace `/healthz` readiness with a probe that validates App Config reachability, or an init-container that curls the App Config data plane with the baked key before writing appconfig.js). **Partial fix:** makes a bad pod NOT go Ready (surfaces the failure, blocks bad rollouts) but does not by itself rewrite a stale file on a running pod. Best combined with (a) or (c). Risk: LOW-MEDIUM.

**Recommendation for the RCA (A2):** the durable/root fix is **(c)** (dynamic appconfig.js — removes frozen-once), optionally hardened by **(e)** (probe that validates the flag endpoint). **(a)** is the smaller "operational reload" fix but needs the Reloader controller stood up first (currently absent). **(b)/(d)** are ordering band-aids that do not cover the delete→recreate key-rotation recurrence.

---

## Exact file inventory (for citation)

| # | Repo (project `Myriad - VPP`) | Path | Used for |
|---|---|---|---|
| 1 | `Myriad - VPP` | `/azure-pipeline/Helm/frontend/templates/deployment.yaml` | Q1 init container, no reloader/checksum/sync-wave |
| 2 | `Myriad - VPP` | `/azure-pipeline/Helm/frontend/values.yaml` | Q1 empty defaults |
| 3 | `Myriad - VPP` | `/azure-pipeline/Helm/frontend/Chart.yaml` | Q1 chart version 0.4.2 |
| 4 | `VPP-Configuration` | `/Helm/frontend/sandbox/values.yaml` | Q1 emptyDir `mydir`, probes=/healthz, no podAnnotations |
| 5 | `Myriad - VPP` | `/azure-pipeline/Helm/secretprovider/templates/secretprovider.yaml` | Q2 CSI map `connectionstrings-app-config`→`application-secret`, no rotation |
| 6 | `VPP - Infrastructure` | `/terraform/fbe/app-config.tf` | Q2/Q3 KV write = primary WRITE key conn string |
| 7 | `VPP - Infrastructure` | `/terraform/fbe/common.tf` | Q3 random_string keeper |
| 8 | `Eneco.Infrastructure` | `/terraform/modules/appconfig/main.tf` | Q3 no key-regen resource |
| 9 | `VPP.GitOps` | `/argocd-configuration/applicationsets/vpp-feature-branch-environments.yaml` | Q2 topology, no sync-wave |
| 10 | `VPP.GitOps` | `/feature-branch-environments/jupiter.yaml` | Q2 per-slot generator params |
| 11 | `Myriad - VPP` | `/azure-pipelines-featurebr-env.yml` | Q2 stage ordering |
| 12 | `Myriad - VPP` | `/azure-pipeline-fbe-del.yml` | Q3 `isTerraformDestroy: "true"` |

**A3 caveats:** (i) Helm/pipeline files fetched from each repo's DEFAULT branch; the create pipeline checks out `myriadvpp` at `refs/heads/development` and ArgoCD sources `VPP-Configuration` at the feature branch, so minor per-branch drift is possible — the init-once mechanism is structural and unlikely to differ. (ii) The child `frontend` Application definition inside `VPP-Configuration/Helm/vpp-core-app-of-apps` was not fetched (inferred from ApplicationSet source path); it is the exact edit target for option (b). (iii) `sandbox.template.yml` (App Config value loader) internals not fetched — only its invocation.
