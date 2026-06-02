---
task_id: 2026-06-02-001
agent: coordinator
status: partial
summary: Converged root cause from repo+docs lanes (R1 chart, R2 infra, D1 docs + follow-up wiki). Live Sandbox leg pending user re-auth.
timestamp: 2026-06-02T09:10:00Z
---

# Converged Synthesis — vpp-agg Sandbox `keys` secret missing

Source lanes: `lane-r1-chart.md` (Helm chart authority — DECISIVE), `lane-r2-infra.md` (IaC),
`lane-d1-docs.md` (wiki/ADR), `wiki-followups.txt` (cert-renewal / secret-expiry / ArgoCD-Sandbox).

## Incident (A1, from slack-intake.md)

- Namespace `vpp-agg`, **Sandbox** K8s cluster. Pods: `MountVolume.SetUp failed for volume 'keys': secret 'keys' not found` (x32/50m).
- Reporter Johnson Lobo; certs were expired; he swapped in VPP Core certs and created `keys` manually. "Broken >6 months."
- The `keys` secret = Kafka/ESP **mTLS** cert bundle: `ca-cert.pem`, `client-cert.pem`, `ssl-key.pem`, `ssl-key.pfx` → mounted at `/app/certs` by 10 `*fn` deployments.

## Root cause (depth-laddered)

- **L1 proximate (A1):** `keys` Secret absent in `vpp-agg`/Sandbox → 10 `*fn` pods fail to mount → workloads down.
- **L2 enabling (A1):** `keys` is provisioned **inline-by-Helm** in `azure-pipeline/Helm/common/templates/secret.yaml` with base64 certs committed in git, conditional `if ns==vpp-agg / elif container.env==DevMC / elif ==Acceptance / end` — **no `else`, no Sandbox branch**; `container.env` set by nothing; and the **`common` chart is never deployed by any pipeline** (deploy templates only HelmDeploy per-service `fn` charts + the `secretprovider` chart, only for `environment ∈ {vpp-agg, afi}`). ⇒ `keys` is created by CD in NO environment; only by manual `helm install`/`kubectl`. Sandbox never got it.
- **L3 design (A1+A2):** The one cert Secret is the ONLY secret in the chart NOT wired through the chart's existing Azure KeyVault **CSI `SecretProviderClass`** (`secretprovider` chart → KV `vpp-agg-sb`, which projects `application-secret`/`ingress-tls`/`dockerpullsecret` and pulls `kafkasslkeystorepassword` but NOT the cert files). Static committed certs + no rotation owner (docs: "maintained by tech lead/lead developer", no automation) + secret-expiry pipeline (def 2735) checks KV *certificate objects* not in-git/secret material ⇒ silent multi-month expiry. This is the credential-expiry CLASS problem ([LL-006]).

## Answers to the 4 asked questions

1. **Why missing?** Three independent reasons above (no Sandbox branch; `container.env` unset; `common` chart never deployed). A1.
2. **Manual vs secret provider?** Secret provider is correct (Johnson right). Durable fix: store the 4 Kafka cert objects in KV `vpp-agg-sb` and add them to the `secretprovider` chart's `objects`/`secretObjects` so CSI projects a `keys`-equivalent Secret. Removes committed/expired certs from git, the missing Sandbox branch, and the undeployed-`common` problem in one move. A2.
3. **Borrow VPP Core certs?** Acceptable stop-gap; NOT durable. It authenticates VPP-AGG to ESP/Kafka under VPP Core's identity (`eet-vpp` ESP app owns the proper cert). Identity smell + undocumented + drifts on next redeploy. A2.
4. **Class linkage?** Yes — [LL-006] credential-expiry class: calendar-expiring cert, human (tech-lead) ownership, no automated rotation, no alarm covering THIS secret/KV item. A1/A2.

## Live confirmation leg (PENDING user re-auth — A3 UNVERIFIED[blocked: MFA expired])

Read-only probes to run after `az login` (Sandbox sub `7b1ba02e-...`, explicit `--subscription`/`--context`):
1. `kubectl --context <sb> -n vpp-agg get secret keys -o jsonpath` → confirm it exists now (Johnson's fix) + its 4 keys.
2. `az keyvault secret list / certificate list --vault-name vpp-agg-sb --subscription 7b1ba02e-...` → confirm `kafka-cacert`/`kafka-clientcert`/`kafka-sslkey` presence + expiry (sibling kafka-certs ticket names these).
3. Decode the committed certs' `notAfter` and the live ones' expiry → confirm "expired ~6 months."
4. `argocd app list` / `kubectl -n vpp-agg get application` → is there a vpp-agg ArgoCD app? does anything deploy `common`? (expect: no `common` app).
5. Confirm the `secretprovider` SecretProviderClass is deployed and `application-secret` exists (proves CSI works in Sandbox; `keys` is simply out of its scope).

None of these change the root cause; they convert L5/L9 claims from A2→A1.
