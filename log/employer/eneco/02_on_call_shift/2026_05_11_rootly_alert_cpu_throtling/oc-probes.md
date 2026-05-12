---
title: "Operational command playbook — discriminate today's otc-container CPUThrottlingHigh recurrence"
status: review
agent: claude-code-coordinator
summary: Copy-paste commands to (1) reproduce today's alert survey, (2) probe H-A/H-B/H-C/H-D on the live cluster, (3) clear the still-open dev alert in Rootly, (4) shape the eventual capacity PR.
parent_rca: ./output/rca.md
followup_rca: ./rca-2026-05-12-followup.md
date: 2026-05-12
task_id: 2026-05-12-001
---

# `oc-probes.md` — live commands to discriminate hypotheses and clear `bF0Rn7`

> **Read first**: [`./rca-2026-05-12-followup.md`](./rca-2026-05-12-followup.md). Verdict is "do NOT improve PR 172896; run these probes; ship the actual capacity / config PR in the IaC repo." All commands are read-only EXCEPT step 9 (Rootly resolve) and the eventual PR in step 8.

## 0. Conventions

```bash
# Pod names captured at 2026-05-12T11:00Z — re-derive if a roll happens.
DEV_POD="opentelemetry-collector-collector-58d5f587f5-92vpd"   # currently throttling, ack-not-resolved (bF0Rn7)
ACC_POD="opentelemetry-collector-collector-86ccc5cb4-wbr97"    # acc throttling pod
NS="eneco-vpp"
LOW_URGENCY_ID="8824cd16-edb5-4bc3-8d0b-0ab833b1a8ac"
MEM_URGENCY_ID="0ef2c622-8ccb-468d-8bfe-1d2401b6374d"
TRADE_PLATFORM_GROUP_ID="e04f0c98-bbf4-4d92-a534-8883172d56cd"
```

> The current `oc` context must point at the cluster you are probing. The OTel Collector lives in different clusters per env: `apps.eneco-vpp-dev.ceap.nl`, `apps.eneco-vpp-acc.ceap.nl`, `apps.eneco-vpp-prd.ceap.nl`.

---

## 1. Reproduce today's alert survey (Rootly)

Replays this RCA's L7 timeline (no auth needed beyond the configured Rootly MCP or Rootly API token).

```bash
# All trade-platform alerts since midnight UTC today.
# IMPORTANT: include external_url in fields[alerts] explicitly — the API default omits it.
curl -sS -H "Authorization: Bearer ${ROOTLY_API_TOKEN}" \
  "https://api.rootly.com/v1/alerts?filter[groups]=${TRADE_PLATFORM_GROUP_ID}&filter[started_at][gte]=2026-05-12T00:00:00Z&page[size]=20&fields[alerts]=short_id,summary,status,started_at,ended_at,description,external_url" \
  | jq -r '.data[].attributes |
    [.short_id, .summary, .status, .started_at, .external_url,
     (.description | capture("namespace (?<ns>[a-z-]+) for container (?<c>[a-z-]+) in pod (?<p>[a-z0-9-]+)") // {ns:"-",c:"-",p:"-"} | "\(.ns)\t\(.c)\t\(.p)")] | @tsv'

# Live (not-yet-resolved) alerts on the group — triggered AND acknowledged.
curl -sS -H "Authorization: Bearer ${ROOTLY_API_TOKEN}" \
  "https://api.rootly.com/v1/alerts?filter[groups]=${TRADE_PLATFORM_GROUP_ID}&filter[status]=triggered,acknowledged&fields[alerts]=short_id,status,started_at,description,external_url" \
  | jq -r '.data[].attributes | [.short_id, .status, .started_at, .external_url, .description] | @tsv'

# Sanity: any prd-cluster alerts in the past 24h? (expected at write time: 0)
# Two methods — run BOTH and confirm agreement.
# (a) Structured: require external_url to contain prd.ceap.nl AND ensure the field is present.
curl -sS -H "Authorization: Bearer ${ROOTLY_API_TOKEN}" \
  "https://api.rootly.com/v1/alerts?filter[groups]=${TRADE_PLATFORM_GROUP_ID}&filter[started_at][gte]=$(date -u -v-24H +%Y-%m-%dT%H:%M:%SZ)&fields[alerts]=short_id,external_url,description" \
  | jq '[.data[] | select((.attributes.external_url // "") | contains("prd.ceap.nl"))] | length'
# (b) Raw-body grep fallback — survives field-renames and label changes.
curl -sS -H "Authorization: Bearer ${ROOTLY_API_TOKEN}" \
  "https://api.rootly.com/v1/alerts?filter[groups]=${TRADE_PLATFORM_GROUP_ID}&filter[started_at][gte]=$(date -u -v-24H +%Y-%m-%dT%H:%M:%SZ)" \
  | grep -c "prd.ceap.nl"

# Anti-blindspot: also list all groups the user is a member of so the on-call can spot prd alerts on a SIBLING group.
curl -sS -H "Authorization: Bearer ${ROOTLY_API_TOKEN}" \
  "https://api.rootly.com/v1/alerts?filter[started_at][gte]=$(date -u -v-24H +%Y-%m-%dT%H:%M:%SZ)&fields[alerts]=short_id,description,external_url&page[size]=50" \
  | jq -r '.data[] | select(((.attributes.external_url // "") | contains("prd.ceap.nl")) or ((.attributes.description // "") | contains("prd.ceap.nl"))) | .attributes | [.short_id, .external_url, .description] | @tsv'
```

If method (a) and (b) disagree, **method (b) is the truth** and method (a) has a field-name regression — open a Rootly support ticket. If the **prod count is > 0 on either method**, the parent verdict needs revisiting — the user's "prod undersized" framing is then re-armed under the strict-cluster reading.

---

## 2. Refresh pod identity before probing (the pod may have rolled)

```bash
oc -n "$NS" get pods -l app.kubernetes.io/instance=opentelemetry-collector \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\t"}{.status.startTime}{"\n"}{end}'

# Capture the freshest pod into DEV_POD / ACC_POD before probing.
DEV_POD=$(oc -n "$NS" get pods -l app.kubernetes.io/instance=opentelemetry-collector \
  --sort-by=.status.startTime -o jsonpath='{.items[-1:].metadata.name}')
echo "DEV_POD=$DEV_POD"
```

---

## 3. H-A — read effective CPU/memory limits on the live CR

```bash
# Step 3a: the CR's declared resources (authoritative if non-empty)
oc -n "$NS" get OpenTelemetryCollector -o yaml \
  | yq '.items[].spec | {name: .name, resources: .resources}'

# Step 3b: the pod's effective limits + recent events
oc -n "$NS" describe pod "$DEV_POD" \
  | sed -n '/Limits:/,/Requests:/p; /Events:/,$p'

# Step 3c: namespace LimitRange (may override or impose floors)
oc -n "$NS" get limitrange -o yaml

# Step 3d: actual usage right now
oc -n "$NS" adm top pod "$DEV_POD" --containers
```

**Confirms H-A if**: CR omits `spec.resources` OR effective `cpu` limit is at/under measured peak from step 3d. **Falsifies H-A if**: limit is well above peak.

Legacy chart baseline for reference (A2 from parent RCA L5): `cpu: 256m / memory: 1Gi`.

---

## 4. H-B — memory trend (preceded today's CPU on dev)

Run from the OpenShift console or any Prometheus client pointed at the cluster:

```promql
# 14-day memory working set per pod
container_memory_working_set_bytes{namespace="eneco-vpp",pod=~"opentelemetry-collector-collector-.*",container="otc-container"}

# CPU rate alongside, to spot GC-induced bursts
rate(process_cpu_seconds_total{namespace="eneco-vpp",pod=~"opentelemetry-collector-collector-.*"}[5m])

# 12-day ratio of working_set to limit — supports the "May 1-12 monotonic growth" check
max_over_time(
  (container_memory_working_set_bytes{namespace="eneco-vpp",container="otc-container"} /
   container_spec_memory_limit_bytes{namespace="eneco-vpp",container="otc-container"})[12d:5m]
)

# Same window, but as the raw working set in bytes — pair with the above to spot growth in absolute terms
max_over_time(
  container_memory_working_set_bytes{namespace="eneco-vpp",container="otc-container"}[12d:5m]
)
```

**Confirms H-B if**: monotonic memory growth across May 1–12 in the 12-day window AND CPU spikes coincident with apparent GC cycles in the same series. **Falsifies H-B if**: memory is flat between days. (If your Prometheus retention is <12d, fall back to `[Nd:5m]` where N = retention − 1, and reduce the confirmation horizon.)

---

## 5. H-C — is the rule itself mis-calibrated for sidecar / observability workloads?

```promql
# Cluster-wide firing of CPUThrottlingHigh by container class
sum by (container) ( ALERTS{alertname="CPUThrottlingHigh", alertstate="firing"} )

# Which workloads have CFS-throttled > 25% in the last hour?
topk(20,
  sum by (namespace, container, pod) (
    rate(container_cpu_cfs_throttled_periods_total{container!=""}[1h])
  ) /
  sum by (namespace, container, pod) (
    rate(container_cpu_cfs_periods_total[1h])
  )
)
```

**Confirms H-C if**: observability-class containers (`otc-container`, `fluentd`, exporters) systematically fire cluster-wide. **Falsifies H-C if**: only this Deployment is anomalous.

---

## 6. H-D — debug exporter verbose in active pipeline

```bash
oc -n "$NS" get OpenTelemetryCollector -o yaml \
  | yq '.items[].spec.config |
        {exporters: .exporters, pipelines: .service.pipelines}'
```

**Confirms H-D if**: `debug.verbosity: detailed` is set AND `debug` is in any pipeline's `exporters:` list. **Falsifies H-D if**: `verbosity: basic` or `debug` not in any active pipeline.

---

## 7. Cross-check: which cluster is THIS context pointing at?

```bash
oc whoami --show-server
oc config current-context
```

If the answer is a `dev` URL you are NOT probing prod — re-target before any prod claim.

### 7b. Compare prd vs dev AlertmanagerConfig — is prod actually wired to the trade-platform Rootly group?

Sherlock W2 surfaced an unprobed lane: prd could be routing alerts to a different receiver (PagerDuty, a different Rootly group), which would silently explain "no prod alerts" without proving prod is healthy. Compare the two CRs.

```bash
# On dev cluster context
oc -n eneco-vpp get alertmanagerconfig rootly-trade-platform -o yaml > /tmp/amc-dev.yaml

# Switch to prd context, then:
oc -n eneco-vpp get alertmanagerconfig rootly-trade-platform -o yaml > /tmp/amc-prd.yaml

# Or list every alertmanagerconfig on prd's eneco-vpp namespace
oc -n eneco-vpp get alertmanagerconfig -o yaml

diff /tmp/amc-dev.yaml /tmp/amc-prd.yaml | head -80
```

**Confirms identical routing if**: diff shows only metadata (resourceVersion / uid / creation timestamps). **Surfaces a W2 falsifier if**: the `route.receiver` or `receivers[].webhookConfigs[].url` differs between envs.

---

## 8. Locate the GitOps app that owns the CR (so the fix lands in the right repo)

```bash
# Owner references on the CR (operator vs. ArgoCD vs. imperatively applied)
oc -n "$NS" get OpenTelemetryCollector -o yaml \
  | yq '.items[].metadata | {name, ownerReferences, annotations}' \
  | grep -E 'argocd.argoproj.io|app.kubernetes.io|owner'

# If an ArgoCD app manages it, find that app in either cluster's argocd ns
oc get applications.argoproj.io -A \
  -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\t"}{.spec.source.repoURL}{"\t"}{.spec.source.path}{"\n"}{end}' \
  | grep -iE 'otel|opentelemetry|telemetry'
```

The `repoURL` from the matching application **is the repo where the capacity PR must land**. It is **not** `platform-documentation`.

---

## 9. Clear the still-open dev alert `bF0Rn7` (and any future short_id) once probes have run

> Do this AFTER step 3 captures the evidence — Rootly will lose acknowledged-state context once resolved.

The PATCH endpoint needs the **alert UUID**, not the `short_id`. Look it up first:

```bash
SHORT_ID="bF0Rn7"    # change for future runs
ALERT_UUID=$(curl -sS -H "Authorization: Bearer ${ROOTLY_API_TOKEN}" \
  "https://api.rootly.com/v1/alerts?filter[short_id]=${SHORT_ID}&fields[alerts]=short_id" \
  | jq -r '.data[0].id')
echo "Resolving SHORT_ID=${SHORT_ID} UUID=${ALERT_UUID}"
test -n "$ALERT_UUID" -a "$ALERT_UUID" != "null" || { echo "lookup failed"; exit 1; }

curl -sS -X PATCH \
  -H "Authorization: Bearer ${ROOTLY_API_TOKEN}" \
  -H "Content-Type: application/vnd.api+json" \
  "https://api.rootly.com/v1/alerts/${ALERT_UUID}" \
  -d '{"data": {"type": "alerts", "attributes": {"status": "resolved"}}}'
```

For `bF0Rn7` specifically at write time the UUID was `ea1bea42-8e22-4549-a364-fc31ae80b1b4` (A1 from `get_alert_by_short_id`). The lookup above re-derives it so the playbook works on any future short_id.

Or via UI: <https://rootly.com/account/alerts/bF0Rn7> → Resolve.

---

## 10. After the probes — three actions, in order

1. Write the discriminator findings (which of H-A/H-B/H-C/H-D is confirmed) into the parent RCA `./output/rca.md` L9 and promote it to `status: complete`.
2. File the **capacity / config PR in the right repo** identified in step 8 — almost certainly `MC-VPP-Infrastructure` or the GitOps repo. Sizing input comes from step 3d / step 4.
3. Add a follow-up lesson to `.ai/memory/lessons-learned.json`: "Repo-class is the cheapest probe when a PR-supposed-to-fix-X did not fix X — `git diff --stat` of the merged commits answers in one second."

---

## Falsifier — when this verdict is wrong

This entire RCA + probe set rests on the premise that **PR 172896 only changes `internal/How-To-Guides/Alert-Routing.md`**, **on a feature branch**, **with no CI consumer that templates k8s manifests from wiki markdown**. Verify locally — these three commands together cover all three premises:

```bash
cd /Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src-temp/platform-documentation && \
  git fetch origin

# Premise 1: only the wiki markdown is touched across the PR's commits
git log origin/add-how-to-guide-for-alert-routing --not origin/main --pretty=format:"%h %s" --name-status | head -40

# Premise 2: PR is open (not merged to main)
git merge-base --is-ancestor $(git rev-parse origin/add-how-to-guide-for-alert-routing) origin/main \
  && echo "MERGED — verdict needs revisiting" \
  || echo "OPEN — verdict stands"

# Premise 3: no IaC templating engine consumes the wiki repo
find . \( -name '*.tf' -o -name 'values.yaml' -o -name 'Chart.yaml' \
       -o -name 'azure-pipelines*' -o -name '*.gotmpl' -o -name 'kustomization*' \) \
       -not -path './.git/*'
```

If any of (1) shows non-`Alert-Routing.md` files, (2) the merge-base check reports MERGED, or (3) the find returns matches, the verdict needs revisiting. **Today's evidence shows none of these.**
