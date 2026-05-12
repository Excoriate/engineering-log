---
task_id: 2026-05-11-007
agent: claude-code
status: complete
summary: Proposed additions to .ai/memory/lessons-learned.json — 7 new entries LL-006..LL-012 distilling today's quad-incident on-call shift, scoped to log/employer/eneco/**. Apply by appending to the JSON array.
---

# Proposed `lessons-learned.json` Additions (LL-006 → LL-012)

> **How to apply**: read this markdown, then append the JSON entries below to `.ai/memory/lessons-learned.json` (which is a JSON array of objects). Maintain valid JSON (commas between objects, no trailing comma after the last).

## Context

Current state of `.ai/memory/lessons-learned.json`:
- 5 entries: `LL-001..LL-005`
- All scoped to `log/employer/eneco/**`
- Schema fields: `id, scope, category, severity, confidence, summary, root_cause, fix, references, added, last_validated, task_origin`

Next available ID: **`LL-006`**

## Proposed Entries (apply as JSON)

```json
[
  {
    "id": "LL-006",
    "scope": "log/employer/eneco/**",
    "category": "credential-management",
    "severity": "high",
    "confidence": "validated",
    "summary": "Credential expiry is a recurring CLASS problem at Trade Platform (5 incidents in 18 months: INC-75 AAD SP / F4 AAD SP / PXQ KV / today's ArgoCD PAT / latent 2026-06-01 3 MC PATs). Per-incident rotation does NOT reduce class recurrence probability. Class-level remediation is mandatory: eliminate calendar-expiring credentials (Workload Identity Federation) OR automate rotation (KV + ESO + scheduler). Standing rule: any PR introducing a new credential MUST declare its rotation owner, verification path, and alarm surface in the same PR.",
    "root_cause": "Manual oral procedure carried by one engineer (Fabrizio Zavalloni); no class-level structural fix has shipped despite multiple post-incident promises since 2024-11 (INC-75). Each instance is firefought as if novel.",
    "fix": "Phase 1 (now-30d, unconditional): SLA + Grafana alert (`argocd_appset_status{condition_type=\"ErrorOccurred\"} > 0`) + named ownership rotation. Phase 2 (30-180d): choose Workload Identity Federation (eliminate PATs) or KV+ESO scheduled rotation based on Fabrizio's gap-list answers in `how-to-rotate.md` §7. Phase 3 (180d+): extend chosen option to F4 AAD SP, ESP cert, TF SP, BTM, Snyk classes.",
    "references": [
      "log/employer/eneco/02_on_call_shift/2026_05_11_rotating_expired_argocd_secrets/proposal-rotation-automation.md",
      "log/employer/eneco/02_on_call_shift/2026_05_11_rotating_expired_argocd_secrets/how-to-rotate.md",
      "llm-wiki/learnings/lessons/credential-expiry-is-a-class-problem-not-per-incident-firefight.md",
      "llm-wiki/context/repos/eneco-credential-expiry-class-incident-history-2024-2026.md"
    ],
    "added": "2026-05-11",
    "last_validated": "2026-05-11",
    "task_origin": "2026-05-11-007_oncall-week-knowledge-harvest"
  },
  {
    "id": "LL-007",
    "scope": "log/employer/eneco/**",
    "category": "alert-design",
    "severity": "high",
    "confidence": "validated",
    "summary": "Azure scheduled-query-rule property `autoMitigate=false` is ORTHOGONAL to severity. A sev-2 rule with autoMitigate=false has the same 'stays Fired forever' property as a sev-0 rule with autoMitigate=false. Severity changes who-gets-paged-how; autoMitigate changes whether the alert auto-resolves when criteria stop matching. Any paging-bound rule with autoMitigate=false MUST have: documented manual-close runbook, action group routing to 24/7 surface, runbook URL in rule description. Sev-0 + autoMitigate=false requires an extra reviewer.",
    "root_cause": "Conflating severity and autoMitigate at design time leads to over-broad sev-0 rules that fire indefinitely on transient triggers (today: CMC vpp-resource-unhealthy fired on Microsoft 5Z1B-6KG late-ingestion).",
    "fix": "Add autoMitigate audit to alert-authoring checklist: query `az monitor scheduled-query list --query \"[?autoMitigate==\\\\\\`false\\\\\\`].{name:name, sev:severity}\"` quarterly; each result must have a manual-close protocol or justified exception. Block sev-0 + autoMitigate=false in CI gate.",
    "references": [
      "log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/rca.md",
      "llm-wiki/learnings/lessons/automitigate-false-orthogonal-to-severity-needs-manual-close-runbook.md"
    ],
    "added": "2026-05-11",
    "last_validated": "2026-05-11",
    "task_origin": "2026-05-11-007_oncall-week-knowledge-harvest"
  },
  {
    "id": "LL-008",
    "scope": "log/employer/eneco/**",
    "category": "alert-noise",
    "severity": "high",
    "confidence": "validated",
    "summary": "Azure Monitor V2 scheduled-query-rules evaluate windows by `ingestion_time()`, NOT `TimeGenerated`. During Microsoft platform latency incidents (e.g., 5Z1B-6KG: Log Analytics + Application Insights West Europe latency 2026-05-11), workspace rows can land minutes-to-hours after emission. Azure's engine has a built-in late-data-settling period that delays evaluation; the late-arrived rows fall into the window and trigger the rule. Net effect: alerts can fire ~20+ minutes AFTER an event's nominal TimeGenerated. Alert KQL MUST narrow `CategoryValue` predicates with `ActivityStatusValue`, `impactedServices`, `_ResourceId`, etc.; raw `CategoryValue == 'ServiceHealth'` matches Microsoft's full announcement stream including resolution notices and backlog-drained earlier notices.",
    "root_cause": "Out-of-IaC manually-created rule (`vpp-resource-unhealthy`) with single-predicate KQL had no narrowing filter; the late-ingestion mechanism of Azure scheduled-query engine + Microsoft platform incident combined to fire on stale data.",
    "fix": "Adversarial review pre-deploy on any new Azure scheduled-query rule MUST include backtest against a known prior Microsoft platform incident. Prefer `ResourceHealth + Activated/action + ResourceProviderValue` over raw `ServiceHealth` for resource-centric semantics. Add ingestion-latency monitoring on workspaces in regions with historical platform incidents (West Europe).",
    "references": [
      "log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/rca.md",
      "llm-wiki/learnings/gotchas/azure-monitor-late-ingestion-fires-alerts-from-stale-data.md"
    ],
    "added": "2026-05-11",
    "last_validated": "2026-05-11",
    "task_origin": "2026-05-11-007_oncall-week-knowledge-harvest"
  },
  {
    "id": "LL-009",
    "scope": "log/employer/eneco/**",
    "category": "incident-methodology",
    "severity": "high",
    "confidence": "validated",
    "summary": "When an incident's RCA must choose between multiple uneliminated causal hypotheses, the correct RCA shape is observation-only — install the discriminator probes + the reader's mental model; ship NO fix recommendation. Today's CPU throttling RCA carried 4 uneliminated hypotheses (H-A undersized CPU, H-B memory pressure upstream, H-C rule mis-calibrated for sidecar class, H-D debug exporter verbose); each implies a different fix. Picking one without elimination ships the wrong fix and masks the real cause.",
    "root_cause": "Hypothesis dependency is non-trivial (H-A is symptom; H-B/H-D are candidate upstream causes; H-C is orthogonal); a snapshot decision ignores dependency structure.",
    "fix": "Document the observation-only L8 template in the RCA process. Adjudication heuristic: run all hypothesis-cheapest-probes; if H-D-class confirms (cheapest+most-reversible), ship that fix first. If H-B-class confirms with H-A-class together, do NOT fix the symptom until the upstream is understood.",
    "references": [
      "log/employer/eneco/02_on_call_shift/2026_05_11_rootly_alert_cpu_throtling/output/rca.md",
      "llm-wiki/learnings/lessons/observation-only-rca-when-multiple-hypotheses-undiscriminated.md"
    ],
    "added": "2026-05-11",
    "last_validated": "2026-05-11",
    "task_origin": "2026-05-11-007_oncall-week-knowledge-harvest"
  },
  {
    "id": "LL-010",
    "scope": "log/employer/eneco/**",
    "category": "on-call-discipline",
    "severity": "high",
    "confidence": "validated",
    "summary": "At Eneco Trade Platform, on-call incidents land in 4+ different intake channels per shift: #myriad-platform (public, bot-driven cards), #team-platform (private internal triage), Rootly direct page (alertmanager-routed; no Slack mention), ServiceNow CMC ticket (sometimes pasted into Slack as URL, often not). Today's 2026-05-11 shift had FOUR incidents and EACH was in a different channel. Reading only #myriad-platform misses 50%+ of an on-call's actual work. Future summarizers MUST sample ALL surfaces: Slack public + Slack private + Rootly + ServiceNow + RCA dirs.",
    "root_cause": "Multiple alert/intake systems wire to different end-state surfaces with no canonical aggregator. Each surface has its own ownership and notification pattern. Coordination implicit on humans, not on a single dashboard.",
    "fix": "On-call summary protocol: enumerate ALL surfaces (Slack public + private + Rootly + SN + RCA dirs) before composing the shift report. Use `eneco-context-slack` for Slack surfaces, `eneco-tools-rootly` for Rootly, manual ServiceNow check. Cross-correlate by time window.",
    "references": [
      "llm-wiki/learnings/lessons/oncall-summary-cannot-reconstruct-from-single-intake-channel.md",
      "llm-wiki/episodes/2026-05-11-oncall-shift-trade-platform-quad-incident.md"
    ],
    "added": "2026-05-11",
    "last_validated": "2026-05-11",
    "task_origin": "2026-05-11-007_oncall-week-knowledge-harvest"
  },
  {
    "id": "LL-011",
    "scope": "log/employer/eneco/**",
    "category": "iac-state-hygiene",
    "severity": "high",
    "confidence": "validated",
    "summary": "FBE slot recycling can leave Azure resources orphaned in `rg-vpp-app-sb-401` (Sandbox subscription `7b1ba02e-...`) that are NOT tracked in the slot's Terraform state. Three uneliminated provenance paths: failed destroy with `terraform state rm` workaround / out-of-band create / Terraform version drift (1.14.3 create vs 1.13.1 destroy → silent skip on state-version-mismatch). Apply-time error: `azurerm_eventhub_namespace 'vpp-evh-premium-<slot>' already exists - to be managed via Terraform this resource needs to be imported into the State`. Fix is delete-recreate (when orphan is empty); destroy pipeline MUST verify zero residue before slot release.",
    "root_cause": "Destroy pipeline `azure-pipeline-fbe-del.yml` lacks residue-zero check; create/destroy pipelines on misaligned Terraform versions.",
    "fix": "Add residue-zero check to destroy pipeline (per slot, query `az resource list -g rg-vpp-app-sb-401` for resources matching slot name; fail if non-zero). Align Terraform versions between create (1.14.3) and destroy (1.13.1). Audit all 10 slots for existing orphans.",
    "references": [
      "log/employer/eneco/02_on_call_shift/2026_05_11_fbe_error_duncan/rca.md",
      "log/employer/eneco/02_on_call_shift/2026_05_11_fbe_error_duncan/fix.md",
      "llm-wiki/learnings/gotchas/fbe-terraform-eventhub-namespace-orphan-on-slot-recycling.md"
    ],
    "added": "2026-05-11",
    "last_validated": "2026-05-11",
    "task_origin": "2026-05-11-007_oncall-week-knowledge-harvest"
  },
  {
    "id": "LL-012",
    "scope": "log/employer/eneco/**",
    "category": "alert-governance",
    "severity": "medium",
    "confidence": "validated",
    "summary": "Alerts created manually outside IaC during platform stand-up never get adopted into IaC; their KQL/thresholds age silently because no review surface owns them. Today's CMC alert rule was created 2024-01-24 by a vendor identity (Conclusion's `eelke.hoffman@conclusion.nl`), single-predicate KQL, sev-0, autoMitigate=false, actions=null — escaped IaC review for 15.5 months until firing today on a Microsoft 5Z1B-6KG-driven late ingestion. Defense: quarterly inventory diff (`az monitor scheduled-query list` per subscription vs IaC-derived expected name list); any unmatched rule is adopt-or-delete within one sprint.",
    "root_cause": "No review surface, no quarterly audit cadence, vendor-identity alert authoring left no IaC trace.",
    "fix": "Quarterly inventory diff job (runs in CI or as scheduled task); alert-authoring checklist requiring PR-only rule creation (no portal authoring on prd); mandatory action group binding (CI gate refuses `actions: null`).",
    "references": [
      "log/employer/eneco/02_on_call_shift/2026_05_11_cmc_alert_vpp_cluster_prod/rca.md",
      "llm-wiki/learnings/lessons/out-of-iac-alerts-decay-silently-quarterly-inventory-diff.md"
    ],
    "added": "2026-05-11",
    "last_validated": "2026-05-11",
    "task_origin": "2026-05-11-007_oncall-week-knowledge-harvest"
  }
]
```

## Application Instructions

1. Open `.ai/memory/lessons-learned.json` (currently a JSON array of 5 objects)
2. Locate the closing `]` of the array
3. Before that `]`, insert a comma after the LL-005 closing `}` (if not already present)
4. Paste the 7 new objects above (in the same array, comma-separated)
5. Validate JSON: `jq . .ai/memory/lessons-learned.json` (must not error)
6. Confirm count: `jq 'length' .ai/memory/lessons-learned.json` → expect `12`

## Companion Markdown Notes

Each LL entry has a companion markdown note in the vault — see the spec files in `../specs/`:

| LL ID | Companion vault note spec |
|-------|---------------------------|
| LL-006 | `lesson-credential-expiry-is-a-class-problem-not-per-incident-firefight.md` |
| LL-007 | `lesson-automitigate-false-orthogonal-to-severity-needs-manual-close-runbook.md` |
| LL-008 | `gotcha-azure-monitor-late-ingestion-fires-alerts-from-stale-data.md` |
| LL-009 | `lesson-observation-only-rca-when-multiple-hypotheses-undiscriminated.md` |
| LL-010 | `lesson-oncall-summary-cannot-reconstruct-from-single-intake-channel.md` |
| LL-011 | `gotcha-fbe-terraform-eventhub-namespace-orphan-on-slot-recycling.md` |
| LL-012 | `lesson-out-of-iac-alerts-decay-silently-quarterly-inventory-diff.md` |

Plus the supporting Episode + ArgoCD-PAT gotcha + OpenShift sanity-check pattern + Azure two-plane close pattern + credential-expiry-history context — all already drafted in `../specs/`.
