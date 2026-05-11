---
task_id: 2026-05-11-005
agent: socrates-contrarian
timestamp: 2026-05-11T16:30:00+00:00
status: complete

summary: |
  Adversarial Socratic review of rca.md for vpp-resource-unhealthy fire. Verdict
  PROCEED-WITH-CHANGES. Twelve findings: 2 BLOCKING (mechanism attribution gap on
  E10's count>1 satisfaction, and L4/L6 layers missing from holistic-RCA schema),
  6 HIGH (createdBy=User does not prove "manual portal" creation; "no workload
  affected" rests on dismissal of a PRD Rootly alert in window; Lesson 3 conflates
  severity and autoMitigate; CMC term in context ledger not actually sourced from
  the ticket; ServiceHealth payload's textual times disagree with structured times
  the RCA picks one without flagging the other; A2/A3 labels on the same fact in
  two places). 3 MEDIUM (E16 Kusto-LA shared-engine reasoning is training-derived;
  ServiceNow connector path stated as A2 but referenced in TL;DR as if confirmed;
  "Microsoft event caused this fire" is temporal correlation, not ID-matched
  causal chain). 1 LOW (rule lastModifiedAt = createdAt is a useful additional
  fact the RCA could cite). The strongest counter-case (Lane 7) is that the
  workspace ingested two rows for the same Microsoft communication during the
  latency-recovery backlog, satisfying count>1 from a single notice — more
  credible than "one event in a five-minute window crossed a >1 threshold."
---

# Socratic Attack on rca.md

## Key Findings

- F1: BLOCKING — E10 mechanism attribution: no sidecar shows ≥2 rows in the 5-min window
- F2: BLOCKING — L4 and L6 missing; on-call-incident-workflow.md rule requires all 12 layers
- F3: HIGH — "manually created in the Azure portal" is A2, not A1; createdByType=User does not entail portal
- F4: HIGH — "No Eneco workload affected" rests on the Rootly sidecar's a-priori dismissal of oTiT7t (PRD, in-window)
- F5: HIGH — Lesson 3 conflates severity and autoMitigate as one trap
- F6: HIGH — CMC term in Context Ledger sourced from directory slug, not from the ticket payload
- F7: HIGH — Microsoft communication payload has two disagreeing time fields; RCA picks one without flagging
- F8: HIGH — L5 table labels Eneco-source-tree A3, but evidence ledger labels same fact A2
- F9: MEDIUM — E16 "shared platform" Kusto/LA reasoning is training-derived inference; falsifier not run in scope
- F10: MEDIUM — ServiceNow ITSM-connector path is A2 in Limitation 4 but L7 timeline narrates it as causal
- F11: MEDIUM — "Microsoft event triggered this fire" is temporal correlation only; no ID-match from communication to alert payload
- F12: LOW — lastModifiedAt == createdAt strengthens "never modified" claim; worth citing

## Verdict

**PROCEED-WITH-CHANGES**

The RCA's framing is directionally correct — an out-of-IaC, over-broad,
unrouted, sev-0 scheduled-query-rule that fires on the Microsoft platform
announcement stream is a real pathology and the close-only choice is defensible.
But the document leans on at least one mechanism step the sidecars do not prove
(E10's count>1 satisfaction), labels at least one inference as observation
("manually created in the Azure portal"), and is missing two of the twelve
mandated holistic-RCA layers (L4, L6). Lesson 3 collapses two orthogonal
properties (severity and autoMitigate) into one trap, weakening rephrase
transfer. None of this overturns the routing decision, but each is a real
gate-violation in the existing evidence ledger.

## Findings (numbered, severity-tagged)

### F1 [BLOCKING] — Mechanism attribution: no sidecar proves count>1 in the firing 5-min window

- **What I see in the RCA**: E10 in the Evidence Ledger — *"Within the 5-minute
  evaluation window at 13:12:43 UTC there were ≥2 AzureActivity ServiceHealth
  rows visible to the workspace (count > 1 satisfied)"*, labeled A2, citing
  *"the workspace 12:00-13:00 UTC hour had 2 ServiceHealth events"*. The TL;DR
  states this as confirmed mechanism: *"satisfied the rule and pushed it over
  its `Count > 1` threshold inside the 5-minute window."*
- **Why it is wrong / weak**: The cited sidecar
  (`workspace-servicehealth-firetime.json`) is a JSON array of length **one** —
  a single ServiceHealth row at `2026-05-11T13:10:36.36 UTC` with
  `ActivityStatusValue=Resolved`. The KQL window the sidecar queried is
  `13:00:00Z–13:15:00Z` (15 minutes), and even THAT 15-minute window has only
  one row. The rule's firing 5-minute window is `13:07:43Z–13:12:43Z` and there
  is **no sidecar evidence** of a second row in that window. The phrase
  *"12:00-13:00 UTC hour had 2 events"* in E10 has no corroborating probe in
  any sidecar — the only ServiceHealth row I can see is the 13:10:36 one. The
  rule's threshold is `operator: GreaterThan, threshold: 1.0, timeAggregation:
  Count` (azure-alert-rule-raw.json lines 16–20), so fire requires **strictly
  >1**, i.e., ≥2 rows. With one visible row, the rule should not have fired
  unless a second row exists that has not been probed.
- **Falsifier**: Re-run KQL `AzureActivity | where TimeGenerated between
  (datetime(2026-05-11T13:07:43Z) .. datetime(2026-05-11T13:12:43Z)) | where
  CategoryValue == "ServiceHealth" | count`. Expected ≥ 2 if the RCA is right;
  if 1, the RCA's mechanism is wrong and an alternative must be sought
  (candidates: a same-EventDataId redelivery; an earlier same-incident
  communication; or an entirely different ServiceHealth event the RCA missed).
- **Required patch**: (a) demote the TL;DR's *"pushed it over its Count > 1
  threshold"* phrasing to *"satisfied the rule's threshold via a count of
  ServiceHealth rows including, at minimum, the 13:10:36 Mitigated
  communication; the exact row count in the 5-min window is A3
  UNVERIFIED[blocked: 5-min-window KQL not re-run in scope]"*. (b) Add the
  KQL above to L9 as the explicit mechanism falsifier. (c) Rewrite E10 to
  state honestly: *"A3 UNVERIFIED[blocked: count not directly probed in the
  5-min firing window]. The 15-min window 13:00:00Z–13:15:00Z probed in scope
  shows ONE row; the second row required for count>1 satisfaction is hypothesized
  from rule-fired-therefore-threshold-met reasoning, not from a direct KQL count
  in the firing window."*
- **Conditional**: if the 5-min KQL returns count=1, then the mechanism in the
  TL;DR is wrong and the RCA must move to alternative mechanism (Lane 7
  counter-case below) before promotion to `complete`.

### F2 [BLOCKING] — L4 and L6 absent; on-call-incident-workflow rule mandates all 12 layers

- **What I see in the RCA**: Headings present are L1, L2, L3, L5, L7, L8, L9,
  L10, L11/L12 (combined). **L4 — Application code flow** and **L6 — The
  pipeline and how it actually runs** are missing entirely.
- **Why it is wrong / weak**: The project rule
  `.claude/rules/domain/on-call-incident-workflow.md` lists L1–L12 with exact
  heading strings and adds *"If `/rca-holistic` skill is invoked, its headings
  supersede this table — the skill is the single source of truth for heading
  text."* The RCA does not invoke the skill in this session and does not
  document an explicit "L4 not applicable because …" justification. A
  zero-context reader looking for the application code flow or the IaC pipeline
  gets nothing. The RCA's own L8 note about delegating to `oc-playbook.md`
  partially substitutes for L11, but L4 (code path through the cluster) and L6
  (IaC pipeline behavior, e.g., would a future Terraform apply have caught this
  if the rule had been imported) are not addressed.
- **Falsifier**: Read the rule file; the table requires all twelve layers. Any
  layer omitted without an in-document *"N/A because X"* note is a schema
  breach.
- **Required patch**: Either add stub sections for L4 (explicit: *"L4 not
  load-bearing here because the failure is in Azure Monitor's rule definition,
  not in any application code path; the namespace `eneco-vpp-prd` is referenced
  in the ticket but is not the failure surface — see Plane 3 verification"*)
  and L6 (explicit: *"L6 — the IaC pipeline did not run for this resource
  because it has never been in IaC; relevance to RCA is that no pipeline gate
  could have caught the misconfiguration"*), OR add a single *"Layers L4 and L6
  intentionally omitted"* note near L3 with the justification.
- **Conditional**: if the RCA holds at `status: review` and is intended to be
  promoted to `status: complete` via the rca-holistic skill's external
  adversarial gate, this schema breach must be remediated before promotion;
  otherwise the holistic-RCA contract is silently broken.

### F3 [HIGH] — "Manually created in the Azure portal" is A2 inference labelled as A1 fact

- **What I see in the RCA**: TL;DR — *"The rule was manually created in the
  Azure portal by `eelke.hoffman@conclusion.nl` on 2024-01-24"*. Evidence
  Ledger E5 — *"Rule created 2024-01-24T16:12:31 UTC by
  `eelke.hoffman@conclusion.nl` (createdByType=User), never modified since"*
  labelled A1, citing `systemData` block of the alert rule JSON.
- **Why it is wrong / weak**: `createdByType=User` (azure-alert-rule-raw.json
  line 46) only tells you that an Azure AD User principal made the
  resource-write API call. It does not distinguish between (a) someone clicking
  through the portal, (b) someone running `az monitor scheduled-query create`
  from a workstation, (c) someone running `terraform apply` from a workstation
  using their own user credentials. A Terraform run from CI under a service
  principal would show `createdByType=Application` or similar; user-credential
  Terraform runs from a workstation show `User`. The local-fs sidecar
  (`local-fs-alert-hcl-search.md`) explicitly enumerates four hypotheses for
  the alert's origin — *"out-of-band directly in Azure Portal … remote Azure
  DevOps / GitHub repo not present in this local clone set … defined in a
  branch / commit that is not currently checked out … managed by a
  Microsoft-managed automation"* — and labels the "out-of-band" conclusion A2,
  not A1. The RCA collapses these four to one ("in the portal") in the TL;DR.
- **Falsifier**: Check the Azure activity log for the
  `Microsoft.Insights/scheduledQueryRules/write` operation against this
  resource ID at the creation timestamp — the activity-log entry's
  `httpRequest.clientRequestId`, `userAgent`, and `caller` fields will
  distinguish portal (`Microsoft_Azure_Monitoring`, `PortalRequestId`) from CLI
  (`Azure-CLI/2.x.y`) from Terraform (`Go-http-client/2.0` with hashicorp
  signatures). The activity-log-7d sidecar referenced in the RCA's Eneco
  Intake Artifacts section (`alert-rule-activity-log.json`) is not in my read
  set this turn, but the sidecar exists per the directory listing — it has
  exactly 3 bytes (likely empty array), meaning no activity-log entries for
  the rule in the past 7 days, which is consistent with "never modified" but
  does NOT speak to the 2024-01-24 creation.
- **Required patch**: Change TL;DR phrasing from *"manually created in the
  Azure portal by …"* to *"created via a User principal
  (`eelke.hoffman@conclusion.nl`) — A1 from systemData; whether the User used
  the Azure portal, Azure CLI, or workstation Terraform is A3
  UNVERIFIED[blocked: activity-log creation entry would be >30d outside our
  retention probe; resolving via az graph or the rule's tags is moot because
  tags={} per E6]."* The "out-of-IaC" framing remains intact (the rule isn't
  in the local repo regardless of creation tool), but the "in the portal"
  framing is unsupported.
- **Conditional**: if the activity-log probe (future) reveals the rule was
  created via Terraform from a workstation, Lesson 1 ("out-of-IaC alerts
  decay silently") still holds (no PR review surface), but Lesson 1's *probe*
  recommendation — looking for non-`_terraform` createdBy strings — fails to
  catch this class of misconfiguration. The probe must be widened to
  *"alerts whose names do not match any IaC-generated naming pattern in the
  repo's monitor_metric_query_alert.tf"* rather than relying on createdBy
  string heuristics.

### F4 [HIGH] — "No Eneco workload affected" silently dismisses a PRD Rootly alert in-window

- **What I see in the RCA**: TL;DR — *"No Eneco workload was actually
  unhealthy."* Limitation 3 — *"the conclusion 'Eneco workload was not
  affected' is currently A2 INFER backed only by the absence of in-window
  cluster alarms in Rootly. Plane 3 of L8 + `oc-playbook.md` is the explicit
  falsifier."*
- **Why it is wrong / weak**: There IS an in-window Rootly alarm on a PRD
  surface — `oTiT7t` at 13:58:18 UTC,
  `KubernetesDeploymentReplicasMismatch eneco-vpp-gurobi/gurobi-compute`,
  environment **PRD**, in the namespace family that the ticket actually names.
  The Rootly sidecar (`rootly-past-hour-cross-check.md` line 47) dismisses this
  as *"Fired 73 min after Microsoft mitigation; 31-second duration; transient
  cluster scheduling event."* That a-priori dismissal is reasonable but it is
  not made visible in the RCA itself — the RCA's TL;DR reads as if NO PRD
  signal existed in window. A next-shift reader who challenges the close-only
  routing will not know about `oTiT7t` from reading the RCA. The RCA also does
  not explain why a 31-second `gurobi-compute` replica mismatch in PRD
  one hour after a Microsoft Log Analytics latency incident is unrelated —
  particularly given that gurobi-compute is the optimization workload tied to
  L1's business framing ("imbalance charges", "regulator-visible non-delivery").
- **Falsifier**: Run the Plane-3 `oc` probe for `eneco-vpp-gurobi` namespace at
  13:58 UTC ± 2 min: pod restart count, last termination reason, scheduling
  events. If a real CrashLoopBackOff or OOMKill landed in PRD even briefly, the
  "no workload affected" claim collapses. Separately, check whether the
  31-second duration is a pod that recovered on its own or one that the
  alertmanager autocleared because the metric went stale (the latter is
  consistent with cluster degradation hidden by metrics ingestion lag).
- **Required patch**: In Limitation 3, name `oTiT7t` explicitly: *"One Rootly
  PRD alert fired in the broader window — `oTiT7t` at 13:58:18 UTC on
  `eneco-vpp-gurobi/gurobi-compute`, 31-second duration. The Rootly cross-check
  sidecar classifies it as 'transient cluster scheduling event'; this RCA
  inherits that classification. If Plane 3 verification surfaces any
  gurobi-compute restart or OOMKill at 13:58 UTC, the 'no workload affected'
  framing must be revisited."*
- **Conditional**: if Plane 3 finds gurobi-compute did restart at 13:58 UTC,
  the close-only routing remains operationally correct for the ServiceNow
  ticket and Azure alert state, but a SEPARATE workload investigation must be
  opened. The current RCA's framing — single fire, single mechanism, no
  workload involvement — would no longer hold and the lessons would need to
  reflect that a Microsoft platform latency incident produces real downstream
  symptoms in our optimization workloads.

### F5 [HIGH] — Lesson 3 conflates severity and autoMitigate into one trap

- **What I see in the RCA**: Lesson 3 — *"Sev-0 and `autoMitigate=false` is
  an irreversible commitment … A sev-0 alert with `autoMitigate=false` will
  page on every fire and will require manual close."*
- **Why it is wrong / weak**: The asymmetry the lesson identifies
  (auto-fire + manual-resolve) is a property of `autoMitigate=false`
  REGARDLESS of severity. A sev-3 alert with `autoMitigate=false` also fires
  automatically and requires manual close — but it does not page, so it is
  noise inventory rather than oncall noise. The severity axis is what makes
  THIS incident a page; the autoMitigate axis is what makes THIS incident
  a permanent fire entry. They are orthogonal. Rephrase test: strip the
  incident-specific nouns and Lesson 3 becomes *"a severity-0 alert with
  manual-mitigate is an irreversible commitment"* — but that is just true by
  definition of sev-0 + manual-mitigate. The durable pattern is *"any alert
  with `autoMitigate=false` accumulates fired-state entries in the Alerts
  blade and must be paired with a documented close protocol, regardless of
  severity; severity merely controls whether the noise reaches the on-call"*.
  As currently written, Lesson 3 would fail to flag a sev-3 +
  autoMitigate=false alert that floods the Alerts blade — that's the same
  trap, but the lesson's probe (`severity == 0 && autoMitigate == false`)
  silently excludes it.
- **Falsifier**: Apply the lesson's probe to the Eneco prod scope. If it
  returns zero hits but the Alerts blade has dozens of permanently-fired
  non-sev-0 entries, the lesson's probe misses the larger pattern.
- **Required patch**: Split Lesson 3 into two lessons OR rewrite as:
  *"`autoMitigate=false` is the irreversible commitment — every fire
  becomes a permanent Alerts-blade entry until manually closed. Severity
  decides whether the noise reaches on-call; severity-0 with
  autoMitigate=false concentrates that noise. Probe: `severity == 0 &&
  autoMitigate == false` for on-call noise; `autoMitigate == false` alone
  for Alerts-blade inventory."* This preserves the original sev-0 concern
  AND surfaces the orthogonal lesson the current text hides.
- **Conditional**: if a future audit using the lesson's current probe
  returns *"no sev-0 alerts with autoMitigate=false found, no action
  needed"*, the lesson has provided false reassurance — the broader
  autoMitigate=false trap remains.

### F6 [HIGH] — CMC term defined from directory slug, not from the cited ticket payload

- **What I see in the RCA**: Context Ledger row for **CMC** — *"Shorthand the
  on-call used in the directory name. From the ticket payload it is the
  ServiceNow CI class — `Reported CI: Azure Cluster | namespace
  eneco-vpp-prd`. Treat as ServiceNow CI nomenclature, not an Eneco-specific
  platform feature."*
- **Why it is wrong / weak**: The ticket payload says *"Reported CI: **Azure
  Cluster** | namespace eneco-vpp-prd"* — the CI class is literally *"Azure
  Cluster"*, NOT *"CMC"*. The string *"CMC"* appears nowhere in the ticket
  file I read (`cmc-service-now-ticket.txt`). The Context Ledger's entry reads
  as if it sourced the CMC label from the ticket, but it actually inherits it
  from the directory slug
  (`2026_05_11_cmc_alert_vpp_cluster_prod`) the on-call chose. A zero-context
  reader who runs the reader-test will look in the ticket for *"CMC"*, fail to
  find it, and lose confidence in the Context Ledger. This is the Context
  Ledger drifting from its source.
- **Falsifier**: `grep -i cmc cmc-service-now-ticket.txt` → no match. The CMC
  label is the on-call's shorthand, not the ticket's CI class.
- **Required patch**: Rewrite the CMC row as: *"'CMC' is the on-call's
  shorthand used in the directory name; it does NOT appear in the ServiceNow
  ticket payload, which uses CI class 'Azure Cluster'. The shorthand is
  derived from the user-visible ticket category in the ServiceNow UI (not
  exported to the .txt file). Treat 'CMC' as a directory-naming convention,
  not a ServiceNow CMDB term provable from this RCA's evidence."* Or, if the
  on-call knows the CMC label IS the ServiceNow UI category, cite the URL or
  screenshot path.
- **Conditional**: if the on-call confirms the ServiceNow UI shows category
  *"CMC alert"* even though the .txt export does not, that's a citation we
  should add — and a future export-tool fix to capture it.

### F7 [HIGH] — Microsoft communication payload has two disagreeing time fields; RCA picks one without flagging

- **What I see in the RCA**: L7 Timeline rows — *"2026-05-11 06:40 UTC —
  Microsoft platform incident `5Z1B-6KG` impact starts"*, *"12:45 UTC —
  Microsoft declares Mitigated"*. Cites E8.
- **Why it is wrong / weak**: The cited payload
  (`workspace-servicehealth-firetime.json` Properties JSON) contains BOTH
  textual times in the `communication` HTML — *"Between 06:40 UTC and 12:45
  UTC on 11 May 2026"* — AND structured times in dedicated fields:
  `impactStartTime: "5/11/2026 11:11:09 AM"` and
  `impactMitigationTime: "5/11/2026 12:55:01 PM"`. The two sets of times do
  not agree (06:40 vs 11:11; 12:45 vs 12:55). The RCA narrates the textual
  times in L7 without flagging the structured-field disagreement. A
  reader-test consumer who clicks through to the payload will see the
  inconsistency and not know which to trust.
- **Falsifier**: Both fields exist in the payload at the same row level
  (`Properties.communication` string vs `Properties.impactStartTime` /
  `Properties.impactMitigationTime`). The disagreement is observable from the
  sidecar alone — no new probe needed.
- **Required patch**: Add a footnote to L7: *"The Properties payload contains
  two sets of times — textual (in the HTML `communication` field: 06:40 UTC
  start, 12:45 UTC mitigation) and structured (`impactStartTime` 11:11:09 UTC,
  `impactMitigationTime` 12:55:01 UTC). The 06:40–12:45 window is the
  customer-impact window per Microsoft's own narrative; the 11:11–12:55
  structured times are likely the detection-to-mitigation window from
  Microsoft's monitoring view (consistent with the 08:57 detection but not
  with the 06:40 impact-start). This RCA uses the textual customer-impact
  window because it is the conservative bound for 'when did latency affect
  our workspace'. A1 — both observable in the payload."*
- **Conditional**: if Microsoft's PIR (when published) reconciles the times,
  update the RCA. Until then, the L7 timeline must visibly acknowledge the
  payload-internal disagreement.

### F8 [HIGH] — Same fact labeled A2 in one place and A3 in another

- **What I see in the RCA**: L5 "Three Truths" table row — *"Wider Eneco
  source tree (local mirror snapshot, A3 freshness): No file anywhere in the
  local Eneco-src checkout references this alert name."* Evidence Ledger
  E12 — *"The alert is not defined anywhere in the local Eneco source tree"*
  labelled A2. E13 — local mirror fixed at commit 8d7d890 due to SSH fetch
  denied — labelled A1. E17 — local main up-to-date with last-known origin/main
  but origin freshness A3 UNVERIFIED[blocked] — labelled A1/A3 mixed.
- **Why it is wrong / weak**: The "no file in the local tree references this
  alert name" claim is a literal `grep` exit code — that is A1 (the
  observation is "rg returned zero matches"). The A2 interpretation is "the
  alert is not defined in IaC", which depends on the additional assumption
  that the local tree is the complete IaC surface (which Limitation 2 and
  E17 explicitly say is A3-blocked). So the fact has three valid labels in
  three frames: *"grep returned zero matches"* = A1, *"alert is not in this
  local tree"* = A1 (trivially follows), *"alert is not in IaC anywhere"* =
  A2 conditional on A3 origin-freshness. The RCA picks A3 in the L5 table,
  A2 in E12, and A1/A3 in E17 — three labels for variations of the same
  underlying claim. That makes the evidence ledger internally inconsistent.
- **Falsifier**: Read all three sections side-by-side and confirm the label
  drift.
- **Required patch**: Pick one canonical phrasing of the claim and one label.
  Recommended: *"Local-mirror-grep result is A1 (rg zero-match,
  command-output-witnessed); 'alert is absent from local IaC' is A1 (trivial
  from the grep); 'alert is absent from authoritative IaC' is A2 conditional
  on E13/E17 A3 origin freshness."* Use that triad consistently in E11, E12,
  E17, and the L5 table.
- **Conditional**: if origin freshness is later confirmed (eneco-context-repos
  probe lands), the A3 collapses and "alert is not in IaC anywhere" becomes A1.

### F9 [MEDIUM] — E16 "shared platform Kusto/LA" reasoning is training-derived

- **What I see in the RCA**: E16 — *"Two Rootly alerts in the same window —
  `mcdta-vpp-IngestionLatency-KustoDynamic-d` (DEV, 13:12 and 13:42 UTC) —
  are likely related to the same Microsoft incident `5Z1B-6KG` via shared
  West Europe ingestion path"*, labeled A2, with reasoning *"Time correlation
  + shared platform (Kusto/ADX shares storage with Log Analytics)"* and a
  falsifier *"pull the Kusto alert rule and check whether its KQL/metric
  reads from the LA-affected path."*
- **Why it is wrong / weak**: The reasoning *"Kusto/ADX shares storage with
  Log Analytics"* is a TRAINING-DERIVED claim — it is broadly true that Log
  Analytics is built on top of ADX (Azure Data Explorer), but the
  ingestion-path coupling at a tenant level depends on cluster topology
  (shared dedicated ADX cluster vs LA's managed engine) and is not directly
  observable from the Rootly sidecar. The falsifier the sidecar names was
  not executed in scope. The RCA imports E16 as A2 without flagging that
  the underlying architectural premise is training-derived, not source-traced.
  The Rootly sidecar itself is more careful — it labels these "likely related"
  and explicitly admits *"causal attribution of Rootly alerts to Microsoft
  incident — based on time correlation + path-through-shared-infra reasoning;
  not proven by backplane traces"*.
- **Falsifier**: Pull the `mcdta-vpp-IngestionLatency-KustoDynamic-d` alert
  rule definition (KQL or metric criteria) and trace its data path. If it
  reads from a dedicated ADX cluster whose ingestion path does NOT pass
  through the affected West Europe Log Analytics service guid
  (`8573e08a-c216-46d6-9396-bb124ec1c385`), the relation is wrong.
- **Required patch**: Add to E16: *"Architectural premise (Kusto/ADX shares
  storage path with Log Analytics) is training-derived for this RCA; the
  Rootly sidecar's falsifier (pull the Kusto alert rule and check the
  ingestion path) was not executed in this scope. Relation is best read as
  'time-correlated and platform-plausible' not 'mechanism-proven'."*
- **Conditional**: if the Kusto alert rule reads from a path independent of
  the affected Log Analytics service guid, E16's relation hypothesis is
  falsified; this does not change the primary RCA conclusion but it does
  weaken the "Microsoft incident produced multiple Eneco-side symptoms"
  narrative.

### F10 [MEDIUM] — ServiceNow ITSM-connector path is A2 in Limitation 4 but L7 narrates it as causal

- **What I see in the RCA**: L7 timeline row — *"~2026-05-11 13:13:50 UTC —
  ServiceNow connector polls Alerts Management, picks up the new sev-0 alert,
  creates the CMC ticket against the Eneco MCC – Production – Workload VPP
  host with namespace eneco-vpp-prd"*. Limitation 4 — *"Path of the
  ServiceNow ticket … is A2 INFER … the most likely path is the
  subscription-level Azure → ServiceNow ITSM connector that polls Alerts
  Management."*
- **Why it is wrong / weak**: L7 narrates the connector path as if proven;
  Limitation 4 admits it is A2. The L7 row says *"connector polls Alerts
  Management"* without flagging that this polling-vs-push, subscription-vs-RG,
  ITSM-connector-vs-EventGrid-vs-LogicApp distinction is not actually proven
  by anything we have in scope. The ticket text itself (cmc-service-now-ticket.txt)
  contains `AlertType: Microsoft.Insights/scheduledQueryRules` and a Workspace
  Logs URL — this is consistent with the ITSM-connector path but also with at
  least three other paths (EventGrid + LogicApp; native ServiceNow Azure
  integration plugin; an Azure Monitor → SNow webhook bound at a different
  scope). Limitation 4 correctly flags this; L7 reads as if the connector is
  the known mechanism.
- **Falsifier**: Look at the ServiceNow side: the inbound payload's source
  URL or x-azure-* headers identify the path. Or look at the Azure side: enumerate
  configured Logic Apps / ServiceNow integrations on the subscription and
  resource group. Neither was done in scope.
- **Required patch**: Soften L7's row to *"~13:13:50 UTC — ServiceNow ticket
  created (A2: connector or other Azure → ServiceNow integration path
  produced the ticket; the specific path is A3 UNVERIFIED[blocked: ServiceNow
  inbound provenance + Azure-side integration inventory not probed in
  scope], see Limitation 4)."*
- **Conditional**: if the actual path is NOT the subscription-level ITSM
  connector but something else (e.g., a Logic App with its own retry
  semantics), the "future fires create new tickets" claim in L8 Plane 2 may
  need adjusting — some paths dedupe, others don't.

### F11 [MEDIUM] — "Microsoft event triggered this fire" is temporal correlation, not ID-matched causation

- **What I see in the RCA**: TL;DR — *"The fire was triggered by Microsoft
  Azure publishing the 'Mitigated' communication for platform incident
  `5Z1B-6KG`."* Multiple downstream sections re-assert *"Microsoft's own
  resolution notice triggered the fire"*.
- **Why it is wrong / weak**: The mechanism *"event ingested at 13:10:36 →
  rule evaluated at 13:12:43 → fired"* is temporal correlation. There is no
  ID-match in scope linking the alert's `sourceCreatedId`
  (`22ed515b-24d3-26ce-3fb3-09cfc5158afb`, per sev0-alerts-24h.json) to the
  workspace row's `CorrelationId`
  (`05f54640-f10b-4383-9d60-48f4f83dbf17`) or `EventDataId`
  (`662512f2-724e-4459-b207-48e2cd5d28ce`). Azure scheduled-query-rules don't
  expose the matched rows in the alert metadata; the link is "the alert fired
  at a time consistent with the row landing in the workspace 2 minutes
  earlier." That's strong evidence — and combined with F1's count>1 question,
  it's actually the same question: WHICH rows did the rule see when it
  fired? The TL;DR's directness ("the fire was triggered by") overstates
  what we can prove.
- **Falsifier**: Re-run the rule's KQL against the workspace using the
  rule-evaluation API (`az monitor scheduled-query test`-style) for the
  13:07:43–13:12:43 window and inspect the returned rows. Or, more
  feasibly, the Azure alert payload itself sometimes includes the
  triggering KQL projection in `Properties.searchResults`; check the
  full alert essentials including extended properties (sev0-alerts-24h.json
  only shows the essentials block; full alert detail was not pulled).
- **Required patch**: Adjust TL;DR phrasing from *"The fire was triggered
  by Microsoft Azure publishing the 'Mitigated' communication"* to *"The
  fire is temporally consistent with the 'Mitigated' communication
  ingested at 13:10:36 UTC (alert-time 2m 7s later, within the rule's
  5-min window). Direct row-to-alert ID matching is A3 UNVERIFIED[blocked:
  scheduled-query-rule alerts do not expose matched rows; full alert
  payload not pulled this session]."*
- **Conditional**: combined with F1's count>1 question, if the second
  triggering row is a redelivery of the same EventDataId (Lane 7), then
  "Microsoft event triggered the fire" remains true but reads differently
  — one Microsoft communication produced TWO row insertions, satisfying the
  >1 threshold from a single notice. That makes the rule even more
  pathological (one notice → one fire is bad; one notice → one fire via
  internal redelivery is *embarrassingly* over-broad).

### F12 [LOW] — `lastModifiedAt == createdAt` is a useful additional fact for "never modified"

- **What I see in the RCA**: E5 — *"Rule created 2024-01-24T16:12:31 UTC …
  never modified since"*.
- **Why it is wrong / weak**: Not wrong, but the supporting evidence is
  slightly understated. The systemData block contains both `createdAt`
  (`2024-01-24T16:12:31.862162+00:00`) AND `lastModifiedAt`
  (`2024-01-24T16:12:31.862162+00:00`) — they are identical to the
  microsecond. The "never modified" claim is supported A1 by this equality,
  not just by the activity-log-7d returning empty. The 7-day activity log
  only proves "not modified in the past 7 days"; the systemData equality
  proves "not modified since creation 15 months ago."
- **Falsifier**: Look at sidecar `azure-alert-rule-raw.json` lines 44 and 47;
  the timestamps are byte-identical.
- **Required patch**: In E5, add a clause: *"createdAt == lastModifiedAt
  (identical to the microsecond per `azure-alert-rule-raw.json:44,47`),
  which is the A1 proof of 'never modified', stronger than the 7-day
  activity-log-empty observation."*
- **Conditional**: if a future activity-log probe reveals a write entry
  between createAt and now, then either Azure's systemData has a bug or
  someone re-wrote the resource with identical content (which would not
  update lastModifiedAt — but in practice always does, even on no-op puts).
  Either way, currently the equality is the strongest evidence available.

## Strongest counter-case (Lane 7)

If I suspend the orphan-portal-alert framing, the strongest counter-explanation
for today's fire is **"single Microsoft communication, double-ingested into
the workspace during the latency-recovery backlog drain, producing count=2
from one notice."**

The mechanism:

1. Microsoft incident `5Z1B-6KG` ran 06:40–12:45 UTC. The incident is itself
   "Log Analytics and Application Insights intermittent data latency" — the
   exact service whose ingestion path our workspace sits on. The communication
   text explicitly warned *"Impacted customers ... may have experienced ...
   incorrect alert activation for workspaces hosted in the region."*
2. During the 6-hour incident, Microsoft's own publication of ServiceHealth
   communications was subject to the same backlog as customer telemetry. By
   13:10 UTC (25 minutes after Microsoft declared Mitigated), the backlog was
   draining.
3. AzureActivity ingestion delivers ServiceHealth rows to the workspace via a
   pipeline that, under backlog drain, can deliver the same emission twice if
   the upstream publisher retried during the backlog and the dedupe
   downstream is not row-perfect. The workspace's row schema includes both
   `CorrelationId` and `EventDataId` — only the latter is row-unique. A
   redelivery would land as a new row with the same CorrelationId but a new
   EventDataId.
4. The single visible row in `workspace-servicehealth-firetime.json` is the
   ONE row I can see in the 15-min window I have evidence for. If a second
   row landed inside the 5-min firing window (13:07:43–13:12:43) — whether a
   duplicate of the Mitigated notice or an earlier same-incident
   communication that was delayed by the backlog — that's the count>1
   trigger. The RCA does not probe this.

This counter-case is MORE consistent with the evidence than the RCA's
narrative for two reasons:

- **Mechanism-completeness**: it explains how a single visible Mitigated row
  could satisfy a `count > 1` rule. The RCA's narrative implicitly requires a
  second row that the RCA does not cite.
- **Self-consistency with the Microsoft notice**: Microsoft itself warned of
  "incorrect alert activation" caused by the latency. If our alert was
  activated by Microsoft's own backlog drain double-delivery, that is
  literally the warned-of pathology.

If this counter-case is correct, the RCA's primary conclusion ("alert is
structurally over-broad, fired on the platform-resolution notice") survives —
the rule IS over-broad and IS sev-0 and IS unrouted. But the framing changes
from *"one Microsoft event over-broadly matched"* to *"one Microsoft event,
delivered twice during backlog drain, doubly-matched"* — and Lesson 2 sharpens:
*"`CategoryValue == 'ServiceHealth'` with a `Count > 1` threshold is doubly
broken — it fires on Microsoft announcements AND it fires on AzureActivity
redelivery, which is a routine occurrence during ingestion-backlog drain"*.

The lever that selects between the RCA's framing and this counter-case is F1's
falsifier (the 5-min-window KQL count). One probe resolves both questions.

## Meta-falsifier (Rule 11)

This review could be wrong in the following named ways:

1. **The second row may exist and the RCA simply did not cite the right
   sidecar.** I read `workspace-servicehealth-firetime.json` (the one the
   coordinator named) and found one row in a 15-min window. If the on-call
   actually ran a wider KQL and saw two rows but only included the most
   recent in the sidecar, F1 is wrong. Falsifier: ask the on-call.
2. **L4 and L6 may be intentionally omitted per a skill-level convention I
   missed.** The rca-holistic skill claims to be "the single source of truth
   for heading text." If the skill explicitly permits layer omission for
   "alert noise" RCAs, F2 is wrong. Falsifier: read the rca-holistic skill
   definition.
3. **"Manually in the portal" may be sourced from the on-call's separate
   conversation with `eelke.hoffman` or another out-of-band signal not in
   scope.** If so, F3 is correct as a labelling complaint but wrong as a
   substantive complaint.
4. **`oTiT7t` (gurobi-compute) may have been investigated in a sidecar not
   shown to me.** If a Plane-3 probe already happened and showed no real
   workload impact, F4's complaint is mooted by the existence of the probe.
5. **The Microsoft payload time disagreement (F7) may be Microsoft's own
   convention (textual = customer-impact window, structured = internal
   monitoring window) and not actually a disagreement worth flagging.** If
   that's the case, F7 reduces from HIGH to LOW.

If a future probe of F1's falsifier returns count ≥ 2 with two distinct
EventDataIds in the 5-min window, the RCA's mechanism narrative is vindicated
and Lane 7's counter-case is wrong; the RCA needs only F2 (missing layers),
F3 (labelling), F4 (dismissed Rootly alert visibility), F5 (Lesson 3 conflation),
F6 (CMC citation), and F8 (label inconsistency) addressed. If count = 1, the
RCA needs structural mechanism revision per F1 and Lane 7.

## What would change the RCA verdict from PROCEED-WITH-CHANGES to REJECT

- F1's falsifier returning count = 1 AND no alternative mechanism surfaced
- F4's falsifier finding a real PRD gurobi-compute restart at 13:58 UTC AND
  the RCA's TL;DR being unchanged from "no Eneco workload was actually
  unhealthy"
- Either of those alone would not flip to REJECT (the close-only routing is
  still operationally correct), but the RCA's narrative would need
  substantial revision before promotion to `status: complete`.

## Summary table of required patches by section

| RCA section | Required patch | Finding |
|---|---|---|
| TL;DR | Soften "manually created in the Azure portal" and "triggered by Microsoft"; flag count>1 mechanism as A3-blocked | F1, F3, F11 |
| TL;DR | Add visibility for the in-window PRD Rootly alert dismissal | F4 |
| Context Ledger — CMC row | Rewrite as "directory-naming convention, not provable from ticket .txt export" | F6 |
| Evidence Ledger E5 | Add createdAt == lastModifiedAt fact | F12 |
| Evidence Ledger E10 | Demote A2 to A3 UNVERIFIED[blocked]; restate honest reasoning | F1 |
| Evidence Ledger E11/E12/E17 + L5 table | Use single canonical labelling for the local-tree absence | F8 |
| Evidence Ledger E16 | Flag "shared platform" premise as training-derived | F9 |
| L4 + L6 | Add stubs OR explicit "intentionally omitted" note | F2 |
| L7 Timeline | Add footnote on payload time disagreement; soften ServiceNow connector row | F7, F10 |
| L9 Verification | Add the 5-min-window KQL count probe | F1 |
| L10 Lesson 3 | Split into autoMitigate axis + severity axis OR rewrite as combined | F5 |
| Limitation 3 | Name `oTiT7t` explicitly | F4 |
