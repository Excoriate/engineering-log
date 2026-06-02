---
task_id: 2026-06-02-001
agent: repo-chart-lane
status: complete
summary: keys secret is inline-Helm in common chart, gated by a namespace/env conditional with NO Sandbox branch and NO else; common chart is never deployed by any pipeline; SecretProviderClass exists but does NOT manage keys.
timestamp: 2026-06-02T00:00:00Z
---

# Lane R1 — Repo / Helm-Chart Authority Receipt

Repo: `Eneco.Vpp.Aggregation` | Project: `Myriad - VPP` | Branch: `development`
Evidence source: Azure DevOps read-only REST (ado-repo-tree / ado-repo-file / ado-repo-search). Every quoted block is the verbatim file content returned by the REST API.

## TL;DR (for the RCA coordinator)

- The `keys` Secret is provisioned **inline by Helm** in chart `common`, template `secret.yaml`, as a hardcoded `kind: Secret` whose `data:` is wrapped in a 3-branch conditional (`vpp-agg` namespace / `DevMC` env / `Acceptance` env) **with NO `else` fallback and NO Sandbox branch**. `A1`
- There **IS** a `SecretProviderClass` chart (`secretprovider`), but it creates secrets named `ingress-tls`, `dockerpullsecret`, and `application-secret` — it **does NOT create or manage `keys`**. `A1`
- No `ExternalSecret` (External Secrets Operator) and no cert-manager `Certificate`/`Issuer` exist anywhere in the chart tree. `A1`
- The `common` chart (the one holding `keys`) is **never referenced by any deploy pipeline** — `Helm/common` returns NO results in code search, and `deploy.yaml`/`deploy-stage.yaml` only `HelmDeploy` per-service `fn` charts + the `secretprovider` chart. There is no HelmDeploy step for `common`. `A1`
- Deploy templates only branch on `environment == 'vpp-agg'` and `environment == 'afi'`. There is no `Sandbox` deploy branch and `overrideValues` never sets `container.env`. `A1`

This directly answers Johnson's question ("Ideally those secrets need to be installed via a secret provider, right?"): the cert `keys` secret is the ONE secret in this chart that is NOT wired through the existing secret provider — it is committed as base64 blobs inside a Helm template and only renders for hardcoded environments. Sandbox is not one of them.

---

## Q1 — Full content + real paths of the two linked files

Johnson linked `common/templates/secret.yaml` and `fn/templates/deployment.yaml`. Real directory prefix found via repo tree:

- Chart root: `azure-pipeline/Helm/` `A1` (ado-repo-tree, line index 1748)
- `keys` secret: **`/azure-pipeline/Helm/common/templates/secret.yaml`** `A1`
- The generic `fn` he linked maps to the per-function deployment template. There is no literal `fn/` dir; there are 10 `*fn` charts that all consume `keys`. Representative: **`/azure-pipeline/Helm/dataingestionfn/templates/deployment.yaml`** `A1`

### `/azure-pipeline/Helm/common/templates/secret.yaml` (verbatim structure; base64 blobs elided)

`A1` (ado-repo-file)

```yaml
######################################
#
#cat ssl-key.pfx | base64 -d > file.pfx
#openssl pkcs12 -in file.pfx -nocerts -out ssl-key.pem
######################################
apiVersion: v1
kind: Secret
metadata:
  name: keys
  namespace: {{ .Release.Namespace }}
type: Opaque
data:
{{- if eq .Release.Namespace "vpp-agg" }}
  ca-cert.pem: >-
    <base64 cert>
  client-cert.pem: >-
    <base64 cert>
  ssl-key.pem: >-
    <base64 key>
  ssl-key.pfx: >-
    <base64 pfx>
{{- else if eq .Values.container.env "DevMC" }}
  ca-cert.pem: >-
    <base64 cert>
  client-cert.pem: >-
    <base64 cert>
  ssl-key.pem: >-
    <base64 key>
  ssl-key.pfx: >-
    <base64 pfx>
{{- else if eq .Values.container.env "Acceptance" }}
  ca-cert.pem: >-
    <base64 cert>
  client-cert.pem: >-
    <base64 cert>
  ssl-key.pem: >-
    <base64 key>
  ssl-key.pfx: >-
    <base64 pfx>
{{- end }}
```

(File is 66 lines; the elided regions are inline base64-encoded certificate/key material committed directly into the chart.)

### `/azure-pipeline/Helm/dataingestionfn/templates/deployment.yaml` (relevant volume/mount excerpt, verbatim)

`A1` (ado-repo-file)

```yaml
          volumeMounts:
            - mountPath: /app/certs
              name: keys
              readOnly: true
      ...
      volumes:
        - name: keys
          secret:
            defaultMode: 420
            secretName: keys
```

The env vars (Kafka SSL paths) come from `dataingestionfn/values.yaml.env_variables`, NOT from the secret directly. The container connects them by file path under `/app/certs`. `A1`

---

## Q2 — HOW the `keys` Secret is defined

- It is a Helm `kind: Secret` (`type: Opaque`), name `keys`, namespace `{{ .Release.Namespace }}`. `A1`
- The `data:` values are **inline** in the template (committed base64 blobs), NOT sourced from `.Values.*` and NOT from any external provider. `A1`
- The entire `data:` body is wrapped in a conditional:
  - `{{- if eq .Release.Namespace "vpp-agg" }}` → certs for the prod-style `vpp-agg` namespace
  - `{{- else if eq .Values.container.env "DevMC" }}` → DevMC certs
  - `{{- else if eq .Values.container.env "Acceptance" }}` → Acceptance certs
  - `{{- end }}` — **there is NO `{{- else }}`** `A1`
- **Implication (A2):** If neither `.Release.Namespace == "vpp-agg"` nor `.Values.container.env in {DevMC, Acceptance}`, the rendered Secret has an **empty `data:` block** — i.e. a `keys` Secret with no cert keys, or (because the whole chart is never deployed, see Q-deploy below) no `keys` Secret created at all.
- `container.env` is set NOWHERE in the repo. `ado-repo-search "container.env"` → **1 result, the secret.yaml itself**. `ado-repo-search "DevMC"` → **1 result, the secret.yaml itself**. `A1` So the `DevMC`/`Acceptance` branches can only ever fire if `container.env` is injected at deploy time via `--set`/overrideValues — and the deploy templates do NOT inject it (Q-deploy).

---

## Q3 — SecretProviderClass / ExternalSecret / cert-manager presence

- **SecretProviderClass: EXISTS** but does not manage `keys`. `A1`
  - Template: `/azure-pipeline/Helm/secretprovider/templates/secretprovider.yaml`
  - `kind: SecretProviderClass`, `apiVersion: secrets-store.csi.x-k8s.io/v1`, `provider: azure` (Azure Key Vault CSI).
  - Its `secretObjects` create exactly three k8s Secrets: `ingress-tls` (TLS), `dockerpullsecret` (dockerconfigjson), and `application-secret` (Opaque: app insights, storage, DB conn strings, eventhub, cosmos, `kafkasslkeystorepassword`, influxdb token, AAD postdeliveryreport creds). `A1`
  - **`keys` is NOT in the `secretObjects` list, and none of `ca-cert.pem`/`client-cert.pem`/`ssl-key.pem`/`ssl-key.pfx` are produced by it.** `A1`
  - Note: it DOES pull `kafkasslkeystorepassword` (the keystore *password*) into `application-secret`, but NOT the keystore/cert *files* themselves. `A2`
- **ExternalSecret (External Secrets Operator): ABSENT.** No `ExternalSecret` kind anywhere — tree has no such template; the only secret-provisioning kinds in the chart are the inline `Secret` (common) and the `SecretProviderClass` (secretprovider). `A1` (full tree listing, Helm section lines 1748-1866)
- **cert-manager Certificate/Issuer: ABSENT.** No `Certificate`/`Issuer`/`ClusterIssuer` templates in the tree. `A1` (same tree listing — only template kinds present: Secret, SecretProviderClass, Deployment, Service, Ingress, Route, CronJob, PrometheusRule/alert_rule).

Full chart template inventory (proof of absence), from the tree:

```text
azure-pipeline/Helm/
  common/templates/                 secret.yaml, _helpers.tpl
  dataingestionfn/templates/        deployment.yaml
  deliveryreportfn/templates/       deployment.yaml, ingress.yaml, route.yaml, service.yaml
  flexreservationingestionfn/       deployment.yaml
  marketinputpreparationfn/         deployment.yaml
  meritordercalculationfn/          deployment.yaml
  ocp-prometheus-alerting/          alerts/alert_rule.yaml
  opstools/                         opstools.deployment.yaml
  postdeliveryreportjob/            cronJob.yaml
  secretprovider/templates/         secretprovider.yaml   <-- only SecretProviderClass
  setpointdisaggregationfn/         deployment.yaml
  siteregistry/templates/           deployment.yaml, ingress.yaml, route.yaml, service.yaml
  strikepricefn/                    deployment.yaml
  telemetryaggregationfn/           deployment.yaml
  telemetryfunctiontestsfn/         deployment.yaml, ingress.yaml, route.yaml, service.yaml
  telemetryingestionfn/             deployment.yaml
```

`A1` — No ExternalSecret, no cert-manager, anywhere.

---

## Q4 — Values files and per-environment differences

- `common/values.yaml`: **EMPTY** (zero content). `A1` So `container.env` has NO default — it is undefined unless set externally. Combined with Q2/Q-deploy, the `DevMC`/`Acceptance` branches are effectively dead unless a pipeline injects `container.env`, which none do.
- `secretprovider/values.yaml`: `A1`
  ```yaml
  KeyVaultName: "vpp-agg-sb"
  secretProvider:
    name: "secret-provider-agg-kv"
  container:
    namespace: vpp-agg
  ```
  Note `vpp-agg-sb` — the `-sb` suffix = the Sandbox Key Vault. So the secret-provider IS pointed at a Sandbox KV, but again only provisions `application-secret`/`ingress-tls`/`dockerpullsecret`, not `keys`. `A2`
- Per-function `values.yaml` (e.g. `dataingestionfn/values.yaml`) carry image/registry/probes/`env_variables`. The Kafka cert paths live here:
  ```yaml
  env_variables:
    KafkaOptions__SslCaLocation:          /app/certs/ca-cert.pem
    KafkaOptions__SslCertificateLocation: /app/certs/client-cert.pem
    KafkaOptions__SslKeyLocation:         /app/certs/ssl-key.pem
    KafkaOptions__SslKeystoreLocation:    /app/certs/ssl-key.pfx
    ASPNETCORE_ENVIRONMENT: Sandbox
  ```
  `A1` — These paths are exactly the four keys the `keys` Secret is supposed to contain.
- **Environment overlay values:** The ONLY overlay file in the chart is `values-afi.yaml` (referenced by `deploy.yaml` for `environment == 'afi'` via `-f ${chartpath}/values-afi.yaml`). `A1` There is **NO `values-sandbox.yaml`, NO `values-dev.yaml`, NO `values-mc*.yaml`, and NO `environments/` directory** anywhere in the chart. `A1` (tree listing — each chart has only `values.yaml`; afi overlays referenced but the `-f` path is per-service; no sandbox overlay exists for `common`).
- **Does Sandbox have an overlay at all?** No. There is no Sandbox-specific values file and no Sandbox branch in the deploy templates. `A1`

### How `keys`/certs are supplied per environment (the divergence)

- `vpp-agg` namespace → secret.yaml branch 1 fires → `keys` rendered with committed certs (IF the `common` chart were deployed).
- `DevMC` / `Acceptance` (via `container.env`) → branches 2/3 → but `container.env` is never set by any pipeline, so dead in practice. `A2`
- **Sandbox → no branch, no `container.env`, no overlay, and the `common` chart is not deployed at all.** `A2`

---

## Q5 — What `keys` contains and how it is consumed

Contents of the `keys` Secret (the four data keys, from secret.yaml): `A1`

| Key in Secret | Purpose | Consumer env var (fn values) |
|---|---|---|
| `ca-cert.pem` | Kafka SSL CA cert | `KafkaOptions__SslCaLocation=/app/certs/ca-cert.pem` |
| `client-cert.pem` | Kafka SSL client cert | `KafkaOptions__SslCertificateLocation=/app/certs/client-cert.pem` |
| `ssl-key.pem` | Kafka SSL client key (PEM) | `KafkaOptions__SslKeyLocation=/app/certs/ssl-key.pem` |
| `ssl-key.pfx` | Kafka SSL keystore (PKCS#12) | `KafkaOptions__SslKeystoreLocation=/app/certs/ssl-key.pfx` |

`A2`: The leading comment in secret.yaml (`openssl pkcs12 ... ssl-key.pfx`) and the broker hosts in fn values (`broker1.dtaaz.esp.eneco.com:9094` etc.) confirm these are **Kafka/ESP mTLS client certificates** for connecting to the Eneco Event Streaming Platform.

Consumption (every `*fn` deployment): mounts the `keys` Secret as a read-only volume at `/app/certs`: `A1`
```yaml
      containers:
        - ...
          volumeMounts:
            - mountPath: /app/certs
              name: keys
              readOnly: true
      volumes:
        - name: keys
          secret:
            defaultMode: 420
            secretName: keys
```
`ado-repo-search "secretName: keys"` → 10 fn deployments consume it (dataingestionfn, deliveryreportfn, flexreservationingestionfn, marketinputpreparationfn, meritordercalculationfn, setpointdisaggregationfn, strikepricefn, telemetryaggregationfn, telemetryfunctiontestsfn, telemetryingestionfn). `A1` Missing `keys` Secret → every one of these pods fails `MountVolume.SetUp` exactly as reported.

---

## How the chart is actually deployed (deploy-pipeline evidence)

- `ado-repo-search "Helm/common"` → **NO RESULTS.** `A1` The `common` chart is not referenced as a chartPath/release by any pipeline.
- `/azure-pipeline/templates/deploy.yaml` per-service HelmDeploy only fires for `environment == 'vpp-agg'` or `environment == 'afi'`; `chartPath = ${chartpath}` (the per-service `*fn` chart); `overrideValues` sets only `image.*` and `ingress.hostname`. **No `container.env`, no `common` chart, no Sandbox branch.** `A1`
- `/azure-pipeline/templates/deploy-stage.yaml` deploys the `secretprovider` chart only for `environment == 'vpp-agg'` or `'afi'`, and iterates `services` (the fn charts). **No step deploys `azure-pipeline/Helm/common/`.** `A1`

`A2`: The `keys` Secret has no committed deploy path. It is created only by a manual/out-of-band `helm install` of the `common` chart into the `vpp-agg` namespace (whoever set up prod/DevMC/Acceptance ran it). In Sandbox nobody ran it — which is exactly why Johnson had to `kubectl create secret keys` by hand.

---

## Verdict on provisioning mechanism

**The `keys` cert Secret is provisioned INLINE-BY-HELM (committed base64 in `common/templates/secret.yaml`), NOT by an external provider — and NOT by anything that runs in Sandbox.** `A2`

Three independent reasons it was missing in Sandbox, all evidence-backed:

1. **No Sandbox branch.** The secret's `data:` only renders for `.Release.Namespace == "vpp-agg"` OR `.Values.container.env in {DevMC, Acceptance}`. There is no `else` and no Sandbox case → for any other context the Secret renders empty. `A1`
2. **`container.env` is never set.** It exists only inside secret.yaml and is set by no values file and no pipeline override → the DevMC/Acceptance branches are dead in CD. `A1`
3. **The `common` chart is never deployed.** No pipeline references `Helm/common`; deploy templates only branch on `vpp-agg`/`afi` and never HelmDeploy `common` → the `keys` Secret is not created by CD in ANY environment, including Sandbox. `A1`

**Why the existing SecretProviderClass did not save it:** the `secretprovider` chart pulls many secrets from Key Vault `vpp-agg-sb` into `application-secret`/`ingress-tls`/`dockerpullsecret`, but the Kafka client cert files (`ca-cert.pem`, `client-cert.pem`, `ssl-key.pem`, `ssl-key.pfx`) are **not** among its `objects`/`secretObjects`. So even where the secret provider runs, `keys` is out of scope. `A1`

**Implication for the fix (chart-authority view, for the RCA to route):** Johnson's instinct is correct — the right structural fix is to move these four Kafka cert objects into Key Vault and add them to the `secretprovider` chart's `objects`/`secretObjects` (producing a `keys`-equivalent Secret via CSI), instead of relying on an inline Helm template that (a) has hardcoded/expired certs committed in git, (b) has no Sandbox branch, and (c) is not even wired into the deploy pipeline. His manual `kubectl create secret keys` + cert swap from VPP Core is the correct stop-gap but will drift again on the next redeploy. `A2`

---

## Lane boundaries / residual risk (A3)

- `A3 UNVERIFIED[blocked: out of lane]` — I did NOT probe the live Sandbox cluster (kubeconfig forbidden) nor Azure Key Vault contents. Whether `vpp-agg-sb` KV actually holds Kafka certs is for the runtime/Azure lane.
- `A3 UNVERIFIED[blocked: not probed]` — The base64 certs committed in secret.yaml: I did not decode/validate expiry. Johnson reported they were expired; the leading comment block and committed-blob pattern are consistent with stale hardcoded certs, but expiry itself is an Azure/runtime-lane confirmation.
- `A3 UNVERIFIED[blocked: not probed]` — There may be a separate orchestration repo (e.g. an Argo/Flux app-of-apps or a `Eneco.Infrastructure` deploy) that installs `common` outside this repo's `azure-pipeline/`. Within THIS repo, `common` is undeployed; cross-repo deploy wiring is a separate lane.
- The `afi` overlay (`values-afi.yaml`) is referenced by deploy.yaml but I did not fetch its body — not relevant to Sandbox `keys`.

## Note on workspace guard

A `task-workspace-guard.sh` PostToolUse hook fired repeatedly during this lane, naming `log/employer/.../2026_03_26_alert_sql_acc/alert_payload_rootly.json` — a file written by a different concurrent agent, NOT by this lane. Per the no-mutation-of-other-agents constraint, I did NOT overwrite `.ai/runtime/current-task.json` (it points at a sibling task `2026-06-02-004`). This receipt is written under my own task workspace (`.ai/tasks/2026-06-02-001_.../context/`), which is outside the log tree the guard protects.
