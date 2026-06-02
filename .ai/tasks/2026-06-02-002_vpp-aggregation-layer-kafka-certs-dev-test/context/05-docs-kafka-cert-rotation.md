---
task_id: 2026-06-02-002
agent: eneco-context-docs-research
status: complete
summary: Canonical agg-layer ESP/Kafka cert rotation runbook FOUND (ArgoCD esp-certificate-agg path) plus ESP cert setup + renewal-contact docs; rotation is manual, cert issued as a PFX handed over by Networking4All (Trust Provider B.V. / DigiCert reseller) via email request — no automated/ACME renewal for the mTLS client cert.
timestamp: 2026-06-02
---

# Docs research — Aggregation Layer Kafka (mTLS) client certificate expiry / rotation

Source surface: Eneco ADO wiki `Myriad---VPP.wiki` (project "Myriad - VPP"), fetched live 2026-06-02 via `eneco-context-docs` skill scripts. Each finding labelled A1 (cited doc URL/path + quote), A2 (inferred), A3 (not found).

## TL;DR

- A canonical aggregation-layer cert rotation runbook **exists** (A1) and matches this incident's domain: ArgoCD application `esp-certificate-agg`, a `keys` Kubernetes secret, a `common` app, and a PFX password in keyvault.
- The mTLS client certificate is **issued as a password-protected PFX handed over by the ESP / external provider** — renewal is **manual** via an email request to **Networking4All (Jenke van Gerven)**, the reseller fronting the **Trust Provider B.V. (DigiCert) PKI**. **No ACME / self-service automated renewal** of the client cert is documented (A1 + A2).
- There **is** an expiry-detection pipeline (definitionId 2735) that posts to a Slack channel (A1) — but it is a notification, not an auto-rotation, and did not prevent the incident (A2).
- The cert filenames in the docs (`23121345441-esp-eet-vpp-dt-...`, `...440-...-acc-...`, `...442-...-prd-...`) line up exactly with this incident's `esp-eet-vpp-dt` / `esp-eet-vpp-acc` certs and the broker host family `*.streaming.eneco.com` (A1).

---

## (a) Canonical procedure / runbook

### A1 — PRIMARY: Aggregation Layer cert rotation runbook

- Path: `/Myriad - Aggregation Layer/Runbook certificate rotation aggregation layer`
- URL: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki/wikis/Myriad---VPP.wiki?pagePath=/Myriad%20-%20Aggregation%20Layer/Runbook%20certificate%20rotation%20aggregation%20layer (Page ID 50903)
- Verbatim opening: *"This runbook defines the steps to execute to rotate the ESP production certificate."*

Concrete steps (quoted):

**Validation with 1 service first**
1. Override 'keys' secret in argocd application 'esp-certificate-agg' to another name 'esp-cert-new-test'
2. Override secret mount in argocd for 1 service (or 2)
3. Override PFX password in ArgoCD for the same service(s)
4. Confirm service(s) can consume / produce with the new cert.

**Rollout plan**
1. Upload new client certificate on Axual production application
2. Configure the production certificate in the gitops repository
3. Configure the ArgoCD Application `esp-certificate-agg` on the production cluster, manual sync, leave out of sync
4. Disable auto-sync on the apps-of-apps
5. Disable auto-sync on the 'common' application
6. Remove kubernetes secret 'keys' from the 'common application'
7. Sync application `esp-certificate-agg` to recreate the 'keys' secret with the new certificate in it
8. Update PFX password in production keyvault
9. Restart service(s)

**Rollback plan**
1. Delete 'keys' secret from application `esp-certificate-agg`
2. Sync argocd application 'common' to recreate the secret
3. Update password in Keyvault back to previous password
4. Restart service(s)

A2 — This runbook is written for the **production** rollout via the AKS/ArgoCD gitops path (Axual upload → gitops repo → `esp-certificate-agg` ArgoCD app → `keys` secret → PFX password in keyvault → restart). The mechanism (secret name `keys`, ArgoCD app `esp-certificate-agg`, PFX password in keyvault) is the agg-layer-specific deployment surface — distinct from the Azure-Function path documented elsewhere. For dev/acc the same gitops/ArgoCD pattern applies per cluster; the runbook does not enumerate dev/acc explicitly (A3 for dev/acc-specific steps — gap, see section (e)).

### A1 — SUPPORTING: ESP certificate setup (the cert anatomy + naming)

- Path: `/Way of Working/DevOps & Platform/Tutorials-HowTos/Certificates and Secrets/ESP certificate setup` (Page ID 6791)
- URL: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_wiki?pageId=6791&friendlyName=ESP-certificate-setup
- Cert filename table (quoted):

| ENV | CERT | Applications |
|-----|------|--------------|
| DT | `23121345441-esp-eet-vpp-dt-streaming-eneco-com.pfx` | EET_VPP, EET_VPP_TELEMETRY |
| ACC | `23121345440-esp-eet-vpp-acc-streaming-eneco-com.pfx` | EET_VPP, EET_VPP_TELEMETRY |
| PROD | `23121345442-esp-eet-vpp-prd-streaming-eneco-com.pfx` | EET_VPP, EET_VPP_TELEMETRY |

- *"Source file we receive from ESP: We receive a password protected PFX file with three components: CA Certificate (root), Client certificate, Private key (private SSL key)."*
- *"The certificate must be setup both on the Axual platform for the application (upload the certificate in the Axual portal) as for the client library to consume/produce."*
- The page documents openssl recipes to split the PFX into `caCertificate.pem` / `clientCertificate.pem` / `sslkey.key` (+ base64) for use as K8s/Keyvault secrets — i.e. how `kafka-cacert` / `kafka-clientcert` / `kafka-sslkey` are produced from the PFX. `SSLKEYSTOREPASSWORD` is the PFX/keystore password (maps to incident secret `kafkasslkeystorepassword`).
- A2: The cert filename prefix `2312134544x` and the `esp-eet-vpp-{dt|acc|prd}-streaming-eneco-com` subject directly correspond to the incident certs `esp-eet-vpp-dt` and `esp-eet-vpp-acc` and broker host `esp-eet-vpp-*.streaming.eneco.com`. This is the same cert family. **Caveat (A2):** the `2312134544x` numbers in the doc are an older issuance generation; the incident's expired-2026-01-10 and replacement-2027 certs are later generations of the same named cert, so exact serials will differ.

### A1 — SUPPORTING: Certificate Renewal (the renewal contact)

- Path: `/Way of Working/DevOps & Platform/Tutorials-HowTos/Certificates and Secrets/Certificate Renewal` (Page ID 12196)
- *"Renewal is via an email request to Jenke van Gerven j.vangerven@networking4all.com — www.networking4all.com. Generally an email will be sent to fm_VPP_support mailbox by Jenke to inform us of an upcoming certificate expiry."*
- *"Certificates reside in keyvault."* + *"We have alerting in place to check for expiry, we need to update the old certificate to point to the new ones."*
- A3 (partial): The "trigger upload to app-gateway" and "Alerting" sub-sections are image-only (screenshots not machine-readable). The renewal-contact text is the load-bearing, machine-readable fact. This page mixes app-gateway TLS cert renewal with ESP cert renewal; the **renewal channel (Networking4All email)** is the cross-cutting fact relevant here.

### A1 — SUPPORTING: ESP cert pipeline automation (partial)

- Path: `/Way of Working/DevOps & Platform/Tutorials-HowTos/Certificates and Secrets/ESP certificate setup/Automation using Azure Pipelines` (Page ID 30987)
- Steps (quoted): "Step 1: Get the certificate from the provider → Step 2: upload PFX to storage account `vppstoragedevops`, fileshare `certs` → Step 3: update cert password on pipeline `Cert-Upload` → Step 4: run pipeline → Step 5: values created per env in keyvault `vpp-aks-devops`."
- A2: This automates the PFX-to-keyvault-secrets fan-out (the openssl split) for the function/AKS keyvault `vpp-aks-devops`, but **Step 1 ("get the certificate from the provider") is manual** and this pipeline targets `vpp-aks-devops`, not the agg-layer runtime vaults named in the incident (`vpp-agg-appsec-d` / `vpp-agg-appsec-a`). It does not propagate from the sandbox vault `vpp-agg-sb` to runtime vaults — consistent with the incident's "rotated into sandbox, never propagated" failure mode (A2).

### A1 — SUPPORTING: Secret expiry detection pipeline

- Path: `/Way of Working/DevOps & Platform/Tutorials-HowTos/Certificates and Secrets/Secret expiry pipeline` (Page ID 36619)
- *"We have the following pipeline https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build?definitionId=2735 which checks for expiring certificates and posts a message to myriad-alerts-devops channel."*
- A2: Detection exists but is notification-only; it does not auto-rotate and evidently did not prevent the 2026-01-10 expiry (gap — see (e)).

### A1 — ADJACENT (cross-team precedent, BTM): ESP Cert renewal

- Paths: `/Myriad - BTM/.../BTM How to Docs/ESP Certs/ESP Cert renewal` and `.../ESP Certs/Troubleshooting`; plus `/Myriad - BTM/B2C/Support tasks/Secret Rotation` and `/Myriad - BTM/B2C/Testing/How to test client certificates`.
- A3 (not fetched in full this session): listed in the wiki index as existing pages; not retrieved verbatim here. They are a parallel BTM-team ESP cert renewal procedure and a useful cross-check if the agg-layer runbook is insufficient. Flagged for follow-up, not relied upon as fact.

---

## (b) Owner / team

- A1: Renewal request channel = **Networking4All (Jenke van Gerven)**, who emails the **fm_VPP_support** mailbox about upcoming expiry (Page 12196).
- A1: ESP access / stream provisioning owner = **FM_BTO_Integration_Team@eneco.com** (the BTO / ESP Integration team), per ESP Integration page (6697): access to DevOps & EET_VPP streams is requested from this mailbox.
- A2: Operational execution of the agg-layer rotation runbook sits with the **VPP Platform & DevOps / Aggregation Layer team** (the runbook lives under `/Myriad - Aggregation Layer/`, uses the agg-layer ArgoCD `esp-certificate-agg` app and `vpp-aks-devops` keyvault tooling). Expiry alerts route to the **myriad-alerts-devops** Slack channel (Page 36619).
- A3: No single named DRI/owner field is stated on the runbook page itself.

## (c) Manual or automated?

- A2 (strong): Rotation is **manual / semi-automated**. The runbook (50903) is an entirely manual ArgoCD/keyvault checklist. The "Automation using Azure Pipelines" page (30987) automates only the PFX→keyvault-secret fan-out (`Cert-Upload` pipeline), and even there Step 1 (obtain the cert from the provider) is manual. The expiry pipeline (2735) only notifies. There is no documented end-to-end automated renewal of the mTLS **client** certificate.

## (d) How is the cert issued? (CA = Trust Provider B.V. via DigiCert)

- A1: Issuance is delivered to VPP as a **password-protected PFX (PKCS#12)** "we receive from ESP" containing CA cert + client cert + private key (Page 6791).
- A1: Renewal is initiated by **email request to Networking4All (j.vangerven@networking4all.com)** (Page 12196). Networking4All is a Dutch certificate reseller.
- A2: This is a **manual CSR / reseller-issuance flow through the Trust Provider B.V. (DigiCert) PKI**, NOT ACME and NOT internal-PKI self-service. The decoded CA chain embedded in the ESP Integration page (6697, `AxualCertificationCreationValues:CACertificate` / `ClientCertificate`) shows the issuer chain `Trust Provider B.V. ... TLS RSA CA G1` chaining to `DigiCert Global Root G2` — i.e. the client cert is issued by **Trust Provider B.V.** under DigiCert roots, brokered by Networking4All. This corroborates the incident's "CA = Trust Provider B.V. via DigiCert" framing (A1 chain bytes + A2 decode).

## (e) Gaps (explicitly stated)

1. A3 — The canonical runbook (50903) is written for **production** and does **not** enumerate dev/acc-specific steps, vault names, or sandbox→runtime propagation. The incident's exact failure (valid replacement landed in `vpp-agg-sb` sandbox vault on 2026-05-29 but never reached runtime vaults `vpp-agg-appsec-d` / `vpp-agg-appsec-a`) is **not addressed by any documented procedure** found. There is no runbook step that says "propagate the new cert from sandbox vault to dev/acc runtime vaults."
2. A3 — No documented preventive control closes the loop between the expiry-notification pipeline (2735 → myriad-alerts-devops) and an enforced rotation deadline; the 2026-01-10 expiry occurred regardless. The renewal docs assume Networking4All proactively warns via email — a human-dependent trigger.
3. A3 — The Certificate Renewal page's deployment/app-gateway/alerting detail is image-only (screenshots), so the precise keyvault-upload + app-gateway trigger steps for the renewal could not be transcribed from text.
4. A3 — BTM's parallel `ESP Cert renewal` / `Secret Rotation` runbooks exist in the index but were not fetched verbatim this session; recommended follow-up if the agg-layer runbook proves insufficient for dev/acc.

---

## How this was retrieved (command trace)

```bash
# index resolution
cat references/wiki-tree-index.md   # found "/Myriad - Aggregation Layer/Runbook certificate rotation aggregation layer"
# primary runbook
scripts/wiki-page.sh --path "/Myriad - Aggregation Layer/Runbook certificate rotation aggregation layer"   # Page 50903
# supporting
scripts/wiki-page.sh --path "/Way of Working/Development Guidelines/Development Style Guide & Information/ESP Integration"   # Page 6697 (CA chain bytes)
scripts/wiki-page.sh --path "/Way of Working/DevOps & Platform/Tutorials-HowTos/Certificates and Secrets/ESP certificate setup"   # Page 6791 (cert filenames, PFX anatomy)
scripts/wiki-page.sh --path ".../Certificates and Secrets/Certificate Renewal"   # Page 12196 (Networking4All contact)
scripts/wiki-page.sh --path ".../Certificates and Secrets/Secret expiry pipeline"   # Page 36619 (pipeline 2735)
scripts/wiki-page.sh --path ".../ESP certificate setup/Automation using Azure Pipelines"   # Page 30987 (Cert-Upload pipeline)
```
