---
task_id: 2026-06-02-001
agent: coordinator
status: complete
summary: Read-only live Sandbox evidence (AKS vpp-aks01-d, KV vpp-agg-sb, vpp-agg ns) confirming the keys-secret RCA. No mutations; no secret values captured.
timestamp: 2026-06-02T09:30:00Z
---

# Live Sandbox Evidence (read-only) — 2026-06-02

Auth: `az login` (user, interactive MFA refresh). All `az` calls used explicit `--subscription 7b1ba02e-…`; kubectl used an isolated kubeconfig `/tmp/sb-kubeconfig-2026-06-02-001` (shared `~/.kube/config` untouched). No `az account set`. No whitelist (Sandbox uses none). No destructive ops. NO secret/key values were printed or stored — only names, metadata, and PUBLIC certificate fields.

## Cluster (A1)

- AKS `vpp-aks01-d`, RG `rg-vpp-app-sb-401`, westeurope, K8s 1.31.11, Running. Hosts namespace `vpp-agg`.

## K8s `keys` secret — provenance (A1, decisive)

```
name: keys   type: Opaque   created: 2026-06-01T08:56:40Z
dataKeys: [ca-cert.pem, client-cert.pem, ssl-key.pem, ssl-key.pfx]
annotations: null   labels: null   ownerReferences: null   managedFields: []
```

- No `helm.sh/release-*` annotations, no ArgoCD tracking label, no `secrets-store.csi.k8s.io` labels, **and crucially no `ownerReferences`** → **created manually/out-of-band** (matches Johnson's "I added it manually" and R1's chart analysis). **Correction (per adversarial review):** `ownerReferences` (absent) is the valid discriminator — NOT `managedFields`. On this cluster (K8s 1.31.11) the CSI-projected `application-secret` also shows empty `managedFields`, so empty `managedFields` alone proves nothing. `keys` is the lone non-controller-owned secret in the namespace.

## K8s `keys` cert identity (A1; PUBLIC cert fields only — private key never read)

- `client-cert.pem`: `subject=CN=esp-eet-vpp-dt.streaming.eneco.com`, issuer `Trust Provider B.V. TLS RSA CA G1`, valid `2025-12-09 → 2027-01-09`. → the AGG's OWN dev-test ESP identity (`eet-vpp-dt`), currently VALID. NOT a VPP Core identity.
- `ca-cert.pem`: `CN=Trust Provider B.V. TLS RSA CA G1`, valid to `2027-11-02`.

## Other namespace secrets (A1)

- `application-secret`, `dockerpullsecret`, `ingress-tls` — created `2025-01-20` (CSI-projected, see SPC below).
- Many `sh.helm.release.v1.<fn>.vNNN` (per-function Helm release history; e.g. `dataingestionfn` up to v223 @ 2026-06-01T14:36). **No `sh.helm.release.v1.common.*`** → the `common` chart (which defines `keys`) is never Helm-installed.

## CSI SecretProviderClass (A1)

```
name: secret-provider-agg-kv   keyvaultName: vpp-agg-sb
secretObjects (projected K8s secrets): ingress-tls, dockerpullsecret, application-secret
```

- `keys` is NOT among the projected secretObjects → the Kafka cert files are out of CSI scope, even though CSI works (the 3 projected secrets exist since 2025-01-20).

## Key Vault `vpp-agg-sb` — Kafka material (A1; names/dates/public-cert fields only)

- Secrets present: `kafka-cacert`, `kafka-clientcert`, `kafka-sslkey`, `kafkasslkeystorepassword`, `kafka-sshkeypass` (+ app-config/connstring/influx/grafana secrets).
- `kafka-cacert` / `kafka-clientcert` / `kafka-sslkey` / `kafkasslkeystorepassword` all **created/updated `2026-05-29`** (recent refresh).
- `kafka-clientcert` decodes to `CN=esp-eet-vpp-dt.streaming.eneco.com`, valid `2025-12-09 → 2027-01-09` (same as the live K8s cert).
- KV **certificate object** `vpp-eneco-com` **expired `2026-01-20`** (ingress/app-gw TLS cert — a separate, also-expired cert; not the `keys` story but worth flagging).

## Runtime status (A1)

- All `*fn` pods `1/1 Running`, AGE ~19h (dataingestionfn, deliveryreportfn, flexreservationingestionfn, marketinputpreparationfn, meritordercalculationfn, setpointdisaggregationfn, strikepricefn, telemetryaggregationfn, telemetryfunctiontestsfn, telemetryingestionfn) + siteregistry Running; postdeliveryreportjob Completed. → incident resolved at runtime by the manual fix (~19h before probe).

## ArgoCD (A1)

- Only `influxdb-vpp-agg-monitoring` (dest ns `vpp-agg-monitoring`, Synced/Healthy). No ArgoCD Application targets the `vpp-agg` namespace or deploys `common`/`keys` → no GitOps reconciliation/self-heal for `keys`.

## Net: every prior A2 runtime inference is now A1-confirmed

The `keys` secret was missing because nothing in CD creates it (no Sandbox branch in the inline-Helm template + `common` chart never deployed + CSI SPC excludes it); Johnson restored it by hand on 2026-06-01; the correct `eet-vpp-dt` certs already exist in KV `vpp-agg-sb` but are not wired to `keys`.
