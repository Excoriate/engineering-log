---
title: "Fix — VPP Aggregation Layer Sandbox `keys` secret"
description: Stop-gap (done), Sandbox-consistency and provider-managed durable fixes, an MC-safety gate, and the credential-expiry class action — adversarially reviewed.
task_id: 2026-06-02-001
agent: coordinator
status: complete
summary: Stop-gap applied; durable options = enroll Sandbox in the GitOps `common` path (parity) or provider-manage keys via ESO (preferred, mount-independent) / CSI (requires *fn to mount the SPC volume). Do NOT delete the shared `common` template — MC renders keys from it. Class fix = KV certificate object + named rotation trigger.
timestamp: 2026-06-02T12:55:00Z
authors: [on-call]
---

# Fix — `vpp-agg` Sandbox `keys` secret

Three layers: **stop-gap** (already done), **durable fix** (two routes), **class fix**. Each step states *what changes*, *what does not*, *why*, *how to verify*. This page was adversarially reviewed (sre-maniac, sherlock); two safety gates below come directly from that review — **read them before acting**.

## Answering Nuno's question first

> *"Ideally those secrets needs to be installed via secret provide right? … what is the expectation here … sandbox is very different from MC."*

**Yes — `keys` should be installed automatically, not by hand.** Today it is *not* provider-managed in either environment: MC renders it from inline-committed certs in the `common` Helm chart (via GitOps); Sandbox doesn't create it at all. The documented ideal is **External Secrets Operator (ESO)** (Key Vault → K8s Secret); **ESO is already installed and syncing in Sandbox** — it just has no `ExternalSecret` for `keys`. So a provider is both the intended pattern and locally available. *This answer is Sandbox-scoped; MC uses the inline path and needs the same migration — see the MC-safety gate.*

## Two safety gates (from adversarial review — non-negotiable)

- **GATE 1 — Do NOT delete `common/templates/secret.yaml`.** MC dev/acc render `keys` from that exact template via the `Eneco.Vpp.Aggregation.GitOps` app-of-apps + OCI `common` chart (verified: `common/dev/values.yaml` sets `container.env=DevMC`; `common/dev/Chart.yaml` depends on `oci://vppacra.azurecr.io/helm-agg`). Deleting it regresses MC. Retire it only **after** MC is migrated to a provider.
- **GATE 2 — If you use CSI, the consuming pods must mount the SPC.** CSI `secretObjects` are projected only while a pod mounts the SecretProviderClass *as a CSI volume*. The 10 `*fn` pods mount `secret: keys` *directly* (0 mount the SPC); the existing CSI secrets survive only because `siteregistry` happens to anchor the SPC. A CSI route for `keys` therefore **must** switch the `*fn` deployments to mount the SPC volume, or the projection is an orphan that re-breaks on a `siteregistry` outage. **ESO does not have this coupling** (preferred — see Route B).

## Decision ladder — which fix applies

```text
Is Sandbox broken RIGHT NOW (keys missing, pods FailedMount)?
 ├─ YES → STOP-GAP (recreate keys by hand from KV certs). Dev/test only. ~5 min.
 └─ NO (already mitigated, as today) → go durable.

Want fastest parity with MC, accept committed-in-git certs for now?
 ├─ YES → ROUTE A: enroll Sandbox in the GitOps `common` path MC uses.
 └─ NO / want to kill the credential-expiry class → ROUTE B: provider-manage keys (ESO preferred).

In ALL cases: obey GATE 1 (don't delete the shared template) and, if CSI, GATE 2.
```

## Layer 0 — Stop-gap (DONE 2026-06-01 by Johnson; documented for repeatability)

**What changed:** a `keys` Secret created by hand in `vpp-agg` with `ca-cert.pem`, `client-cert.pem`, `ssl-key.pem`, `ssl-key.pfx`. **What did not:** chart, pipeline, provider — so it has no owner and will be lost on namespace recreate or redeploy. **Why it works:** pods only need the four files at `/app/certs`. `A1` (pods Running ~19h).

Redo recipe (dev/test only), using the AGG's **own** identity certs already in KV `vpp-agg-sb` (do **not** borrow another component's cert):

```bash
SB=7b1ba02e-bac6-4c45-83a0-7f0d3104922e
export KUBECONFIG=/tmp/sb.kubeconfig    # az aks get-credentials ... vpp-aks01-d (isolated file)
work=$(mktemp -d)                        # mode 0700; holds private key briefly
az keyvault secret show --vault-name vpp-agg-sb --name kafka-cacert     --subscription "$SB" -o tsv --query value > "$work/ca-cert.pem"
az keyvault secret show --vault-name vpp-agg-sb --name kafka-clientcert --subscription "$SB" -o tsv --query value > "$work/client-cert.pem"
az keyvault secret show --vault-name vpp-agg-sb --name kafka-sslkey     --subscription "$SB" -o tsv --query value > "$work/ssl-key.pem"
pfxpass=$(az keyvault secret show --vault-name vpp-agg-sb --name kafkasslkeystorepassword --subscription "$SB" -o tsv --query value)
openssl pkcs12 -export -inkey "$work/ssl-key.pem" -in "$work/client-cert.pem" -certfile "$work/ca-cert.pem" -out "$work/ssl-key.pfx" -passout pass:"$pfxpass"
kubectl -n vpp-agg create secret generic keys \
  --from-file=ca-cert.pem="$work/ca-cert.pem" --from-file=client-cert.pem="$work/client-cert.pem" \
  --from-file=ssl-key.pem="$work/ssl-key.pem" --from-file=ssl-key.pfx="$work/ssl-key.pfx" \
  --dry-run=client -o yaml | kubectl apply -f -
shred -u "$work"/* 2>/dev/null; rm -rf "$work"   # never leave private keys on disk
```

> **Safety:** private-key material lives only in a `mktemp -d` (0700) and is shredded immediately. Never paste keys into Slack/tickets ([LL-017]). `-o tsv` (not `-o json`) keeps the PEM well-formed. `--dry-run=client | apply` = idempotent.

**Verify stop-gap:** `kubectl -n vpp-agg get secret keys -o jsonpath='{.data}' | jq 'keys'` → 4 keys; `kubectl -n vpp-agg get pods` → all `*fn` `1/1 Running`.

## Layer 1 — Durable fix

### Route A — Sandbox consistency (fastest; does NOT fix the class)

**What changes:** add a Sandbox values set to `Eneco.Vpp.Aggregation.GitOps` (mirroring `common/dev`) so the Sandbox cluster's `vpp-agg` namespace deploys the OCI `common` chart; the existing `if .Release.Namespace == "vpp-agg"` branch then renders `keys`. (Equivalently: add a `common` HelmDeploy step to the legacy Sandbox pipeline.) **What does not:** the `*fn` deployments, the certs. **Why:** brings Sandbox to parity with MC — `keys` is created by CD, not a human. **Limitation:** it still relies on **certs committed in git** (the inline template), so it does **not** remove the rotation/security class — it just makes Sandbox consistently broken-or-fixed with MC. Choose Route A only as a short-term parity step.

**Verify:** after sync, `kubectl -n vpp-agg get secret keys` shows a `helm.sh/release-name` annotation for the `common` release (controller-owned, not hand-made); pods `1/1 Running` without a manual secret.

### Route B — provider-managed `keys` (recommended class fix)

Materialise `keys` from KV `vpp-agg-sb` (which already holds the correct `eet-vpp-dt` certs) via a provider:

- **Preferred: ESO `ExternalSecret`.** ESO is already installed and syncing in Sandbox. It maintains the K8s Secret independently of any pod mount → **no CSI mount-coupling (GATE 2 avoided)**. Define an `ExternalSecret` (in the `vpp-agg` SecretStore pointed at `vpp-agg-sb`) that builds `keys` with:
  - `ca-cert.pem`  ← KV secret `kafka-cacert`
  - `client-cert.pem` ← KV secret `kafka-clientcert`
  - `ssl-key.pem`  ← KV secret `kafka-sslkey`
  - `ssl-key.pfx`  ← **see pfx caveat**
  ESO re-syncs on its poll interval, so a deleted/expired secret self-heals.
- **Alternative: CSI SecretProviderClass.** Add the cert objects to `secret-provider-agg-kv` `objects` and a `keys` entry to `secretObjects`. **GATE 2 applies:** you must also switch the 10 `*fn` deployments to mount the SPC as a CSI volume at `/app/certs` (`csi: { driver: secrets-store.csi.k8s.io, volumeAttributes: { secretProviderClass: secret-provider-agg-kv } }`), so each consumer anchors its own projection. Without that, the projected `keys` is orphaned the moment `siteregistry` scales to 0.

> **pfx caveat (must be designed, not assumed):** KV holds `kafka-sslkey` (PEM) + `kafkasslkeystorepassword`, but **no `.pfx`**. The chart's `KafkaOptions__SslKeystoreLocation` wants `ssl-key.pfx` (PKCS#12); providers project bytes verbatim and cannot assemble a pfx. Options, by operator preference:
> - **(b) switch the app to a PEM keystore** (drop `SslKeystoreLocation`, set `ssl.keystore.type=PEM`) — cleanest, but **gate on**: (i) confirm the app's *pinned* `Confluent.Kafka`/librdkafka version supports PEM keystore (do not assume "recent versions do"), and (ii) ship with a **runtime mTLS smoke test** against ESP (a Ready pod that can't reach Kafka is a worse, silent failure). Requires an app/config change.
> - **(a) store an assembled `.pfx` in KV** (e.g. `kafka-sslkeystore`) and project it — lowest code, but creates a second private-key copy that must be re-assembled on every rotation → re-introduces a manual maintenance step (the LL-006 class). Acceptable only if the pfx is added to the same rotation runbook entry as the PEM and alarmed.
> - **(c) init-container `openssl pkcs12`** — works; adds a per-pod moving part and bakes the keystore password into the init spec.
> Recommend **(b) if and only if** the client version is verified; else **(a)** with paired rotation.

### Verify Route B — gated sequence (do NOT delete the manual secret first)

```text
1. Apply the provider (ESO ExternalSecret, or CSI SPC + *fn mounting the SPC volume) and sync.
2. GATE (pass/fail = controller ownership, NOT "pods recover"):
     kubectl -n vpp-agg get secret keys -o json | jq '{owner:.metadata.ownerReferences, labels:.metadata.labels}'
   -> must show an ESO owner (kind: ExternalSecret) OR label secrets-store.csi.k8s.io/managed=true.
   If absent -> projection not materialised -> STOP. Do NOT delete the manual secret. Investigate.
3. Only after step 2 passes: delete the manual `keys`; `kubectl -n vpp-agg rollout restart deploy`;
   confirm all *fn reach 1/1 Running consuming the provider copy (a Running pod won't re-read a volume
   Secret without a restart — that's why the restart is explicit, NOT "do nothing else").
4. mTLS smoke test: confirm a *fn actually connects to ESP (logs/health), not just pod-Ready.
5. Rollback ready: if step 2 fails, recreate the manual `keys` from KV (Layer 0).
```

## Layer 2 — Class fix (credential-expiry class, [LL-006])

This is the same shape as 5+ prior credential-expiry incidents: calendar-expiring credential, human owner, no automation, no alarm on the credential's real storage form.

1. **Alarm the real item — prefer a KV certificate object.** Live state: `kafka-cacert/clientcert/sslkey/keystorepassword` are KV **secrets** with **`expires: null`** → the existing expiry pipeline (`def 2735`, which watches KV **certificate objects**) does not cover them. **Primary control:** store the client cert as a KV **certificate object** (intrinsic, non-optional expiry the existing alarm already watches). **Fallback only:** set `--expires` on the KV secrets + extend the pipeline to read secret expiry — but note this depends on a human setting the attribute every rotation (same class defect), so use it only for material that genuinely cannot be a cert object (CA chain, raw PEM key).
2. **Name the owner AND the trigger.** Docs say ownership is "tech lead/lead developer" — make it a named person + backup in the AGG runbook, and define the **rotation trigger** (alert at expiry-minus-N-days), not just an owner. Current client cert is valid to `2027-01-09` (~7 months runway — not urgent, but the root of the "broken >6 months" history).
3. **No-cert-without-rotation rule:** any PR introducing a credential declares owner + rotation path + alarm in the same PR ([LL-006] standing rule).
4. **Adjacent finding to file separately:** KV certificate object `vpp-eneco-com` **expired 2026-01-20** — verify whether Sandbox ingress/app-gateway TLS is affected (out of scope for `keys`, found en route). `A1`

## What this fix explicitly does NOT do

- It does not delete `common/templates/secret.yaml` (GATE 1 — MC depends on it).
- It does not rotate the ESP cert end-to-end (owner-gated, partly undocumented — RCA L10).
- It does not touch MC; apply the same provider pattern there only after Sandbox is proven, and probe each MC KV for the `kafka-*` material + the MC CSI/ESO identity's KV access first.
- It does not decode or move private-key material anywhere except an ephemeral, shredded temp dir.
