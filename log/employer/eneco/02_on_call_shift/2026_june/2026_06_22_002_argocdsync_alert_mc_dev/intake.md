# ArgoCDSyncAlert — MC Dev (Rootly intake)

## Derivation header

| Field | Value |
|-------|-------|
| `template_id` | `slack-intake.template.md` |
| `template_version` | `1.0.0` |
| `template_path` | [`log/employer/eneco/02_on_call_shift/_templates/slack-intake.template.md`](../../_templates/slack-intake.template.md) |
| `instance_id` | `2026_02_22_002_argocdsync_alert_mc_dev` |
| `filled_date` | `2026-06-22` |
| `example_calibrated` | `fbe-404-stefan-intake.md` (bundled under harness skill) |

> **Derived intake:** Generic structure and UAC live in the [template](../../_templates/slack-intake.template.md). This file is a **rendered instance** for a Rootly / Alertmanager **ArgoCDSyncAlert** on MC Dev — not an FBE slot incident.

## Table of contents

- [Instance manifest](#instance-manifest)
- [Input](#input)
  - [Description](#description)
  - [Original request (verbatim)](#original-request-verbatim)
  - [Known state from attachments](#known-state-from-attachments)
- [Mandatory context](#mandatory-context)
  - [Environmental context](#environmental-context)
  - [Context to fetch (mandatory)](#context-to-fetch-mandatory)
  - [Skills to use](#skills-to-use)
  - [Tools or CLI(s)](#tools-or-clis)
  - [UAC](#uac)
    - [Evidence and honesty](#evidence-and-honesty)
    - [Learning bar](#learning-bar)
    - [Deliverables](#deliverables)
    - [Post-completion: vault and memory](#post-completion-vault-and-memory)
    - [RCA acceptance](#rca-acceptance)
    - [How-to-fix acceptance](#how-to-fix-acceptance)
    - [Out of scope for UAC](#out-of-scope-for-uac)

## Instance manifest

Single source of incident-specific values. Keys marked `n/a` are inapplicable (not FBE).

| Key | Value | Evidence |
|-----|-------|----------|
| `INCIDENT_TITLE` | ArgoCDSyncAlert — MC Dev (Rootly) | A1 Rootly payload |
| `INSTANCE_ID` | `2026_02_22_002_argocdsync_alert_mc_dev` | A1 task path |
| `SLACK_LIST_URL` | *(none at intake)* | A3 — no Slack thread linked yet |
| `ATTACHMENT_REFS` | Rootly alert JSON (inline below) | A1 user intake |
| `SLOT` | `n/a` (MC platform GitOps alert) | A1 not FBE |
| `BUILD_ID` | `n/a` | A1 no ADO build in alert |
| `PIPELINE_ID` | `n/a` | A1 |
| `PUBLIC_URL` | `https://console-openshift-console.apps.eneco-vpp-dev.ceap.nl/monitoring` | A1 `externalURL` / generatorURL in payload |
| `KUBE_CONTEXT` | `n/a` — use `oc` login to MC Dev API | A2 MC Dev cluster |
| `AZ_SUBSCRIPTION` | `n/a` — OpenShift MC, not sandbox AKS subscription | A2 |
| `RESOURCE_GROUP` | `n/a` | A2 |
| `PRIMARY_SKILL` | `eneco-platform-mc-vpp-infra` | A2 router: ArgoCD on MC Dev |
| `VAULT_FBE_PATH` | `$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/` | A2 platform vault neighborhood |
| `VAULT_ERRORS_PATH` | `$SECOND_BRAIN_PATH/llm-wiki/learnings/gotchas/` | A2 |
| `SEARCH_TERMS` | `ArgoCDSyncAlert`, `OutOfSync`, `eneco-vpp-argocd`, `grafana`, `launchpad`, `dockersecrettelemetry`, `MC dev`, `autosync_enabled` | A1 |
| `ROUTER_SYMPTOM` | `ArgoCDSyncAlert MC dev eneco-vpp-argocd grafana launchpad dockersecrettelemetry OutOfSync Healthy info severity` | A1 |
| `INVESTIGATION_HOST` | `AVD` | A2 MC Dev OpenShift + Argo CD — live probes only from AVD; local `argocd` CLI will not work |
| `LEDGER_DATE` | `2026-06-22` | A1 intake render date |
| `SNAPSHOT_NOTE` | Three Argo CD apps OutOfSync but Healthy in `eneco-vpp-argocd`; `grafana` autosync **false**, others **true**; firing since 2026-06-19 — re-probe before RCA | A1 payload |

## Input

### Description

**ArgoCDSyncAlert** is a Prometheus/Alertmanager rule on MC Dev that fires when Argo CD Applications in `eneco-vpp-argocd` report `sync_status=OutOfSync` while often remaining `health_status=Healthy`.

**A1 FACT** (Rootly alert batch `7190c81c-0cb8-4852-986c-6e79c16f5e23`, status `triggered`, severity **info**): three applications are firing simultaneously:

| Application | Dest namespace | Autosync | Git repo (label) | Sync | Health | Since (UTC) |
|-------------|----------------|----------|------------------|------|--------|-------------|
| `grafana` | `eneco-vpp-grafana` | **false** | `vpp-configuration` (Myriad VPP) | OutOfSync | Healthy | 2026-06-19T11:01:32Z |
| `launchpad` | `eneco-vpp-asset-scheduling` | **true** | `asset-scheduling-gitops` | OutOfSync | Healthy | 2026-06-19T15:21:02Z |
| `dockersecrettelemetry` | `eneco-vpp-telemetry` | **true** | `argocd-config` | OutOfSync | Healthy | 2026-06-19T11:01:32Z |

Alertmanager receiver: `eneco-vpp-argocd/alertmanagerconfig/rootly-trade-platform` → Rootly escalation policy.

> **Do not treat info severity + Healthy as “no action”.** OutOfSync can indicate drift, manual sync needed, or autosync disabled (`grafana`). Confirm whether Trade Platform owns remediation vs CMC GitOps for each app/repo.

### Original request (verbatim)

**Status:** **A1 FACT** — Rootly alert payload supplied at intake (not Slack). Rootly MCP `get_incident` on batch UUID returned 404 — treat as alert-group id, not Rootly incident sequential id.

```json
{
  "ID": "7190c81c-0cb8-4852-986c-6e79c16f5e23",
  "alerts": [
    {
      "endsAt": "0001-01-01T00:00:00Z",
      "labels": {
        "job": "eneco-vpp-metrics",
        "pod": "eneco-vpp-application-controller-0",
        "name": "grafana",
        "repo": "https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/myriad%20-%20vpp/_git/vpp-configuration",
        "project": "default",
        "service": "eneco-vpp-metrics",
        "endpoint": "metrics",
        "instance": "100.66.7.39:8082",
        "severity": "info",
        "alertname": "ArgoCDSyncAlert",
        "container": "argocd-application-controller",
        "namespace": "eneco-vpp-argocd",
        "prometheus": "openshift-user-workload-monitoring/user-workload",
        "dest_server": "https://kubernetes.default.svc",
        "sync_status": "OutOfSync",
        "health_status": "Healthy",
        "dest_namespace": "eneco-vpp-grafana",
        "autosync_enabled": "false",
        "exported_namespace": "eneco-vpp-argocd"
      },
      "status": "firing",
      "startsAt": "2026-06-19T11:01:32.193Z",
      "annotations": {
        "message": "ArgoCD application grafana is out of sync"
      },
      "fingerprint": "0c09c3fe127c015f",
      "generatorURL": "https://console-openshift-console.apps.eneco-vpp-dev.ceap.nl/monitoring/graph?g0.expr=argocd_app_info%7Bnamespace%3D%22eneco-vpp-argocd%22%2Csync_status%3D%22OutOfSync%22%7D+%3E+0&g0.tab=1"
    },
    {
      "endsAt": "0001-01-01T00:00:00Z",
      "labels": {
        "job": "eneco-vpp-metrics",
        "pod": "eneco-vpp-application-controller-0",
        "name": "launchpad",
        "repo": "https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/vpp%20-%20asset%20optimisation/_git/asset-scheduling-gitops",
        "project": "asset-scheduling",
        "service": "eneco-vpp-metrics",
        "endpoint": "metrics",
        "instance": "100.66.7.39:8082",
        "severity": "info",
        "alertname": "ArgoCDSyncAlert",
        "container": "argocd-application-controller",
        "namespace": "eneco-vpp-argocd",
        "prometheus": "openshift-user-workload-monitoring/user-workload",
        "dest_server": "https://kubernetes.default.svc",
        "sync_status": "OutOfSync",
        "health_status": "Healthy",
        "dest_namespace": "eneco-vpp-asset-scheduling",
        "autosync_enabled": "true",
        "exported_namespace": "eneco-vpp-argocd"
      },
      "status": "firing",
      "startsAt": "2026-06-19T15:21:02.193Z",
      "annotations": {
        "message": "ArgoCD application launchpad is out of sync"
      },
      "fingerprint": "5e5c3ea4c8f6c923",
      "generatorURL": "https://console-openshift-console.apps.eneco-vpp-dev.ceap.nl/monitoring/graph?g0.expr=argocd_app_info%7Bnamespace%3D%22eneco-vpp-argocd%22%2Csync_status%3D%22OutOfSync%22%7D+%3E+0&g0.tab=1"
    },
    {
      "endsAt": "0001-01-01T00:00:00Z",
      "labels": {
        "job": "eneco-vpp-metrics",
        "pod": "eneco-vpp-application-controller-0",
        "name": "dockersecrettelemetry",
        "repo": "https://enecomanagedcloud@dev.azure.com/enecomanagedcloud/myriad%20-%20vpp/_git/argocd-config",
        "project": "default",
        "service": "eneco-vpp-metrics",
        "endpoint": "metrics",
        "instance": "100.66.7.39:8082",
        "severity": "info",
        "alertname": "ArgoCDSyncAlert",
        "container": "argocd-application-controller",
        "namespace": "eneco-vpp-argocd",
        "prometheus": "openshift-user-workload-monitoring/user-workload",
        "dest_server": "https://kubernetes.default.svc",
        "sync_status": "OutOfSync",
        "health_status": "Healthy",
        "dest_namespace": "eneco-vpp-telemetry",
        "autosync_enabled": "true",
        "exported_namespace": "eneco-vpp-argocd"
      },
      "status": "firing",
      "startsAt": "2026-06-19T11:01:32.193Z",
      "annotations": {
        "message": "ArgoCD application dockersecrettelemetry is out of sync"
      },
      "fingerprint": "53ee23a68aaa2b40",
      "generatorURL": "https://console-openshift-console.apps.eneco-vpp-dev.ceap.nl/monitoring/graph?g0.expr=argocd_app_info%7Bnamespace%3D%22eneco-vpp-argocd%22%2Csync_status%3D%22OutOfSync%22%7D+%3E+0&g0.tab=1"
    }
  ],
  "rootly": {
    "title": "ArgoCDSyncAlert",
    "description": null,
    "alert_source_url": "https://console-openshift-console.apps.eneco-vpp-dev.ceap.nl/monitoring/graph?g0.expr=argocd_app_info%7Bnamespace%3D%22eneco-vpp-argocd%22%2Csync_status%3D%22OutOfSync%22%7D+%3E+0&g0.tab=1",
    "alerting_targets": [
      {
        "id": "1b6ee744-4aca-45ed-9d00-2d1d2b5edbfa",
        "type": "EscalationPolicy"
      }
    ]
  },
  "status": "firing",
  "version": "4",
  "groupKey": "{}/{namespace=\"eneco-vpp-argocd\"}:{alertname=\"ArgoCDSyncAlert\", job=\"eneco-vpp-metrics\"}",
  "receiver": "eneco-vpp-argocd/alertmanagerconfig/rootly-trade-platform",
  "externalURL": "https://console-openshift-console.apps.eneco-vpp-dev.ceap.nl/monitoring",
  "groupLabels": {
    "job": "eneco-vpp-metrics",
    "alertname": "ArgoCDSyncAlert"
  },
  "commonLabels": {
    "job": "eneco-vpp-metrics",
    "pod": "eneco-vpp-application-controller-0",
    "service": "eneco-vpp-metrics",
    "endpoint": "metrics",
    "instance": "100.66.7.39:8082",
    "severity": "info",
    "alertname": "ArgoCDSyncAlert",
    "container": "argocd-application-controller",
    "namespace": "eneco-vpp-argocd",
    "prometheus": "openshift-user-workload-monitoring/user-workload",
    "dest_server": "https://kubernetes.default.svc",
    "sync_status": "OutOfSync",
    "health_status": "Healthy",
    "exported_namespace": "eneco-vpp-argocd"
  },
  "routing_rules": [
    {
      "id": "f4a0e4c1-f2ab-4ee8-8309-21b56db807ad",
      "targets": [
        {
          "id": "1b6ee744-4aca-45ed-9d00-2d1d2b5edbfa",
          "type": "EscalationPolicy"
        }
      ]
    }
  ],
  "truncatedAlerts": 0,
  "alert_urgency_id": "8824cd16-edb5-4bc3-8d0b-0ab833b1a8ac",
  "commonAnnotations": {},
  "rootly_alert_status": "triggered"
}
```

### Known state from attachments

**A1 FACT** from alert labels (not live cluster state):

- Controller pod: `eneco-vpp-application-controller-0` in `eneco-vpp-argocd`
- Metrics instance: `100.66.7.39:8082` (Prometheus: `openshift-user-workload-monitoring/user-workload`)
- Alert batch: `version` **4**, `groupKey` `{}/{namespace="eneco-vpp-argocd"}:{alertname="ArgoCDSyncAlert", job="eneco-vpp-metrics"}`, `truncatedAlerts` **0**
- Receiver: `eneco-vpp-argocd/alertmanagerconfig/rootly-trade-platform` → Rootly escalation policy `1b6ee744-4aca-45ed-9d00-2d1d2b5edbfa`
- All three apps: `sync_status=OutOfSync`, `health_status=Healthy`, `severity=info`
- **`grafana`**: autosync **disabled** — OutOfSync may be expected until manual sync or policy change
- **`launchpad`** / **`dockersecrettelemetry`**: autosync **enabled** — drift may indicate GitOps lag, sync failure, or compare-options mismatch
- Repos span **three ADO projects** (Myriad VPP, Asset Optimisation, argocd-config) — ownership may differ per app

## Mandatory context

### Environmental context

| Field | Value |
|-------|-------|
| Platform | MC Dev OpenShift (`eneco-vpp-dev`, host suffix `*.apps.eneco-vpp-dev.ceap.nl`) |
| Monitoring / alert UI | [OpenShift monitoring console](https://console-openshift-console.apps.eneco-vpp-dev.ceap.nl/monitoring) |
| Argo CD control plane NS | `eneco-vpp-argocd` |
| Argo CD UI (typical MC Dev) | `eneco-vpp-server-eneco-vpp-argocd.apps.eneco-vpp-dev.ceap.nl` (**A2 INFER** — confirm after `oc` login) |
| Alert route | Alertmanager → Rootly (`rootly-trade-platform`) |
| FBE slot | **n/a** |
| ADO org | `enecomanagedcloud` |
| **Live investigation host** | **AVD only** — MC Dev OpenShift + Argo CD probes are not reachable from local laptop or agent sandbox |

> **AVD requirement (A2):** For MC Dev/Acc/Prd, Argo CD and OpenShift live troubleshooting (`oc`, app status, sync/diff, console) **must run on an AVD session**. Local `argocd` CLI against MC will **not work** — use Argo CD UI or `oc get applications.argoproj.io` from AVD after `eneco-tools-connect-mc-environments` login.

**GitOps repos implicated (A1 from alert labels):**

| Application | ADO repo | Project |
|-------------|----------|---------|
| `grafana` | `vpp-configuration` | Myriad - VPP |
| `launchpad` | `asset-scheduling-gitops` | VPP - Asset Optimisation |
| `dockersecrettelemetry` | `argocd-config` | Myriad - VPP |

### Context to fetch (mandatory)

Complete **before** live probes or destructive sync. Summaries **in this file** (not task notes only).

| # | Source | Skill | Harvest summary | Channels / paths |
|---|--------|-------|-----------------|-------------------|
| 1 | Slack — platform requests | `eneco-context-slack` | **A3 UNVERIFIED[blocked: Slack MCP auth-only in intake session]** — manual: search `#myriad-platform` for `ArgoCDSyncAlert`, `OutOfSync`, app names | `#myriad-platform` |
| 2 | Slack — team coordination | `eneco-context-slack` | **A3 UNVERIFIED[blocked: same]** — manual: `#team-platform` for prior handlers / known drift | `#team-platform` |
| 3 | Slack / Rootly thread | `eneco-oncall-intake-rootly` | **A1 FACT** — Rootly JSON embedded [above](#original-request-verbatim); no Slack URL at intake | Rootly alert batch id `7190c81c-…` |
| 4 | Written runbooks / wiki | `eneco-context-docs` | **A2 INFER** — repo log documents MC ArgoCD topology + PAT/GitOps patterns: [`2026_05_11_rotating_expired_argocd_secrets`](../../2026_may/2026_05_11_rotating_expired_argocd_secrets/draft-rotation-secrets.md) (dual ArgoCD instances, `eneco-vpp-argocd` vs `openshift-gitops`) | Platform-documentation wiki; ADO wikis |
| 5 | Second brain | `2ndbrain-obsidian` | **A3 UNVERIFIED[blocked: vault not queried at intake]** — search `eneco-vpp-platform`, `ArgoCD`, `OutOfSync` | `$SECOND_BRAIN_PATH/2-areas/work-eneco/eneco-vpp-platform/` |

**Example search terms (this incident):** `ArgoCDSyncAlert`, `OutOfSync`, `eneco-vpp-argocd`, `grafana`, `launchpad`, `dockersecrettelemetry`, `autosync_enabled false`, `MC dev`.

**Done when:** **A2 INFER** — prior MC ArgoCD log cited in row 4; Rootly payload A1 in row 3. Slack/vault rows blocked with named fallback queries.

> **MC access:** Use `eneco-tools-connect-mc-environments` for Dev MC login **from AVD**; turn OFF IP whitelisting when done. Do not attempt live cluster probes from local agent environment.

### Skills to use

| Skill | Phase | Role |
|-------|-------|------|
| `eneco-oncall-intake-rootly` | Intake / harvest | Decode Rootly payload, map alerts → apps (**used at intake**) |
| `eneco-context-slack` | Before investigation | Mandatory context fetch (blocked paths documented) |
| `eneco-context-docs` | Before investigation | Runbooks and wiki |
| `2ndbrain-obsidian` | Before investigation | Vault search |
| `eneco-platform-mc-vpp-infra` | Investigation | MC Dev OpenShift + Argo CD probes, safety gates |
| `eneco-context-repos` | Investigation | Repo map for three GitOps repos |
| `eneco-tools-connect-mc-environments` | Investigation | MC Dev connectivity |
| `on-call-log-entry` | Throughout | Log layout after spec accepted |
| `rca-holistic` | Deliverables | `output/rca.html` |
| `how-to-feynman` | Deliverables | `output/how-to-fix.html` |
| `2ndbrain-knowledge-build` | After completion | Vault domain knowledge (UAC) |
| `2ndbrain-memory-consolidate` | After completion | Episode + lessons (UAC) |

**Classification gate:** Load `eneco-platform-mc-vpp-infra`. **No FBE router** — record `FAILURE_CLASS` (e.g. `gitops-drift-info`, `benign-autosync-off`, `action-required-autosync-on`), `ROUTER_STATUS`, and probe plan in task notes. **All live probes on AVD.** Per app: confirm autosync policy, diff (Argo CD UI or `oc` Application CR), and owning team (Trade Platform vs CMC).

### Tools or CLI(s)

**Purpose:** Tool ledger and identifiers at intake time. Agent selects probes via `eneco-platform-mc-vpp-infra` — generic contract per [template § Tools](../../_templates/slack-intake.template.md#tools-or-clis).

#### Agent contract

- **Primary authority:** `eneco-platform-mc-vpp-infra` + fetched context
- **Investigation host:** **`AVD`** — MC Dev OpenShift + Argo CD live troubleshooting is **not possible** from local laptop or agent sandbox
- **Identifiers:** [Incident identifiers](#incident-identifiers) only — do not invent app/repo names beyond alert payload
- **Evidence:** `A1 FACT` · `A2 INFER` · `A3 UNVERIFIED`
- **Ledger vs live:** Snapshot from 2026-06-19 alert timestamps — re-verify at investigation **on AVD**
- **Destructive actions:** `argocd app sync` / GitOps changes require explicit user authorization and owner confirmation per app — run from AVD (UI or approved in-cluster path), not local CLI
- **Record in RCA:** Commands actually run **on AVD** — not this exemplar list

#### Incident identifiers

| Constant | Value |
|----------|-------|
| `ROOTLY_ALERT_BATCH_ID` | `7190c81c-0cb8-4852-986c-6e79c16f5e23` |
| `INVESTIGATION_HOST` | `AVD` |
| `ALERTNAME` | `ArgoCDSyncAlert` |
| `ARGOCD_NS` | `eneco-vpp-argocd` |
| `MC_CLUSTER` | `eneco-vpp-dev` (console host) |
| `AFFECTED_APPS` | `grafana`, `launchpad`, `dockersecrettelemetry` |
| `PUBLIC_URL` | `https://console-openshift-console.apps.eneco-vpp-dev.ceap.nl/monitoring` |
| `ADO_ORG` | `enecomanagedcloud` |
| `SEVERITY` | `info` |

#### Tool availability ledger

| Tool | Version (ledger 2026-06-22) | Notes |
|------|-----------------------------|-------|
| `kubectl` | v1.36.2 | Off-AVD may target wrong context; MC Dev prefers `oc` **on AVD** |
| `oc` | **A3 UNVERIFIED[not probed at intake]** | **Required on AVD** for MC Dev OpenShift |
| `argocd` CLI | v3.4.4 (local) | **NOT AVAILABLE off-AVD** for MC live troubleshooting — will not authenticate/reach MC server from laptop; use Argo CD UI on AVD or `oc get applications.argoproj.io` |
| `az` | **A3 UNVERIFIED[not probed at intake]** | ADO repo access if needed |
| `jq` | **A3 UNVERIFIED[not probed at intake]** | Parse alert JSON |
| `curl` | system | Console/metrics smoke (browser on AVD preferred) |
| `rg` | system | Filter CLI output |
| `qctl` | **NOT FOUND** | Use `oc` / `kubectl` on AVD |

#### Investigation surfaces (agent-selected)

| Surface | Questions | Example tools |
|---------|-----------|---------------|
| **GitOps / Argo CD** | Per-app sync status, revision, autosync, diff, sync failures? | **On AVD:** Argo CD UI; `oc get applications.argoproj.io -n eneco-vpp-argocd`; `oc describe application <name> -n eneco-vpp-argocd` |
| **Git / repo** | Target revision exists? Recent commits? Repo credentials? | ADO from AVD or laptop; `eneco-context-repos` |
| **Alert / noise** | Info-only chronic drift vs new regression? Suppression? | Prometheus rule, Rootly incident history |
| **Ownership** | Trade Platform vs CMC GitOps per app/repo? | Slack, `#team-platform` |

#### Exemplar commands (reference only — **run on AVD session**)

```bash
# On AVD session — after eneco-tools-connect-mc-environments Dev MC login
oc whoami
oc get applications.argoproj.io -n eneco-vpp-argocd -o wide
oc get application grafana -n eneco-vpp-argocd -o jsonpath='{.status.sync.status}{" "}{.status.health.status}{" autosync="}{.spec.syncPolicy.automated}{"\n"}'
# Argo CD UI (preferred for diff/sync on MC Dev): open server route from AVD browser
# Do NOT rely on local: argocd login / argocd app diff — will not work off-AVD for MC
curl -sS -o /dev/null -w "http_code=%{http_code}\n" "https://console-openshift-console.apps.eneco-vpp-dev.ceap.nl/monitoring"
```

**SNAPSHOT (2026-06-22):** Intake-time snapshot from Rootly payload only — three apps OutOfSync/Healthy; `grafana` autosync off; alerts firing since 2026-06-19 — **re-probe live cluster before RCA**.

### UAC

**Done** means every requirement below is satisfied. **Epistemic labels:** `A1 FACT` · `A2 INFER` · `A3 UNVERIFIED`.

#### Evidence and honesty

| Rule | What it means for the agent |
|------|----------------------------|
| Context fetched | [Context to fetch](#context-to-fetch-mandatory) completed or blocked with documented fallback |
| No unverified claims | Root cause requires probe evidence; hypotheses ≤3 with discriminating probes |
| Honest probes | RCA lists commands **actually run** |
| Re-run rule | Intake snapshots and ledger rows are not live truth |

#### Learning bar

When the fix is confirmed, I must **replay diagnosis and repair myself** from deliverables alone. Opaque steps **fail** UAC even if the incident is fixed.

#### Deliverables

Two HTML artifacts under `output/` (relative to incident folder). Markdown working notes are fine; they do not replace `output/*.html`.

| # | Artifact | Path | Skill |
|---|----------|------|-------|
| 1 | Root cause analysis | `output/rca.html` | `rca-holistic` |
| 2 | How to fix | `output/how-to-fix.html` | `how-to-feynman` |

#### Post-completion: vault and memory

**Mandatory after** fix confirmed and deliverables shipped.

| # | Skill | Done when |
|---|-------|-----------|
| 1 | `2ndbrain-knowledge-build` | Applicable vault neighborhood updated if durable **domain** knowledge emerged |
| 2 | `2ndbrain-memory-consolidate` | Episode + lessons in `llm-wiki/` and `.ai/memory/lessons-learned.json` |

Domain vault writes **after** fix confirmation. Agent behavioral lessons via memory consolidation only.

#### RCA acceptance

- Chain: symptom → context fetched → investigation → conclusion
- Cites Slack, vault, or docs where they shortened the path
- Probe evidence for load-bearing claims; rejected routes explained
- If unverified: ≤3 hypotheses with discriminating probes

#### How-to-fix acceptance

- Ordered, executable steps with verification and rollback
- Code/config changes: repo, branch, files, deploy path, success validation

#### Out of scope for UAC

- HTML before investigation
- Markdown-only substitute for `output/*.html` without approval
- Skipping vault/memory when promotable knowledge or lessons exist
