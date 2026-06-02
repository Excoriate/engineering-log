---
task_id: 2026-06-02-001
agent: docs-adr-lane
status: complete
summary: AGG-Layer secret/cert architecture is largely UNDOCUMENTED; intended model inferred from generic platform pages (ESO->KeyVault->K8s Secret, ESP/Kafka mTLS certs maintained by tech lead); no `keys` secret, sandbox-vs-MC, or expired-cert runbook exists.
timestamp: 2026-06-02T00:00:00Z
---

# Lane D1 — Docs & ADR Authority (read-only)

Incident: VPP Sandbox K8s namespace `vpp-agg`, secret `keys` (Kafka/mTLS certs) went missing; certs expired ~6 months.
Scope of this lane: ADO wiki (Myriad - VPP + Platform-documentation) + `DesignDecisions` ADR repo only. Other lanes (runtime/IaC/Slack) out of scope.

Evidence labels: `A1 FACT` = exact wiki path/ADR file + quoted text; `A2 INFER` = derived; `A3 UNVERIFIED[blocked: reason]`.

> Concurrency note: another agent holds `.ai/runtime/current-task.json` (points to task `2026-06-02-004`). This lane's manifest (`2026-06-02-001`) is intact. No git/az/kube mutation performed; ADO wiki/repo reads only.

---

## Headline finding

**The Aggregation Layer's secret/certificate architecture is NOT documented as an architecture.** There is no ADR, no AGG wiki page, and no runbook that describes the `keys` secret, how `vpp-agg` obtains its Kafka/mTLS certificates, certificate lifetimes, or rotation. The intended model below is **reconstructed (A2 INFER)** from generic, platform-wide pages plus one Kafka library ADR. The absence itself is the most important finding for the RCA: a missing/expired secret in `vpp-agg` cannot be triaged from any existing document.

---

## Intended secret/cert architecture (per docs)

### 1. K8s secrets are intended to be sourced from Azure Key Vault via External Secrets Operator (ESO), referenced by ArgoCD

`A1 FACT` — wiki `/Way of Working/DevOps & Platform/Kubernetes/External Secrets Operator` (Page ID 49296, Myriad---VPP.wiki):
> "External Secrets Operator is a Kubernetes operator that integrates external secret management systems including Azure Keyvault. The operator reads information from external APIs and automatically injects the values into a Kubernetes Secret."
> "Service principal should have access to keyvault (Keyvault Secrets officer role is recommended)"
> "Create a External secret resource to use above secret store to fetch secrets from keyvault... This will create a Kubernetes secret called mariadb-kv-secrets... and poll for the secret change in every one hour."
> "Referring secrets in argocd — We can reference these existing secrets in our argocd value file of the application."

`A2 INFER` — The platform's intended pattern is: **Azure Key Vault (source of truth) → ESO `SecretStore`/`ClusterSecretStore` (via SP with KV Secrets Officer) → synthesized K8s `Secret` → referenced by the ArgoCD app value file.** If `vpp-agg` followed this pattern, the `keys` secret would be auto-regenerated from Key Vault on a ~1h poll and could not "go missing" unless (a) ESO was not configured for it, or (b) the KV item itself was deleted/expired. The reported "missing for ~6 months / expired certs" behavior is more consistent with a **statically-applied secret NOT managed by ESO** (see gap below).

### 2. Kafka / ESP authentication is via mTLS certificates, "maintained by the tech lead/lead developer"

`A1 FACT` — wiki `/Architecture & Designs/Solution design/Integration architecture/ESP-Kafka integration` (Page ID 4223, Myriad---VPP.wiki):
> "ESP is the Kafka based integration platform of Eneco, and is one of the key integrations of the VPP with other Eneco systems."
> "Certificates: Authentication is required using certificates. These are maintained by the tech lead/lead developer."
> "A user group in the self-service portal... Our current group: 'Team EET-VPP'"
> "An application (which can be producer and consumer)... Current: eet-vpp"
> "Link of the certificate and application (upload PEM file)"

`A2 INFER` — Kafka/ESP access is mTLS with **PEM certificates uploaded per ESP application (`eet-vpp`)**, and ownership is explicitly a **human role (tech lead / lead developer), not an automated rotation system.** This is the documented owner for Q5. There is no documented automatic renewal — consistent with a 6-month silent expiry.

### 3. The Kafka client cert handling model: certs delivered, base64-encoded, written to local files per service

`A1 FACT` — ADR `implementation-decision-records/I001-New-confluent-kafka-nuget-package/README.md` (DesignDecisions), "Positive Consequences #5":
> "Improved Certificate Management: The new package simplifies certificate handling. Post bug resolution in the Confluent library, it will enable direct use of certificates as received, eliminating the current need to convert them into base64 and recreate local files for services."

`A2 INFER` — At the time of writing (migration Axual → Confluent, 2023-11-13), the working model was: **certificate received → converted to base64 → recreated as local files for the service.** This matches a K8s `Secret` named `keys` holding base64 cert material mounted into the pod — i.e., the `keys` secret is the **service's Kafka mTLS cert bundle.** This ADR also explicitly names "Johnson Lobo already spent time" on the migration — consistent with the incident note that Johnson borrowed certs from VPP Core.

`A1 FACT` — wiki `/Way of Working/DevOps & Platform/Tutorials-HowTos/Kubernetes Secrets` (Page ID 6281): confirms the generic model — "Secrets are - by default - base 64 coded" with `base64` / `base64 -d` examples. No mention of `keys` or Kafka.

### 4. Target-state inter-layer transport is moving to Event Hubs (not ESP/Kafka) — but that is L3↔L4, not the AGG secret model

`A1 FACT` — ADR `architecture-decision-records/AggregationLayer/AL011-VPPAL-In-VPPInternational/AGG in Target state.md` (Status: accepted, 2025-09-18, deciders Hein Leslie, Wesley Coetzee, Tomasz Brzezinski, Alex Shmyga):
> "Currently, communication between VPPCore and VPPAL occurs via the ESP. However, in the future state, VPPCore at L3 will not have direct connectivity to Level 4 (L4) where ESP resides. Communication must therefore pass through the Transfer Zone, which will utilize Azure Event Hubs..."
> Decision: "Option 3 – VPPAL publishes directly to L3.5 Event Hubs."

`A2 INFER` — Today (per ADR's "Currently") VPPCore↔VPPAL still rides **ESP/Kafka with certificates**; Event Hubs is the *future* target. So the expired-cert failure mode is current-state-relevant and not retired by AL011. AL004 (`EventHubs-for-internal-communication`) covers AGG-internal Event Hubs but is internal, not the ESP cert path.

---

## Q3 — Troubleshooting Guide / FAQ coverage of `keys` / FailedMount / cert expiry / Kafka certs / sandbox

`A1 FACT` — Platform-documentation wiki `/Guides/Troubleshooting Guide` (Page ID 68128, "Maintained by Trade Platform Team, Last updated April 2026") sections present: FBE failures; "Kafka Application ID changed — FBE configuration is broken" (Axual App ID propagation, NOT certs); Azure Portal 401; ADX prod; VPN; **"Local Mac reaches Sandbox but not DEV/ACC/PROD private endpoints"** (sandbox is mentioned only as the *non-private-endpointed* env that "just works"); Gurobi; Terraform replace/TFLint; Postgres `permission denied for table`.
- **No entry for**: a missing/`FailedMount` K8s secret, the `keys` secret, certificate expiry, ESP/Kafka mTLS cert rotation, or `vpp-agg`.

`A1 FACT` — Platform-documentation wiki `/Guides/FAQ` (Page ID 68127) covers onboarding/ADO license, AAD group PRs, ArgoCD repo connections & sync, SonarCloud, Gurobi portal, Postgres Entra access, CCoE keyvault repo permissions. The only secret/cert-adjacent FAQ is "How do I get CCoE repo permissions (e.g., terraform-azure-keyvault)" — a **repo-access** question, not cert rotation.
- **No FAQ entry for** rotating Kafka/ESP certs or recreating a missing `keys` secret.

`A2 INFER` — The two canonical "platform self-service" docs (FAQ + Troubleshooting Guide), actively maintained to April 2026, have **zero coverage of the `keys`-secret / expired-Kafka-cert failure class.** Next on-call hitting this has no documented path.

---

## Q4 — Sandbox vs MC for the aggregation layer (secrets/certs)

`A1 FACT` — Platform-documentation `/Guides/Troubleshooting Guide` (Page ID 68128): "Sandbox does **not** need this — sandbox is not private-endpointed." And `/Guides/FAQ` (68127): "Private-endpointed Postgres hosts need an explicit hosts entry... Sandbox does **not** need this — sandbox is not private-endpointed."
`A1 FACT` — wiki `/Way of Working/DevOps & Platform/Tutorials-HowTos/ArgoCD/ArgoCD Sandbox` exists in the tree (per wiki-tree-index) — a dedicated ArgoCD Sandbox doc, separate from MC ArgoCD.

`A2 INFER` — Documented Sandbox/MC difference is at the **networking** layer (Sandbox = public/no private endpoint; MC/DEV/ACC/PROD = private-endpointed, VNet-integrated). **There is NO documented difference in the secret/cert provisioning model between Sandbox and MC for the aggregation layer.** That is itself a gap: whether Sandbox `vpp-agg` is supposed to use ESO+KeyVault like MC, or a hand-applied secret, is undocumented — which plausibly explains why a Sandbox `keys` secret could silently disappear and expire while an MC one (if ESO-managed) would self-heal. `A3 UNVERIFIED[blocked: no doc states the Sandbox AGG secret-provisioning mechanism]`.

---

## Q5 — Kafka cert ownership / rotation & relationship to VPP Core certs

- **Ownership (documented):** `A1 FACT` ESP-Kafka integration page: "Certificates... are maintained by the tech lead/lead developer." Cert↔ESP-application linking is manual ("upload PEM file"), via the ESP self-service portal / FM_BTO_Integration_Team. The ESP application is `eet-vpp`, group `Team EET-VPP`.
- **Rotation procedure:** `A3 UNVERIFIED[blocked: no rotation runbook found]`. The wiki tree shows a `Certificates and Secrets` how-to cluster (`/Way of Working/DevOps & Platform/Tutorials-HowTos/Certificates and Secrets` with children: pfx file management, Generate self signed, **Secret expiry pipeline**, **Certificate Renewal**, ESP certificate setup) — NOT fetched this pass to respect rate limits, but their titles indicate a *generic* cert-renewal + secret-expiry-pipeline how-to exists. Whether it covers the AGG `keys`/ESP cert specifically is unverified. **Recommend the RCA lane fetch `/Way of Working/DevOps & Platform/Tutorials-HowTos/Certificates and Secrets/Certificate Renewal` and `.../Secret expiry pipeline`.**
- **VPP Core relationship ("Johnson borrowed certs from VPP Core"):** `A3 UNVERIFIED[blocked: no doc describes AGG borrowing/sharing VPP Core certs]`. Closest signals: I001 ADR names "Johnson Lobo" on the Kafka migration; wiki tree has `/Product Functional Designs/VPP Core/VPP Core NL/mFRR Activation Service/Tennet mFRR API - Certificates Setup` and a BTM `ESP Certs/Troubleshooting` page — i.e., VPP Core and BTM each have their own ESP cert docs, but **no document establishes that the Aggregation Layer is supposed to reuse VPP Core's certificates.** If Johnson borrowed VPP Core certs, that was an undocumented operational workaround, not an architecture.

---

## Documentation gaps found

1. **No AGG-Layer secret/cert architecture doc.** No ADR and no `Myriad - Aggregation Layer` wiki page describes how `vpp-agg` obtains secrets/certs. `repo-search DesignDecisions "secret"` → **NO RESULTS**; `"certificate"` → only I001 (a NuGet-library ADR, not an architecture).
2. **No `keys`-secret / FailedMount / expired-cert runbook.** Absent from the Platform Troubleshooting Guide AND the AGG Disaster Recovery Runbook.
3. **AGG Disaster Recovery Runbook is a stub.** `A1 FACT` wiki `/Myriad - Aggregation Layer/Operations & Support/Disaster Recovery/Application Runbooks/Aggregation Disaster Recovery Runbook` (Page ID 64681): sections "Application Key Indicators" and "Chain Key Indicators" are literally `TODO`; it covers only "download pod logs" + an App Insights link. No secret/cert recovery procedure.
4. **Sandbox secret-provisioning model undocumented.** Docs distinguish Sandbox from MC only by network/private-endpoint posture, not by whether AGG secrets come from ESO+KeyVault or are hand-applied.
5. **No documented Kafka cert rotation tied to AGG.** Ownership is "tech lead/lead developer" (a person, no automation named); a generic Certificate Renewal / Secret expiry pipeline how-to exists (titles only, unfetched) but is not linked from any AGG doc.
6. **No documented VPP Core ↔ AGG cert sharing.** The "borrowed certs from VPP Core" arrangement has no architectural backing in docs/ADRs.

---

## Hypothesis status (for RCA synthesis)

- **H1 (AGG secret/cert architecture IS documented):** ELIMINATED. `A1` searches + page reads returned no architecture doc.
- **H2 (it is undocumented; absence is the finding):** SUPPORTED. The intended model had to be reconstructed (A2) from generic platform pages + one library ADR.
- **Operative inference for RCA:** A `keys` secret that "went missing for ~6 months and expired" is most consistent with a **statically-applied K8s secret holding base64 ESP/Kafka mTLS PEM certs, NOT managed by ESO**, whose underlying certificates have a human (tech-lead) ownership model with no automated renewal — i.e., a documentation+ownership gap, not a designed self-healing path. `A2 INFER` — requires the runtime/IaC lanes to confirm whether `vpp-agg`'s `keys` secret is ESO-backed or static.

---

## Pages/ADRs fetched this lane (A1 sources)

| # | Surface | Path / ID |
|---|---------|-----------|
| 1 | Wiki (Myriad-VPP) | `/Way of Working/DevOps & Platform/Kubernetes/External Secrets Operator` — Page 49296 |
| 2 | Wiki (Myriad-VPP) | `/Architecture & Designs/Solution design/Integration architecture/ESP-Kafka integration` — Page 4223 |
| 3 | Wiki (Myriad-VPP) | `/Way of Working/DevOps & Platform/Tutorials-HowTos/Kubernetes Secrets` — Page 6281 |
| 4 | Wiki (Myriad-VPP) | `/Myriad - Aggregation Layer/Operations & Support/Disaster Recovery/Application Runbooks/Aggregation Disaster Recovery Runbook` — Page 64681 |
| 5 | Wiki (Platform-documentation) | `/Guides/Troubleshooting Guide` — Page 68128 |
| 6 | Wiki (Platform-documentation) | `/Guides/FAQ` — Page 68127 |
| 7 | ADR (DesignDecisions) | `implementation-decision-records/I001-New-confluent-kafka-nuget-package/README.md` |
| 8 | ADR (DesignDecisions) | `architecture-decision-records/AggregationLayer/AL011-VPPAL-In-VPPInternational/AGG in Target state.md` |
| - | Repo search (DesignDecisions) | `"secret"` → NO RESULTS; `"certificate"` → only I001; `"kafka"` → 13 hits (AL004, I001, VPP001, CoreLayer) |

## Suggested follow-up fetches (NOT done — rate limit; for RCA/other lanes)

- `/Way of Working/DevOps & Platform/Tutorials-HowTos/Certificates and Secrets/Certificate Renewal`
- `/Way of Working/DevOps & Platform/Tutorials-HowTos/Certificates and Secrets/Secret expiry pipeline`
- `/Way of Working/DevOps & Platform/Tutorials-HowTos/ArgoCD/ArgoCD Sandbox`
- `/Product Functional Designs/VPP Core/VPP Core NL/mFRR Activation Service/Tennet mFRR API - Certificates Setup` (VPP Core cert model, for the "borrowed certs" angle)
