---
task_id: 2026-05-11-005
slug: cmc-alert-vpp-cluster-prod
agent: el-demoledor
timestamp: 2026-05-11T16:25:00+00:00
status: complete
adversarial_role: el-demoledor
target_artifact: log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/rca.md
summary: |
  Demolition attack on the rca.md for the 2026-05-11 CMC vpp-resource-unhealthy fire.
  Two BLOCKING findings (F1 count-arithmetic uses a window that the only on-disk evidence
  contradicts; F3 "no Eneco workload affected" is currently unfalsified — cluster-side probe
  is delegated to a file that does not exist). Three HIGH (F2 ITSM connector path is
  asserted without eliminating alternatives; F4 portal-edit history is not probed; F8 the
  RCA cites its own coordinator-produced sidecars as A1). Four MEDIUM/LOW. Verdict:
  PROCEED-WITH-CHANGES — fix-and-ship; do NOT promote to status: complete until F1, F3
  patched and F2 alternatives are enumerated.
---

# El-Demoledor Attack on `rca.md`

## Verdict

**PROCEED-WITH-CHANGES** — fix-and-ship after BLOCKING/HIGH findings are absorbed.
Do NOT promote `status: complete` until F1 (E10 arithmetic) and F3 (cluster-side falsifier) are patched and F2 (ITSM connector path) lists eliminated/uneliminated alternatives.

## Findings (numbered, severity-tagged)

### F1 [BLOCKING] — E10 count-arithmetic contradicts the on-disk sidecar; the rule did NOT see ≥2 ServiceHealth rows in the 5-min window

- **Quote / section ref**: `rca.md:97` (Evidence Ledger E10), reinforced at `rca.md:209` (timeline "rolling 5-min window, sees `count > 1`").
- **Quote of the claim**: *"Within the 5-minute evaluation window at 13:12:43 UTC there were ≥2 AzureActivity ServiceHealth rows visible to the workspace (count > 1 satisfied) ... Inferred from E7 + E8: the workspace 12:00-13:00 UTC hour had 2 ServiceHealth events; the rule evaluates the rolling 5-min window and the rule's threshold is `Count > 1`."*
- **Break**:
  1. The rule's `windowSize = 0:05:00` (`azure-alert-rule-raw.json:56`). At `lastModifiedDateTime = 2026-05-11T13:12:43.279Z` (`alert-fires-30d.json:14`), the rolling window covers **13:07:43.279 → 13:12:43.279 UTC**.
  2. The on-disk sidecar `workspace-servicehealth-firetime.json` queried **13:00-13:15 UTC** (a 15-min window that fully contains the rule's 5-min window) and returned **exactly 1 row**: `TimeGenerated = 2026-05-11T13:10:36.3600226Z`, `ActivityStatusValue=Resolved`, trackingId `5Z1B-6KG`.
  3. Therefore at evaluation, the 5-min window contained **1** ServiceHealth row, not ≥2. `Count > 1` evaluates `1 > 1 = false`. The rule mechanism described in E10 + the L7 timeline row **cannot have fired the alert as described**.
  4. The RCA conflates "the 12:00-13:00 hour had 2 events" (which is from a histogram statement, not the sidecar at hand) with "the 5-min rolling window had ≥2." Hour-level density does not imply 5-min-window density.
  5. Compounding error: `criteria.allOf[0].timeAggregation = "Count"` with `resourceIdColumn = "_ResourceId"` means the count is computed per-`_ResourceId` partition (per-resource bucket), not globally. If the single returned row has a populated `_ResourceId` and any older row exists in the workspace with the **same** `_ResourceId`, the per-resource count could still be ≥2 even with one row in the 5-min summary — but **no probe in the sidecars proves this either way**. The RCA does not even mention partitioning by `_ResourceId`.
  6. Alternative semantics that the RCA does not address: `failingPeriods.minFailingPeriodsToAlert=1, numberOfEvaluationPeriods=1` means a SINGLE failing 5-min period triggers; combined with `threshold > 1` aggregated as `Count`, the rule does not have any path to fire with one row visible in the window. Either the row count is wrong (probe was too narrow / mis-grouped) or the mechanism is wrong (e.g., the rule receives `_ResourceId`-partitioned rows and a hidden second row exists at a different `_ResourceId`).
- **Falsifier OR proof**: Re-run the KQL bounded to the exact 5-min window AND projecting `_ResourceId`:
  ```kql
  AzureActivity
  | where TimeGenerated between (datetime(2026-05-11T13:07:43.279Z) .. datetime(2026-05-11T13:12:43.279Z))
  | where CategoryValue == "ServiceHealth"
  | summarize cnt = count() by _ResourceId
  | order by cnt desc
  ```
  Expected, if the RCA's mechanism holds, ≥2 in at least one `_ResourceId` bucket. If it returns one row with cnt=1 (or zero rows), E10 is falsified and the actual trigger mechanism is unknown.
- **Required patch**:
  1. Downgrade E10 from A2 to **A3 UNVERIFIED[blocked: 5-min window + `_ResourceId` partition not probed in this session]**.
  2. Remove the "saw `count > 1` for `CategoryValue == 'ServiceHealth'`" assertion from the L7 timeline row at 13:12:43; replace with: "the rule's criteria became satisfied; the exact count path is A3 pending the 13:07:43-13:12:43 + `_ResourceId`-partitioned probe."
  3. Add the falsifier KQL above into the Verification table (L9) as a **mandatory pre-close probe**, not optional.
  4. State explicitly in L8/L9 that if the falsifier returns zero or one row per `_ResourceId`, the RCA mechanism is wrong and the close-only decision must be re-evaluated — there may be a different mechanism (Smart Detection, a different rule, a delayed-ingestion second row) that the team is not seeing.
- **Conditional belief-change**: If the falsifier KQL returns ≥2 rows in some `_ResourceId` bucket → E10 promotes back to A2 and the RCA mechanism is correct as-stated. If it returns one or zero → the RCA's "this is a simple over-broad KQL firing on a single Microsoft mitigation notice" story is wrong, the cause is currently UNKNOWN, and the parent coordinator must escalate before closing.

---

### F2 [HIGH] — "ServiceNow via ITSM connector" asserted as the path, but at least 3 alternatives are uneliminated and zero probes exist

- **Quote / section ref**: `rca.md:316` (Limitations #4) and `rca.md:177-180` (L3 box) and `rca.md:79` (Context Ledger row "ServiceNow (intake channel)").
- **Quote of the claim** (Limitations admits A2 but the rest of the document treats it as established): *"this RCA assumes the connector path on the basis of `actions: null` plus the existence of the ticket."*
- **Break**:
  1. The RCA's reasoning is `actions:null` ∧ ticket exists ⟹ ITSM connector. This is the affirming-the-consequent fallacy on the form (ticket arrives by SOMETHING; let X be ITSM; therefore X). It does not eliminate:
     - **A-alt1**: A subscription-level **Azure Monitor Alert Processing Rule** that overrides per-alert routing and adds an action group/webhook independently of the rule's `actions:null`. Probe: `az monitor alert-processing-rule list -g mcprd-rg-vpp-p-res` and at subscription scope.
     - **A-alt2**: A **Logic App** polling `Microsoft.AlertsManagement/alerts` and POSTing to ServiceNow. Probe: `az logicapp list --subscription f007df01-...` filtered by trigger type and destination.
     - **A-alt3**: A **subscription-level diagnostic setting** that ships AlertsManagement events to an Event Hub which a ServiceNow integration consumes. Probe: `az monitor diagnostic-settings subscription list`.
     - **A-alt4**: A direct **Azure → ServiceNow native integration** at the ServiceNow MID server side (pull, not push); the Azure subscription has no record of this, so the local probe would show nothing — only the ServiceNow side would.
  2. The Slack intake says `Tags: action OC: nullclass: softwarecomponent: azure_alert` and `Trigger: Azure - AlertName: vpp-resource-unhealthy` (`cmc-service-now-ticket.txt:27, 12`). `action OC: null` is suggestive but the source ServiceNow CI integration ID is not exported. The "ITSM connector" assumption is not in any sidecar.
  3. This matters for the L8 fix: Plane 2 says "Closing the upstream Azure alert is the trigger ServiceNow expects in order to flip the ticket." That is **only true if** the path is bidirectional ITSM connector. If the path is, say, Logic App push-only (no ack/close webhook back to ServiceNow), then closing the Azure alert does NOTHING to the ServiceNow ticket and the on-call will be left with an open page.
  4. The 15-min auto-propagation expectation (`rca.md:231`) is fabricated — no sidecar substantiates either the 15-min number or the bidirectional behavior.
- **Falsifier OR proof**:
  ```bash
  az monitor alert-processing-rule list --resource-group mcprd-rg-vpp-p-res -o json > apr-rg.json
  az monitor alert-processing-rule list --subscription f007df01-9295-491c-b0e9-e3981f2df0b0 -o json > apr-sub.json
  az logicapp list --subscription f007df01-9295-491c-b0e9-e3981f2df0b0 -o json | jq '.[] | select(.kind|contains("workflowapp"))'
  az monitor diagnostic-settings subscription list --subscription f007df01-9295-491c-b0e9-e3981f2df0b0
  ```
  And on the ServiceNow side: open the CMC ticket "related items" → trace what integration record created it.
- **Required patch**:
  1. Move Limitations #4 (the ITSM-connector A2) into the **Evidence Ledger as a new E18 with status A3 UNVERIFIED[blocked: integration source not probed]**. List the four alternatives above explicitly.
  2. In L8 Plane 2, replace "Closing the Azure alert is the trigger ServiceNow expects" with: *"If the ServiceNow→Azure path is bidirectional ITSM, closing the Azure alert closes the ticket within ~15 min (UNVERIFIED). If not, the on-call must close the ticket manually in ServiceNow."* Add a step: **always close both planes, do not assume propagation**.
  3. In L9 add a verification step: "Within 15 min of Azure alert close, did the ticket transition? If no, the path is not bidirectional ITSM — close the ticket manually and add this finding to the lessons-learned."
- **Conditional belief-change**: If the four probes are run and the connector path is identified → E18 promotes to A1 and the Plane-2 procedure tightens. If the probes are blocked / not run → the close-only fix carries explicit "close ticket manually" as a defensive default, not an "if-then" fallback.

---

### F3 [BLOCKING] — "No Eneco workload affected" is asserted in TL;DR and L8 but the falsifier file does not exist

- **Quote / section ref**: `rca.md:19` TL;DR (*"No Eneco workload was actually unhealthy"*); `rca.md:242` (Plane 3 falsifier delegates to `oc-playbook.md`); `rca.md:248` (claims `oc-playbook.md` is "forthcoming in this directory"); `rca.md:307-308` (L11/L12 again delegates to `oc-playbook.md`).
- **Break**:
  1. **The file does not exist.** No `oc-playbook.md` is present in `log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/`. The RCA's only falsifier for its load-bearing conclusion is an unwritten document.
  2. The RCA's actual evidence for "no workload affected" is: (a) no in-window Rootly alert from PRD against this rule, and (b) the assertion that two cluster-side alerts are explainable away. Both are weak:
     - **`oTiT7t` KubernetesDeploymentReplicasMismatch on `eneco-vpp-gurobi/gurobi-compute` (PRD) at 13:58 UTC.** RCA dismisses as "31-second transient." There is no baseline given (does this fire every day?), no link to the underlying deployment to show whether it was a real replica gap, no cross-check against the previous day's alert volume. 73 min after Microsoft mitigation is well inside the trailing-effect window of a Log Analytics latency incident; backlogged metrics could mask a real degradation.
     - **`inbox-ingestion KubePodCrashLooping` (DEV) — recurring "throughout day."** Recurring ≠ unrelated. The RCA does not show the day-before baseline, the crash rate today vs yesterday, or whether the count went up during the Microsoft window.
  3. The cluster is `eneco-vpp-prd`. The RCA never queried it. No `oc get pods -n eneco-vpp-prd`, no `oc get events`, no operator status, no PVC status, no NodeNotReady check. The L1 framing says sev-0 on this stack = "Eneco is losing money right now." The RCA closes the ticket without ever looking at the surface that L1 says we exist to protect.
  4. The Verification Strategy at `rca.md:260` says: *"If any probe returns positive evidence of cluster degradation, **stop using this RCA's conclusion** — re-open as a real workload incident."* But that is conditioned on running the probes from a file that does not exist.
- **Falsifier OR proof**: Minimum bar — three `oc` probes against `eneco-vpp-prd` covering 13:00-13:20 UTC:
  ```bash
  oc get pods -n eneco-vpp-prd --field-selector=status.phase!=Running
  oc get events -n eneco-vpp-prd --sort-by='.lastTimestamp' | head -50
  oc get pods -n eneco-vpp-prd -o json | jq '.items[] | {name:.metadata.name, restarts:[.status.containerStatuses[]?.restartCount]|max}' | jq -s 'sort_by(.restarts)|reverse|.[0:10]'
  ```
  And a workspace cross-check for ResourceHealth events on the namespace's underlying Azure resources during 13:00-13:20 UTC.
- **Required patch**:
  1. **Downgrade the TL;DR claim from "No Eneco workload was actually unhealthy" to "No Eneco workload was OBSERVED unhealthy in this session; cluster-side falsifier in `oc-playbook.md` is mandatory pre-close."** This is the F3 conditional from the brief.
  2. **Author `oc-playbook.md` before promoting the RCA to `status: complete`**. The RCA is currently citing a phantom artifact as its load-bearing falsifier. That is a harness violation (`anti-slop-gate.md`: "commands paired with question, expected output, and decision rule" — the commands have to exist).
  3. Add E19 to the Evidence Ledger: *"`oTiT7t` (PRD, 13:58 UTC) dismissed as 31-second transient — A3 UNVERIFIED[blocked: no baseline, no deployment probe]."* And E20 for the `inbox-ingestion` baseline gap.
  4. In L9, change "no degraded operator / no recent CrashLoopBackOff in `eneco-vpp-prd`" from an Expected Output into a **required A1 probe with output captured**.
- **Conditional belief-change**: If `oc-playbook.md` exists and the probes pass clean → TL;DR claim can stand as "no impact observed via Rootly + cluster probes." If `oc-playbook.md` is not produced before close → the RCA must be marked `status: blocked` and the ticket must NOT be closed on the strength of this document alone.

---

### F4 [HIGH] — "Never modified since 2024-01-24" relies on `systemData`, but the RCA does not name what probe would catch a portal-only edit that ARM-modified-tracking misses

- **Quote / section ref**: `rca.md:92` (E5) and `rca.md:202` (timeline row "never modified") and Lesson 1 (`rca.md:269-275`) which is built on top of this claim.
- **Break**:
  1. `systemData.lastModifiedAt == createdAt == 2024-01-24T16:12:31` is from the ARM resource representation (`azure-alert-rule-raw.json:43-50`). This is the canonical ARM "last write" timestamp for the resource body.
  2. The RCA does NOT distinguish between:
     - Body edits (ARM PUT of the rule properties) — captured in `systemData.lastModifiedAt`.
     - Tag edits — also captured (typically).
     - Role assignment changes ON the rule's scope (action-group bindings, RBAC over the rule itself) — these are on a sibling resource (the role assignment), not the rule's `systemData`.
     - Activity log entries for "write" operations on this resource ID that, e.g., touched and reverted the rule — these could exist in the Activity Log but be invisible in `systemData` if the rule was reset to identical contents.
     - Soft-disable/enable cycles via the portal — `enabled` is a body field, so this SHOULD show, but does the portal touch `systemData` on toggle? Not probed.
  3. The sidecar `alert-rule-activity-log.json` is referenced at `rca.md:48` but **its contents are not summarized in the RCA**. If that sidecar contains the activity-log probe, its result should be in the Evidence Ledger; if it does not contain a 15-month history, the "never modified" claim is over-stated.
  4. Lesson 1 ("Out-of-IaC alerts decay silently for years") is structurally fine but its load-bearing premise is the never-modified claim. If the rule WAS edited via portal in a way that systemData didn't catch, the Lesson 1 narrative ("never adopted, no review") still holds — but the timeline pivot point ("15.5 months unchanged") becomes wrong.
- **Falsifier OR proof**:
  ```bash
  az monitor activity-log list \
    --resource-id /subscriptions/f007df01-9295-491c-b0e9-e3981f2df0b0/resourceGroups/mcprd-rg-vpp-p-res/providers/microsoft.insights/scheduledqueryrules/vpp-resource-unhealthy \
    --start-time 2024-01-24T00:00:00Z --end-time 2026-05-11T13:00:00Z \
    --query "[?contains(operationName.value, 'write') || contains(operationName.value, 'delete')].{when:eventTimestamp, who:caller, op:operationName.value}" \
    -o table
  ```
  Expected if E5 is accurate: zero rows (or one row at 2024-01-24 for the create). Anything else falsifies "never modified."
  Cross-check via Azure Resource Graph history:
  ```bash
  az graph query -q "resourcechanges
  | where resourceId =~ '/subscriptions/f007df01-9295-491c-b0e9-e3981f2df0b0/resourceGroups/mcprd-rg-vpp-p-res/providers/microsoft.insights/scheduledqueryrules/vpp-resource-unhealthy'
  | project change_time = properties.changeAttributes.timestamp, change_type = properties.changeType, source = properties.changeAttributes.changedByType"
  ```
- **Required patch**:
  1. Read the existing `alert-rule-activity-log.json` sidecar and **summarize its actual contents in a new evidence row E21**. If it does not cover the full 2024-01-24 → 2026-05-11 window, downgrade E5's "never modified" to A2 INFER from `systemData` only.
  2. In Lesson 1, rephrase the recommended probe from `az graph query` over `createdBy` to **include `properties.changeAttributes` history**, because resource graph history is the surface that catches the portal-edit-without-systemData-update case.
- **Conditional belief-change**: If the activity log shows any write between create and fire → E5 must be amended ("created 2024-01-24, last touched X by Y"), the timeline row at `rca.md:203` becomes wrong, and Lesson 1's "fifteen and a half months" narrative gets a real footnote. If the log is clean → E5 promotes to a tighter A1.

---

### F5 [LOW] — Lesson 3 conflates severity with mechanism

- **Quote / section ref**: `rca.md:285-291`.
- **Break**: Lesson 3 says "Sev-0 + autoMitigate=false is irreversible." The structural fault here is the KQL, not the severity. A sev-2 rule with the same KQL and `autoMitigate=false` would have the same "stays Fired forever" property; severity changes who-gets-paged-how, not the auto-close behavior. The lesson as written reads like "sev-0 is bad" when the actual rule is "any sev × autoMitigate=false + over-broad KQL = unkillable paging." Lesson 2 already covers the over-broad KQL, so Lesson 3's incremental signal is about the on-call asymmetry (manual close required), not the severity number.
- **Required patch**: Rephrase Lesson 3 title to "**`autoMitigate=false` on a paging-bound rule requires a manual-close runbook**", make sev-0 a paragraph-level qualifier ("severity intensifies the on-call cost but does not cause the mechanism"), and adjust the Probe to query for `autoMitigate==false` first, severity second.
- **Conditional belief-change**: If accepted → the Lesson catalogue cleanly separates "alert breadth" (Lesson 2), "alert auto-close semantics" (Lesson 3), and "alert governance gap" (Lesson 1). Currently Lesson 3 partially overlaps Lesson 2's "noisy" framing.

---

### F6 [MEDIUM] — Reader-mastery walkthrough: a 03:00 on-call trips at three points (see Lane 6 section below)

- **Quote / section ref**: TL;DR + L7 + L8 collectively.
- **Break**: see "Reader-mastery walkthrough" below — three concrete trip-points for a cold reader; the document is not 3-minute-actionable as it stands.
- **Required patch**:
  1. Move the "**5Z1B-6KG** Microsoft incident is the trigger" line out of the TL;DR's mid-paragraph and into a **single-line callout** before the TL;DR (e.g., `> SMOKING GUN: Microsoft platform incident 5Z1B-6KG mitigation notice landed in workspace at 13:10:36 UTC → over-broad KQL fired the alert at 13:12:43 UTC.`).
  2. Promote the close-only decision into a **3-line action checklist** at the top of L8 (close Azure alert; close ServiceNow ticket; run oc-playbook), with explicit "do this if the Microsoft incident is confirmed" precondition.
  3. Add a bold "**STOP closing if cluster probe returns positive degradation**" callout to L8 Plane 3 so a tired reader does not skip it.
- **Conditional belief-change**: If trip-points are addressed → the RCA passes the 3-min reader test and the L12 on-call card becomes optional rather than required. If not addressed → L12 (`on-call-onepager.md`) becomes mandatory before next on-call rotation, not "future" as currently written.

---

### F7 [LOW] — ASCII L3 topology fits a desk monitor, not a phone, and has no machine-parseable equivalent

- **Quote / section ref**: `rca.md:133-178`.
- **Break**: The ASCII art is approximately 78 columns × 45 lines. On a phone screen (Slack mobile, ServiceNow mobile app), this wraps and becomes unreadable. The RCA references a "Mermaid" requirement in the project conventions (`.claude/rules/markdown/conventions.md` — "MUST use \`\`\`mermaid for all system diagrams") and ships none. This is a project-convention violation, not just a readability nit.
- **Required patch**: Replace the ASCII box with a `flowchart LR` (or `flowchart TD` for phone) Mermaid block; keep the ASCII as an "alt-text" code block beneath for terminal viewers.
- **Conditional belief-change**: If converted → the RCA renders correctly on Slack and on the engineering-log GitHub view. If left as-is → the rca-holistic skill's Rule X7 (mermaid + ASCII fallback) is violated and the artifact has a real defect for cold-reader mobile triage.

---

### F8 [HIGH] — The RCA self-cites its sidecars as A1 evidence; some of those sidecars are coordinator-produced summaries that should be A2

- **Quote / section ref**: `rca.md:84` ("A1 = command/file proof"); rows E2, E3, E7, E8, E10, E11, E12, E15.
- **Break**:
  1. E2/E3/E4/E5/E6 cite `azure-alert-rule-raw.json` — this is genuinely the captured output of `az monitor scheduled-query show`. **A1 stands.**
  2. E7 cites `all-alerts-30d.json` — the sidecar list shows `alert-fires-30d.json` and `all-alerts-30d.json` separately; the RCA cites the wrong filename in E7 (says "sidecar `all-alerts-30d.json`" but the brief lists `alert-fires-30d.json`). I read `alert-fires-30d.json` and confirmed the 13:12:43 entry. The citation file name is **misaligned** with sidecar inventory — minor but a 3 AM reader following the breadcrumb will find a different file than the one named.
  3. E8 cites `workspace-servicehealth-firetime.json` — genuine `az monitor log-analytics query` output. **A1 stands**, but see F1 for what it actually shows.
  4. E10 is labelled A2 with a stated falsifier — that is correct epistemic discipline. But the inference itself is wrong (F1).
  5. E11/E12 cite `local-fs-alert-hcl-search.md` — this is a **subagent-produced sidecar**, not raw probe output. The sidecar contains its own evidence labels and verdict. The RCA imports the verdict as A2 INFER (correct), but several adjacent claims read as if the underlying searches were directly observed by the RCA author. The RCA does not say "subagent codebase-locator reported NOT FOUND; I did not re-run the rg commands myself." Under the harness `agent-laundering` rule, importing the subagent's conclusion is INFER until source-verified by the coordinator — the RCA does not document the source verification.
  6. E15 cites `rootly-past-hour-cross-check.md` — itself a coordinator-produced summary of Rootly MCP output. The underlying API response is not pinned; if Rootly returns different results next session, the citation does not survive replay.
- **Falsifier OR proof**:
  - Fix E7 file path mismatch by running `ls /Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/.ai/tasks/2026-05-11-005_cmc-alert-vpp-cluster-prod/sidecars/` and aligning the citation.
  - Add to E11/E12 an explicit "subagent codebase-locator (eneco-context-repos lineage) sidecar, INFER until coordinator-verified by partial re-run of one of the 12 probes."
- **Required patch**:
  1. Re-label E11/E12 from A2 to **"A1/A2 hybrid: A1 for the sidecar's existence + verdict statement; A2 for the underlying grep results which the coordinator did not re-execute."** Or run one literal `rg 'vpp-resource-unhealthy' /Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/` from the RCA author's terminal to bind one A1 probe to the inherited conclusion.
  2. Fix the filename in E7.
  3. Add an A1 vs A1-imported distinction in the Evidence Labels section at `rca.md:23-25` — coordinator-direct A1 vs subagent-imported A1.
- **Conditional belief-change**: If labels are tightened → the RCA's epistemic grade matches its actual evidence chain. If not → the RCA's conclusion ("the rule is not in IaC anywhere") rests on an unverified subagent claim and the Lesson 1 narrative inherits that uncertainty.

---

### F9 [MEDIUM] — Out-of-scope leakage and unstated open governance question

- **Quote / section ref**: Lesson 1 and L10 broadly.
- **Break**: The RCA discovered that the rule was created by `eelke.hoffman@conclusion.nl` — a Conclusion (vendor) identity, not an Eneco identity. The RCA documents this fact (E5) but treats it as morally neutral. The on-call has no authority to make a security/governance call here — but the document also does not flag the **separate finding** that a vendor identity created a sev-0 paging rule on a production subscription that escaped IaC for 15.5 months. That is a governance/audit signal that belongs in a follow-up ticket, not buried inside Lesson 1's "out-of-IaC alerts decay silently."
- **Required patch**: Add a single line to Lesson 1 or Limitations: *"Side observation, out of scope for this RCA: the creating principal is a vendor identity (@conclusion.nl). Whether vendor identities should be able to create sev-0 alerts on prod is a governance question for SRE/Platform, not an on-call decision."* Then stop — do not propose remediation.
- **Conditional belief-change**: If added → the RCA signals to next-shift readers without overreaching. If not → next-shift readers may infer that the on-call considered and dismissed the governance angle; explicitly flagging it as out-of-scope is more honest.

---

### F10 [LOW] — `Lesson 1 / Lesson 2` Probe queries are not literally executable

- **Quote / section ref**: `rca.md:273-275, 281`.
- **Break**:
  - Lesson 1 probe: `az graph query --query "Resources | where type =~ 'microsoft.insights/scheduledqueryrules' | extend createdBy = tostring(properties.systemData.createdBy) | where createdBy !endswith '@enecomanagedcloud.onmicrosoft.com' and createdBy !endswith '_terraform'"` — Azure Resource Graph does not expose `systemData` on the Resources table; it is exposed via `resourcechanges` or on the resource's `properties` if the provider surfaces it. In practice this query returns empty or errors out. The intent is sound; the syntax does not match the actual Graph schema.
  - Lesson 2 probe: "search Azure for any scheduled-query-rule whose KQL contains `ServiceHealth` and not `Activated/action`" — there is no surface that returns scheduled-query-rule KQL bodies via Graph; you have to enumerate rules and `az monitor scheduled-query show` each. The lesson presents this as a one-liner.
- **Required patch**: Either downgrade the Probe entries to "**Sketch of probe — verify Resource Graph schema before running**", or replace with executable form using `az monitor scheduled-query list --subscription ... | jq` enumeration. Untested probes presented as `bash` blocks are minor slop per `anti-slop-gate.md`.
- **Conditional belief-change**: If patched → Lessons are operationally useful; if left as-is → future on-calls copy-paste them, get empty results, and abandon the lesson.

---

## Reader-mastery walkthrough (Lane 6)

Scenario: next-shift on-call wakes at 03:00 CEST to a ServiceNow page identical to today's. They have read **only this RCA**, no surrounding context.

| Step | Action attempted | Trip point |
|---|---|---|
| 1 | Open RCA → scan TL;DR | TL;DR is a single 11-line paragraph. The smoking gun (`5Z1B-6KG` mitigation notice landed at 13:10:36 UTC → over-broad KQL fired at 13:12:43 UTC) is in the middle of the paragraph, sandwiched between resource-id minutiae and a paragraph-end "Recommended remediation tier" clause. **Trip 1: cannot find smoking gun in <30 sec.** (F6) |
| 2 | Decide whether to close the ticket | L8 Plane 1 says close the Azure alert. L8 Plane 2 says ServiceNow closes "if it does not propagate within ~15 minutes" do something else. **Trip 2: the ~15-min number is unsubstantiated (F2)**, so a 3 AM reader who waits 15 min and sees the ticket still open does not know whether to manually close or escalate. |
| 3 | Decide whether to probe the cluster | Plane 3 says "see `oc-playbook.md`." **Trip 3: that file does not exist (F3).** A 3 AM reader, finding the falsifier file missing, has two options: (a) skip the cluster probe and assume the RCA is right, which violates the RCA's own conditional ("if any probe shows degradation, stop using this RCA"), or (b) manually invent the probe at 03:00 — exactly the situation an RCA exists to prevent. |
| 4 | Memorable mental model | The mental model "Microsoft platform incident → its mitigation notice → our workspace → our over-broad KQL → our sev-0 ticket" is genuinely clean, but it competes for shelf space with the L3 ASCII topology (F7, mostly an inventory rather than a failure path), the L7 timeline (good), and three Lessons (Lesson 3 partially redundant with Lesson 2 — F5). **Trip 4 (minor): the mental model is buried in good-but-orthogonal layers.** A 3 AM reader who only reads TL;DR + L8 will get it; a reader who tries to read top-to-bottom will lose the thread by L5. |

**Trip-point count: 3 BLOCKING/HIGH (1, 2, 3) + 1 LOW (4).** This document is **not fit for `status: review` → `status: complete` promotion** until trips 1, 2, 3 are addressed.

## Lane-by-lane explicit results

- **Lane 1 (count arithmetic)**: BREAK — F1.
- **Lane 2 (ITSM connector path)**: BREAK — F2.
- **Lane 3 (no workload affected)**: BREAK — F3.
- **Lane 4 (never modified since 2024-01-24)**: BREAK — F4.
- **Lane 5 (sev-0 conflation)**: BREAK (low) — F5.
- **Lane 6 (reader mastery)**: BREAK — F6 (3 trip points).
- **Lane 7 (Mermaid/ASCII)**: BREAK (low) — F7.
- **Lane 8 (self-citation laundering)**: BREAK — F8.
- **Lane 9 (out-of-scope leakage)**: PARTIAL BREAK — F9 (omission, not over-reach: the RCA is more disciplined about scope than the brief feared, but it omits a single flag-and-stop on the vendor-identity governance angle).

No lanes returned "no break found." Each finding states a single load-bearing consequence the parent coordinator must change.

## Bottom-line for the parent coordinator

**Fix-and-ship**: this RCA has a genuinely correct core narrative (Microsoft mitigation notice → over-broad KQL → sev-0 ticket), but the load-bearing arithmetic in E10 contradicts the only sidecar on disk (F1), the load-bearing falsifier file does not exist (F3), and the load-bearing ServiceNow path is one of four uneliminated alternatives (F2) — close the ticket only after F1, F2, F3 are addressed in the document; otherwise the next on-call trips at three places by 03:00.
