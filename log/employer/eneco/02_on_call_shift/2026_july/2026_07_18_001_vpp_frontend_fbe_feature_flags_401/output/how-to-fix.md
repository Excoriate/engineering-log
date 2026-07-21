# How to fix — VPP frontend FBE feature-flags 401 after creation

Companion to [rca.md](./rca.md). Every path below is a real file in a local checkout under
`Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/` (all pulled to latest 2026-07-19).
Identifiers are live-verified; secrets are never printed.

## The bug in one sentence

The frontend bakes the App Config **HMAC connection string once** into a static `appconfig.js`
(init container → emptyDir), and **nothing re-bakes it** when a slot's App Config store is recreated
with new keys — so the browser keeps signing requests with a dead credential → **401** until the pod
is manually restarted.

## Recommended plan (what to put in the PR)

| Priority | Change | Repo / file | Kills the manual pod delete? |
|----------|--------|-------------|------------------------------|
| P0 (now) | Restart the 5 currently-drifted slots' frontends | live cluster (no code) | interim only |
| **P1 (primary)** | Add a **frontend rollout-restart after ArgoCD converges** to the FBE create pipeline | `Myriad - VPP/azure-pipelines-featurebr-env.yml` | **Yes** — for pipeline-driven create/recreate |
| **P2 (robustness)** | **Stakater Reloader** + Deployment annotation on `application-secret` | `VPP.GitOps` + `Myriad - VPP/.../Helm/frontend` + `VPP-Configuration/.../sandbox/values.yaml` | **Yes** — trigger-agnostic |
| P3 (hardening) | Hand the browser a **read-only** App Config key, not the primary write key | `VPP - Infrastructure/terraform/fbe/app-config.tf` + appconfig module | security, not the 401 |
| P4 (strategic) | Make `appconfig.js` **dynamic** (serve the CSI-mounted value, drop the snapshot) | `Myriad - VPP/.../Helm/frontend` + frontend image | eliminates the class |

P1 alone closes Duncan's exact ask if the store only ever changes via the pipeline. P2 makes it robust
to any out-of-band recreate. Ship **P1 + P2** together; add P3; schedule P4.

---

## P0 — Immediate mitigation (no code, restores 200 now)

The RCA found **5 of 6 active FBE frontend slots currently drifted** (boltz, ishtar, kidu, thor, veku;
jupiter is the healthy 6th). Their baked store is deleted, so today they fail the flag call with a
connection error / missing indicator; each just needs its frontend re-baked:

```bash
kubectl config use-context vpp-aks01-d
for ns in boltz ishtar kidu thor veku; do
  kubectl -n "$ns" rollout restart deploy/frontend
done
for ns in boltz ishtar kidu thor veku; do
  kubectl -n "$ns" rollout status deploy/frontend --timeout=120s
done
```

Verify the **effect** (not the exit code) per slot:

```bash
ns=boltz
kubectl -n "$ns" exec deploy/frontend -c frontend -- cat /etc/nginx/html/appconfig/appconfig.js \
  | grep -oE 'Endpoint=https://[^;"]+'
kubectl -n "$ns" get secret application-secret -o jsonpath='{.data.connectionstrings_appconfig}' \
  | base64 -d | grep -oE 'Endpoint=https://[^;"]+'
# the two Endpoint hosts MUST now match; then browser DevTools: .appconfig.featureflag/* == 200
```

> **Safety (H-SAFETY-1):** `rollout restart` is retry-safe and reversible. Do **NOT** rotate App Config
> keys, re-run/destroy the App Config Terraform, rename the store, or touch dev-mc `vpp-applicationconfig-d`
> — the store and keys are correct; only the **pod** is stale. This mitigation is authorization-gated:
> it changes live FBE state, so run it only with the owner's OK (it is exactly the manual step we are
> removing, used here once as triage).

---

## P1 — Primary permanent fix: rollout-restart in the create pipeline

**File:** `Myriad - VPP/development/azure-pipelines-featurebr-env.yml`, stage `DeployFBEInArgoCD`
(job `CreateFeatureBranchEnvironmentStack`). Today it commits the ArgoCD app file, then a **blind 180 s
countdown** step `waitDeploy` (lines ~638-651) that neither verifies nor restarts anything.

**Change:** replace the blind sleep with (a) a real readiness wait and (b) a targeted frontend restart, so
a reused slot's surviving pod re-bakes `appconfig.js` from the final store. The namespace is
`$(featurebranchName)`.

Replacement for the `waitDeploy` step (kubectl variant — needs the job to have AKS credentials, see prereq):

```yaml
          - task: AzureCLI@2
            name: waitDeploy
            displayName: Wait for ArgoCD sync, then re-bake frontend appconfig.js
            inputs:
              azureSubscription: <sandbox-service-connection>   # must have AKS user access to vpp-aks01-d
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                set -euo pipefail
                az aks get-credentials -g rg-vpp-app-sb-401 -n vpp-aks01-d --overwrite-existing
                NS="$(featurebranchName)"
                # 1) wait for ArgoCD to create the namespace + frontend Deployment
                for i in $(seq 1 60); do
                  kubectl -n "$NS" get deploy/frontend >/dev/null 2>&1 && break || sleep 5
                done
                # 2) wait until it is rolled out, then restart so the init re-reads the FINAL secret
                kubectl -n "$NS" rollout status deploy/frontend --timeout=180s
                kubectl -n "$NS" rollout restart deploy/frontend
                kubectl -n "$NS" rollout status deploy/frontend --timeout=180s
                # 3) effect check: baked endpoint must equal the live secret endpoint
                BAKED=$(kubectl -n "$NS" exec deploy/frontend -c frontend -- \
                        cat /etc/nginx/html/appconfig/appconfig.js | grep -oE 'Endpoint=https://[^;"]+')
                CUR=$(kubectl -n "$NS" get secret application-secret \
                        -o jsonpath='{.data.connectionstrings_appconfig}' | base64 -d | grep -oE 'Endpoint=https://[^;"]+')
                echo "baked=$BAKED current=$CUR"
                [ "$BAKED" = "$CUR" ] || { echo "appconfig.js != application-secret — still stale"; exit 1; }
                # 3b) CRITICAL: application-secret itself can LAG the live store (see RCA L7), so also
                #     assert the baked store actually EXISTS in Azure — otherwise baked==current can be
                #     a false green where BOTH point at a since-deleted store.
                STORE=$(echo "$BAKED" | sed -E 's|Endpoint=https://||; s|\.azconfig\.io$||')
                az resource show -g rg-vpp-app-sb-401 -n "$STORE" \
                   --resource-type Microsoft.AppConfiguration/configurationStores >/dev/null 2>&1 \
                   || { echo "baked store $STORE does not exist in Azure — stale"; exit 1; }
```

**Prerequisite / credentials (corrected by review):** the pipeline's sibling `Infra_tests` stage already
runs `AzurePowerShell@5` under `$(azureSubscription)`, so an Azure service connection with cluster
access **is already available to this pipeline** — the earlier worry that the job "has no cluster
credentials" was overstated. Reuse that same `azureSubscription` for the `AzureCLI@2` step above
(it needs **AKS Cluster User** on `vpp-aks01-d`; grant it if the existing connection lacks it). Alternative
if you prefer not to touch the cluster directly: use the ArgoCD API the pipeline already knows
(`argocdUri = https://argocd.dev.vpp.eneco.com`):
`argocd app actions run <slot>_frontend restart --kind Deployment --resource-name frontend` (needs an
ArgoCD auth token in the job) — but then keep the effect check as a separate authenticated `az`/`kubectl` step.

Either way, keep the **effect check** (baked endpoint == live secret endpoint) as the pass condition —
`rollout status` success alone is not proof (H-EFFECT-1). This is idempotent: on a first-create the extra
restart is harmless; on a recreate it fixes the stale pod.

---

## P2 — Robustness: Stakater Reloader (trigger-agnostic auto-restart)

Because CSI keeps `application-secret` current (rotation `--enable-secret-rotation=true`,
`--rotation-poll-interval=2s`, verified live), a controller that rolls the frontend when that secret
changes fixes the 401 for **any** cause — pipeline or out-of-band. Reloader is **not installed** today, so
this is two parts.

**Part A — install Reloader (once, Sandbox cluster).** Add an ArgoCD Application in `VPP.GitOps`
(alongside the other platform apps under `argocd-configuration/applications/`) pointing at the upstream
`stakater/reloader` Helm chart, scoped to a `reloader` namespace. (Additive; no blast radius on FBEs.)

**Part B — annotate the frontend Deployment.** Reloader reads the annotation on **`Deployment.metadata.annotations`**,
not the pod template — and the chart currently hardcodes that block. Two edits:

1. `Myriad - VPP/.../azure-pipeline/Helm/frontend/templates/deployment.yaml` — make the Deployment
   annotations extensible (the block after `pod.beta.kubernetes.io/init-containers`):

   ```yaml
   metadata:
     name: {{ include "frontend.fullname" . }}
     labels:
       {{- include "frontend.labels" . | nindent 4 }}
     annotations:
       pod.beta.kubernetes.io/init-containers: '[ ... unchanged ... ]'
       {{- with .Values.deploymentAnnotations }}
       {{- toYaml . | nindent 4 }}
       {{- end }}
   ```

2. `VPP-Configuration/Helm/frontend/sandbox/values.yaml` — set it (FBE/sandbox only, prod untouched):

   ```yaml
   deploymentAnnotations:
     secret.reloader.stakater.com/reload: "application-secret"
   ```

> **Why this is provably viable (A1):** on the 5 drifted slots, `application-secret` already holds the
> **new** store while the pod holds the **old** one — i.e., CSI updates the K8s secret without a pod roll.
> A Reloader watching that secret would have rolled the frontend automatically. Caveat: `application-secret`
> has 13 keys used by other workloads; annotating the frontend to reload on it means the frontend also
> rolls when unrelated keys change — acceptable (a frontend restart is cheap and stateless).

---

## P3 — Security hardening: read-only key to the browser (orthogonal)

Today the browser receives the **primary write** key (`app_configuration_primary_write_key_connection_string`).
The SPA only reads flags, so hand it a read-only key to shrink blast radius.

1. Appconfig module `Eneco.Infrastructure/terraform/modules/appconfig/output.tf` — add:

   ```hcl
   output "app_configuration_primary_read_key_connection_string" {
     value     = azurerm_app_configuration.app_configuration.primary_read_key[0].connection_string
     sensitive = true
   }
   ```

   **Tag hygiene (review finding):** cut the new tag (e.g. `v0.2.0`) as a **minimal commit off the
   `v0.1.0` tag** — NOT off the module's `main` HEAD. `main` HEAD has drifted from `v0.1.0` (it dropped
   `ignore_changes = [tags]`, added `tags`/`data_owners`, and added provider pinning
   `azurerm ~> 4.0` / `required_version >= 1.12`); tagging from HEAD would bundle those unrelated changes
   into the FBE apply.

2. `VPP - Infrastructure/terraform/fbe/app-config.tf` — bump the module `ref` and switch the KV value:

   ```hcl
   key_vault_secret_value = module.appconfig.app_configuration_primary_read_key_connection_string
   ```

> **Safety (reviewed):** this is a KV-secret **value update** (App Config exposes read + write keys
> simultaneously) — **not** a store rename and **not** ForceNew (confirmed against azurerm 4.x docs; the
> only ForceNew field here is the store `name`, which is unchanged). After apply, CSI refreshes
> `application-secret` and the frontend must be re-baked (P1/P2 will do it). No one-way door.
> **Two caveats:** (a) `local_auth_enabled` is unset on the store (defaults `true`); do NOT later disable
> local auth as a "hardening" — it kills **read AND write** HMAC keys and would defeat this entire
> browser-HMAC design. (b) Provider behaviour above is doc-verified, not plan-verified this session —
> **run one `terraform plan` on a throwaway slot** and confirm the store shows **no replacement** before
> shipping P3.

---

## P4 — Strategic root fix: make `appconfig.js` dynamic

Remove the frozen-snapshot class entirely: instead of the init container writing `appconfig.js` **once**
into an emptyDir from an env var, generate/serve it from the **CSI-mounted** secret (already present at
`/mnt/secrets-store/connectionstrings-app-config`, kept fresh at 2 s) **at container start or request time**.

Approach (needs a frontend-image change + testing in a throwaway slot):
- Drop the `mydir` emptyDir + init container; mount the CSI file into nginx's web root, or have the
  container entrypoint regenerate `appconfig.js` from `/mnt/secrets-store/...` on start; and
- add a **readiness probe that validates the flag endpoint** (a `Ready` pod should be able to fetch flags),
  so a stale credential can never report healthy.

Higher effort; schedule after P1/P2 stop the bleeding.

---

## Verification (all fixes — close on EFFECT, never a return code)

1. **Baked == live:** `appconfig.js` `Endpoint=` host equals the `application-secret` endpoint and an
   existing Azure store (`az resource list -g rg-vpp-app-sb-401 --resource-type Microsoft.AppConfiguration/configurationStores --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e`).
2. **Browser 200:** DevTools on `https://<slot>.dev.vpp.eneco.com/` → `.appconfig.featureflag/*` returns
   **200**; the **Dutch flag + "Tennet NL"** indicator renders.
3. **Regression:** create a throwaway slot end-to-end; confirm flags load **without** any manual pod delete.
4. **Recurrence:** trigger a store recreate (recreate the slot) and confirm the frontend self-recovers
   (P1 pipeline step or P2 Reloader rolls it) — verify by effect, not by "pipeline green".

## One-way doors / do-NOT list

- Do **not** rename the App Config store or its per-slot Key Vault. Renaming the store is **ForceNew
  destroy+recreate** (new HMAC keys — the exact drift this RCA is about). Precise blast radius: an App
  Config **store** has soft-delete ~1–7 days with purge protection **off** by default, so a store rename is
  recoverable-ish but still rotates keys; the harsher one-way door is the **Key Vault** (soft-delete
  default ~90 days + possible purge protection) — do not rename `vpp-fbe-<slot>-vlt`.
- Do **not** rotate App Config keys or re-run/`terraform destroy` the App Config module to "fix" a stale pod
  — that recreates the exact drift you are fixing.
- Do **not** point FBE flags at dev-mc `vpp-applicationconfig-d` — wrong store.
- The FBE **delete** pipeline `2629` runs `terraform destroy` — it is not a rollback; it is the very step
  that regenerates the store next create.

## PR checklist

- [ ] P1 pipeline step edited + a Sandbox AKS credential (or ArgoCD token) available to the job
- [ ] P2 Reloader Application added to `VPP.GitOps`; chart `deploymentAnnotations` plumbed; sandbox values set
- [ ] P3 module read-key output + `ref` bump + `app-config.tf` value switch
- [ ] Effect check (baked endpoint == live secret endpoint) is the pipeline pass gate
- [ ] Validated on one throwaway slot: create → flags load with **no** manual pod delete
- [ ] P0 mitigation applied to the 5 currently-drifted slots (with owner OK)
