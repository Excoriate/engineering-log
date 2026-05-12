---
task_id: 2026-05-11-007
agent: claude-code
status: complete
summary: Distilled durable knowledge from today's 4 on-call incidents — extracted patterns, mechanisms, and reusable insights, cross-checked against existing vault coverage.
---

# Today's Incidents — Durable Knowledge Extraction (2026-05-11)

> Source artifacts: `log/employer/eneco/02_on_call_shift/2026_05_11_*/` (4 dirs, ~575k bytes of RCA + supporting docs).
> Method: read L1/L8/L10/L11 of each rca.md + context.md + slack-intake.txt + supporting playbooks + cross-correlated with Slack (#myriad-platform + #team-platform 1-week harvest).

## Incident 1 — CMC alert `vpp-resource-unhealthy` (production)

### One-line summary
ServiceNow CMC INC2384584 fired at 13:12 UTC; root cause = Microsoft Azure platform incident `5Z1B-6KG` (Log Analytics + Application Insights data latency in West Europe) caused workspace to ingest ServiceHealth rows late, which triggered an over-broad, out-of-IaC sev-0 alert rule with `autoMitigate=false`. No Eneco workload was actually unhealthy. **Status: CLOSED by Alex at 15:06 UTC; flagged for SRE/Platform IaC adoption follow-up.**

### Load-bearing mechanism (A1)
- Alert rule: `Microsoft.Insights/scheduledQueryRules/vpp-resource-unhealthy` in `mcprd-rg-vpp-p-res`
- KQL: `AzureActivity | where CategoryValue == "ServiceHealth"` (single predicate, no further filter)
- Threshold: `Count > 1` over 5-min window
- `actions: null` (no Action Group → no Rootly page; ServiceNow received via A3-UNVERIFIED separate path)
- Created 2024-01-24 by `eelke.hoffman@conclusion.nl` (Conclusion vendor SPN), `systemData.createdAt == lastModifiedAt` byte-identical (= never re-written via ARM PUT)
- Fire mechanism: Microsoft `5Z1B-6KG` backlog drain caused 2 ServiceHealth rows (TG 12:54:56Z + 12:55:53Z) to be ingested at 13:09:10Z / 13:09:44Z → fell into Azure's `ingestion_time()` evaluation window `12:52:07Z–12:57:07Z` → `metricValue=2.0` → fire at 13:12:43Z

### Adversarial review pattern (load-bearing)
- 2 typed adversaries dispatched: `socrates-contrarian` + `el-demoledor`
- Both verdicts: PROCEED-WITH-CHANGES
- 12 findings BLOCKING/HIGH absorbed in v2.0 (see Mutation Log in rca.md)
- F3 demoledor BLOCKING: forced creation of `oc-playbook.md` (cluster sanity check) as mandatory pre-close gate

### Durable lessons (3) — from rca.md L10
1. **Out-of-IaC alerts decay silently for years** — defense: quarterly Azure→IaC alert inventory diff (`az monitor scheduled-query list` vs IaC tfvars)
2. **`CategoryValue == "ServiceHealth"` is the wrong knob** without narrowing (`ActivityStatusValue`, `impactedServices`, per-service KQL projection); use `ResourceHealth + Activated/action + ResourceProviderValue` for per-resource semantics
3. **`autoMitigate=false` on paging-bound rule requires manual-close runbook** — **orthogonal to severity** (sev-2 with autoMitigate=false has same "stays Fired forever" property); severity merely intensifies on-call cost

### Side observation (vendor governance)
- Rule created by Conclusion vendor identity, sev-0, on production, escaped IaC for 15.5 months. Governance/audit question for SRE/Platform — flagged in RCA, not actioned in on-call.

### Reusable pattern → vault candidate
- `oc-playbook.md` (192 lines) — **rule-out, not diagnose** OpenShift sanity check for cluster/Azure-window-bounded alerts. 4 probes:
  1. Non-Running pods (snapshot)
  2. Abnormal events in window (transitions)
  3. Restart count terminations in window (state-during-event)
  4. (Optional) Azure-side ResourceHealth events for namespace-backed resources (complementary falsifier)
- Principle: *"the cloud-side alert's truth surface is the workspace; the workload's truth surface is the cluster API. When the workspace was demonstrably stale, the workload truth surface is authority — ALWAYS probe the cluster directly."*

### Existing vault overlap
- `learnings/lessons/oncall-rca-must-close-on-every-state-plane.md` → today's incident STRENGTHENS this with a concrete Azure+ServiceNow two-plane close example (the existing note covers Rootly+Azure; today adds Azure+ServiceNow as a sibling instance)

---

## Incident 2 — FBE-create failure (Duncan / kidu slot)

### One-line summary
Duncan Teegelaar triggered FBE-create build 1638601 at 09:56 CEST; Terraform apply failed with `azurerm_eventhub_namespace "vpp-evh-premium-kidu" already exists` — Azure-resource orphan from prior slot release. Retry failed faster (steady, non-transient). Fix = delete orphan in Azure, re-run pipeline. **Status: RCA + fix doc authored; user-owned execution.**

### Load-bearing mechanism (A1)
- Subscription: Sandbox `7b1ba02e-bac6-4c45-83a0-7f0d3104922e`
- Resource group: `rg-vpp-app-sb-401`
- Resource: `vpp-evh-premium-kidu` (Event Hub Premium namespace) — exists in Azure, NOT in Terraform state
- Module path: `module.eventhub_namespace_premium.azurerm_eventhub_namespace.eventhub_namespace`
- Terraform version: 1.14.3 (create pipeline) vs 1.13.1 (destroy pipeline — F19 version drift)
- Orphan state: **EMPTY** (zero event hubs, zero consumer groups, zero auth rules beyond auto-SAS, zero IP/vnet rules) → safe to delete-recreate
- Orphan age: ~11 months (createdAt 2025-06-10)

### Fix decision rationale
**Delete-recreate over `terraform import`**, 3 reasons:
1. Orphan is empty (no data to preserve)
2. Orphan is 11 months stale; import would trigger immediate drift vs current IaC (network rules, SKU sub-attributes, tags)
3. `terraform import` from ADO pipeline is awkward (no import hook in `azure-pipelines-featurebr-env.yml`)

### Provenance (3 candidate paths, all uneliminated)
- P1: Failed destroy with `terraform state rm` workaround
- P2: Out-of-band create
- P3: Terraform version drift (1.14.3 create vs 1.13.1 destroy) → silent skip on state-version-mismatch
- **Fix is identical regardless of which path**

### Durable lessons (3) — from rca.md L10
1. **Apply-time Azure-resource orphan on slot reuse is empirically live** — destroy pipeline lacks residue-zero check → next slot tenant inherits the trap. Defense: `azure-pipeline-fbe-del.yml` must verify zero residue before slot release; also resolve F19 (destroy pipeline still on TF 1.13.1)
2. **Stale local clones hide their staleness** — two clones of same ADO repo at different HEADs led to misidentifying the active pipeline. Defense: pair FIRST `Read` of a repo file with `git log -1 --format='%h %s %ad'`
3. **Cross-repo failure paths require explicit topology** — `.terraform/modules/<local-name>/<internal-path>` decodes to LOCAL_NAME mapping to SOURCE_URL in calling IaC. Reading the error path verbatim goes to the WRONG file. Defense: L2 repo topology must be documented before reading

### Convergence with Incident 4 (ArgoCD PAT)
Duncan's FBE-create was actually blocked by TWO problems:
- **Upstream blocker (orthogonal)**: F2 EventHub namespace orphan (this incident)
- **Downstream blocker**: ArgoCD ApplicationSet PAT expired → even after F2 fix, kidu's child Applications would not generate

Both must be resolved before Duncan's FBE is functional.

### Existing vault overlap
- `episodes/2026-04-21-stefan-vpp-mfrr-activation-crashloop.md` — adjacent FBE episode; today's adds a NEW failure mode (Terraform state orphan)
- `learnings/gotchas/eneco-vpp-sandbox-is-aks-not-openshift.md` — confirms sandbox is AKS; today's incident is on sandbox AKS

---

## Incident 3 — Rootly alert `ln2I9h` — CPUThrottlingHigh on otc-container

### One-line summary
Rootly Low-tier page at 11:45 UTC (04:45 Pacific); 49.76% CPU throttling on `otc-container` in pod `opentelemetry-collector-collector-566b6bd96-2htph`, namespace `eneco-vpp`, **DEV cluster** (`eneco-vpp-dev.ceap.nl`). **Status: acknowledged; observation-only RCA shipped; NO fix recommended pending discrimination.**

### Load-bearing observation
The RCA was authored deliberately as **observation-only** because 4 hypotheses are not yet discriminated:
- **H-A**: Undersized CPU limit (regression vs. legacy chart suspected, unverified)
- **H-B**: Memory pressure upstream → GC bursts → CPU spikes → CFS throttling
- **H-C**: Upstream PrometheusRule mis-calibrated for sidecar workload class (cluster-wide)
- **H-D**: Debug exporter verbose (`verbosity: detailed`) drawing CPU

### Hypothesis dependency (NOT all peers)
- H-B → drives → H-A (memory upstream)
- H-D → drives → H-A (stdout I/O CPU draw)
- H-A is the SYMPTOM, not a cause
- H-C is orthogonal (rule itself, not this pod)

### Adjudication heuristic
- Confirming H-A alone = pressure exceeded limit; doesn't say WHY
- Confirming H-B + H-A = upstream memory; raising CPU without fixing memory just delays next memory alert
- Confirming H-D + H-A = upstream debug verbose; fixing debug config is cheapest
- Confirming H-C alone (cluster-wide) = rule itself is the issue

### Durable lessons (3) — from rca.md L10
1. **Routing label ≠ severity grading** — SaaS alerting platform's tier description (Low/Medium/High/Critical) can be workspace default, not team policy. Probe: query platform's tiers API; identical descriptions across tiers OR batch-created timestamps suggest defaults. Defense: team urgency calibration belongs in routing config + team runbooks, not in alert label
2. **Causal arrow asserted from snapshot can be falsified by timeline** — when alert fires with adjacent symptoms (CPU + memory), don't read causal direction from which alert fires; read it from temporal order + magnitude trend. Probe: enumerate all related alerts on same target over longest window. Defense: hold both causal directions as candidates until time-series probe discriminates
3. **Name-match is not deployment proof** — finding a file whose `metadata.name` matches the pod's expected source is INFER, not FACT. The runtime cluster's own object store (`kubectl get -o yaml`) is the only authoritative source

### Adversarial review pattern
- Antecedent attacks (pre-RCA): `sherlock-diagnosis-attack.md`, `socrates-framing-attack.md`
- Post-draft attacks: `el-demoledor-post-draft-attack.md`, `socrates-post-draft-attack.md`
- Cross-RCA correlation with prior incident: `cross-rca-correlation-with-005.md`
- Pattern: **observation-only RCA is the correct shape when hypotheses are not yet discriminated** — shipping a fix before discrimination ships the wrong fix and masks the real cause

### Reusable pattern → vault candidate
- L11 cold-start command playbook (220 lines) — preconditions (ROOTLY_API_KEY, oc CLI, OCP_TOKEN), Rootly alert decode, engagement timeline, history pattern intelligence, then per-hypothesis probes. Discriminator-first cold-start.
- Step 1 reusable principle: *"the platform that emitted the page owns the canonical state; do not start with the runbook URL or the Slack thread"*

### Existing vault overlap
- No existing vault note on CPU throttling, otc-container, or OpenTelemetry collector → **clean greenfield for new lessons + new pattern**

---

## Incident 4 — ArgoCD secret rotation (4 expiring PATs)

### One-line summary
PAT expiration report posted 2026-05-08 in `#myriad-alerts-devops` flagged `argo-cd-sandbox` PAT as Critical (expired 2026-05-10) and 3 MC PATs as Warning (`argo-cd-{devmc,accmc,prdmc}-cmc-goldilocks-repository`, expiring 2026-06-01). PAT expiry caused `vpp-feature-branch-environments` ApplicationSet to fail `ApplicationGenerationFromParamsError` since 2026-05-10T12:40:13Z — silently breaking 3 new FBE slots (kidu/boltz/enel). Surfaced ~22h later by Fabrizio's question in #team-platform. **Status: sandbox PAT rotated today (Alex + Fabrizio); 3 MC PATs deferred to 2026-05-12. Comprehensive runbook (`how-to-rotate.md` 1291 lines) + proposal (`proposal-rotation-automation.md` 505 lines) authored.**

### Load-bearing mechanism (A1)
- Service account: `sa_platform_vpp@eneco.com` (shared, login in Trade Platform Team vault)
- PAT semantics: bearer credential; ADO ceiling 12 months; minted after sign-in as SA
- Storage:
  - Sandbox: K8s `Secret` with label `argocd.argoproj.io/secret-type: repository`, namespace `argocd` (AKS `vpp-aks01-d`)
  - MC: namespace `eneco-vpp-argocd` OR `openshift-gitops` (UNVERIFIED — Fabrizio to confirm)
- Source secret in Azure KeyVault: `argocd-repository-credentials-template-url-{acc,devmc}` in `vpp-appsec-d` (2 of 4 PATs; gaps for sandbox + prdmc)
- ApplicationSet failure mechanism: PAT expires → Git auth break → `ApplicationGenerationFromParamsError` → existing Application CRDs survive (etcd-persisted) BUT new generations fail → newly-recycled slots get no apps
- Recovery: rotate PAT + update Opaque secret + ApplicationSet retries every minute → kidu's child Applications materialize within 3-5 min

### Why 4 PATs (architectural)
Each ArgoCD install has its own repo credential (per-cluster isolation by ArgoCD design):
1. Sandbox ArgoCD (AKS `vpp-aks01-d`) → `VPP.GitOps` → `argo-cd-sandbox` PAT
2. dev-MC ArgoCD (OpenShift) → `cmc-goldilocks` → `argo-cd-devmc-cmc-goldilocks-repository` PAT
3. acc-MC ArgoCD (OpenShift) → same in acc env
4. prd-MC ArgoCD (OpenShift, production) → same in prd env

Trade-off: compromised PAT on sandbox doesn't break prd; rotation overhead is 4×.

### Goldilocks identity
Per Roel (#team-platform 2026-03-03): *"I asked him to update a PAT for me in the CMC ArgoCD instance for the Goldilocks application."* Repo content + identity is `[PENDING: ask Fabrizio]`. **Likely: CCoE managed-cloud policy / version-pinning ArgoCD app** (NOT the k8s VPA tool of same name). UNVERIFIED.

### Recurrence pattern — the CLASS problem
| When | Surface | Cause | Resolution |
|------|---------|-------|------------|
| 2024-11-19 (INC-75) | Multi-FBE | AAD SP secret expired | Fabrizio rotated per-FBE; post-incident: *"This manual process is error-prone and must be automated"* |
| 2025-12-29 (F4) | All active FBEs | Same AAD SP (`6db398ec-...`) expired again | Manual rotation over ~1h+ |
| 2026-05-07 (PXQ) | PXQ service | KeyVault client secret expired | Same class |
| **2026-05-11 (today)** | Sandbox FBE | ArgoCD PAT expired | Manual today |
| **2026-06-01 (latent)** | dev-MC / acc-MC / prd-MC | 3 ArgoCD PATs scheduled | Proactive rotation needed |

Fabrizio (DM 2026-04-10): *"this is a shit job to be done and can cause outages."*

### Remediation options proposed (3)
- **A — Workload Identity Federation** (eliminate PATs entirely): 10-15d eng; HIGH cutover risk; LOW steady-state risk; doesn't help non-ADO credentials
- **B — KeyVault + ESO + scheduled rotation**: 7-10d (but ESO must be installed first); ESO is NOT deployed at Eneco today; cross-class extensible
- **C — Status quo + SLA + Grafana alert + ownership**: 1-3d; buys time; doesn't fix the class
- **Recommended sequence**: Phase 1 (now-30d) = C unconditionally; Phase 2 (30-180d) = A or B based on Fabrizio's gap answers; Phase 3 (180d+) = extend chosen option to F4/ESP/TF SP/BTM/Snyk classes

### Silent-failure mode (durable diagnostic gotcha)
- FBE pipeline reports `partiallySucceeded` + Slack `1/4 Success` — visible signals do NOT point at credential layer
- Diagnostic surface: `kubectl describe applicationset vpp-feature-branch-environments -n argocd` — in NO first-look runbook
- **Proposed Grafana alert**: `argocd_appset_status{condition_type="ErrorOccurred"} > 0` → real-time auth-break detection

### Existing vault overlap
- `learnings/gotchas/argocd-app-of-apps-product-team-cannot-sync.md` — **ORTHOGONAL** (about Casbin RBAC denying sync at product-team boundary; today's PAT issue is about auth break to git source). Both should cross-link as "ArgoCD failure mode family" siblings.
- `patterns/workflows/argocd-helm-oci-plus-appconfig-plus-kv-csi-three-layer-config-stack.md` — today's PAT failure is a **Layer 1 (deploy-time)** failure mode (ArgoCD sync broken because repo auth failed). Should cross-link.
- `memory/verify-own-prior-claim-via-parallel-adversarial-evaluator.md` — adversarial methodology reinforced by today's draft+attack pattern.

---

## Pattern Across All 4 Incidents (today's meta-learning)

### Adversarial discipline is now mandatory practice
- Incident 1 (CMC): socrates + el-demoledor, 12+ findings absorbed
- Incident 2 (FBE): Sherlock attack + post-draft adversarial
- Incident 3 (CPU): 4 separate adversarial reviews (antecedents + auxiliary)
- Incident 4 (ArgoCD): Socrates S3 attack noted in runbook (PAT-vs-credential conflation)

→ **Durable insight (memory zone)**: typed-subagent adversarial review is the operational default for on-call RCA at Trade Platform; sequence is **draft → adversarial typed subagent → mutation log → re-verify**.

### Today's work surfaces in 4 different intake channels
1. FBE Duncan: #myriad-platform General Request (Slack Lists card)
2. CMC alert: ServiceNow CMC ticket INC2384584 (manual paste by Alexandre)
3. CPU throttling: Rootly direct page (ln2I9h) — NOT in either Slack channel
4. ArgoCD PAT: #team-platform private discussion (Fabrizio's question)

→ **Durable insight (lesson)**: "what happened today on-call" cannot be reconstructed from any single intake channel. Reading #myriad-platform misses 50%+. Future on-call summarizers MUST sample: Slack public + Slack private + Rootly + ServiceNow + RCA dir.

### Credential expiry is the dominant class of operational pain
4-of-5 recent recurring incidents = credential expiry (AAD SP × 2, KV secret × 1, PAT × 1). The next latent is the 3 MC PATs on 2026-06-01. Class-level remediation (Option A or B) > per-incident firefighting.

### Architecture diagrams arrived TODAY at Trade Platform domain
Roel pinned 4 icepanel diagrams to the trade-platform domain home page on 2026-05-11:
1. OpenTelemetry routing
2. Gurobi DEV
3. Gurobi PROD
4. Gurobi prod AZ-redundancy (DRAFT — Nuno's near-future change)

These are durable architectural references; vault context note recommended.

### LTR + Immutable Backups landed 2026-05-01
Long-Term Retention + locked time-based immutability on 6 VPP production SQL databases (`vpp-sqlserver-p`): `asset`, `assetmonitor`, `assetplanning`, `assetplanning-tennetde`, `assetplanning-assets`, `assetplanning-elia`. Until retention window expires, NO admin / script / Microsoft Support / ransomware can alter or delete the backups. Durable architectural posture; vault context note recommended.
