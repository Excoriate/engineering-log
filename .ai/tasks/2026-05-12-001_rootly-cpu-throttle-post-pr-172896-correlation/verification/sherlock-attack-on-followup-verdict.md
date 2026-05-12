---
title: "Sherlock adversarial attack on rca-2026-05-12-followup verdict"
agent: sherlock-holmes
status: complete
summary: |
  Attacked the coordinator's four-claim verdict on four win conditions (W1 wiki→IaC, W2 routing-around-group, W3 user-meant-different, W4 broken probe). Core conclusions (1)+(3)+(4) SURVIVE. Conclusion (2) ("zero prod alerts → user's prod-undersized recall is hollow") is PARTIALLY FALSIFIED: the user-intent reading is under-constrained, and the supporting probe (`oc-probes.md` step 1 final block) uses a non-existent `.attributes.external_url` JSON path, so the "0 prod alerts" filter is structurally vacuous on the API shape the playbook actually queries. Two additional probe defects logged.
task_id: 2026-05-12-001
timestamp: 2026-05-12T13:30:00Z
parent_verdict: ../../../../log/employer/eneco/02_on_call_shift/2026_05_11_rootly_alert_cpu_throtling/rca-2026-05-12-followup.md
---

# Sherlock — adversarial attack on the followup verdict

## Verdict

**VERDICT-PARTIALLY-FALSIFIED.**

The verdict's load-bearing claims (1) "PR 172896 cannot have fixed CPU throttling", (3) "today's alerts are continuation of `ln2I9h`", and (4) "do NOT modify PR 172896; run the live-cluster discriminator" all **SURVIVE** every attack I could mount. Claim (2) — "user's 'prod undersized' recall is unsupported because zero prod alerts in trade-platform" — survives on the **alert-surface** reading but is **falsifiable on two narrower lanes**:

- The supporting verification command in `oc-probes.md` step 1 (the `select(.attributes.external_url | contains("prd.ceap.nl"))` JQ filter) **cannot detect cluster identity** on the Rootly response shape (`external_url` is not a top-level `data.attributes` field on `/v1/alerts` — confirmed by the captured `antecedents/rootly-alert-meta.json`). The L12 playbook line 230 grep-the-raw-body fallback is sound and presumably what actually produced the "0" — but the in-playbook probe at lines 49–52 does NOT reproduce it.
- The "user meant prod-the-environment" reading is plausible but not the only one — the parent RCA H-A is literally "**Suspected undersized CPU budget (regression vs. legacy chart suspected, unverified)**". A user paraphrasing that as "resources on prod were undersized" — using **"prod"** as a colloquial gloss on "the production-class workload" / "the deployed Collector" rather than the prd-the-cluster — is a live alternative the followup never disambiguates. Treating it as falsified without a user-roundtrip is premature.

Net: the **action recommendation** (don't touch the wiki PR; run probes; file capacity PR in MC-VPP-Infrastructure / GitOps) is correct. The **lesson framing** ("the user's recall does not survive the data") is over-confident and should be downgraded to A3 pending one Slack DM.

Plus: one terminology defect (the followup repeatedly says PR 172896 is "merged" / the branch is `rootly`; the actual commits live on `origin/add-how-to-guide-for-alert-routing` and are NOT on `origin/main` as of the local clone HEAD).

---

## Attack lane W1 — does the wiki PR have any path to move an IaC / Helm / k8s surface?

**Probe set executed** (against `/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src-temp/platform-documentation`):

1. `git log origin/main --since="2026-05-07" --pretty=format:"%h %s" --name-status | head -60` → only 4 commits on main (gurobi onboarding + nuget PoC); none are the alert-routing series.
2. `git log --all --oneline --since="2026-05-07"` → finds all 8 commits (`1fb1864` … `bec3c72`) plus `c4d4e8e` and `731a7b2` ("Apply suggestions from code review"). Every one is **on `origin/add-how-to-guide-for-alert-routing`**, **not** on `origin/main` and **not** on `origin/rootly` (the latter is a separate branch).
3. `for c in 1fb1864 f93fd5b 3b2b82a dc8b636 699903a f438009 9abfb10 bec3c72; do git show --stat $c; done` → every commit changes **exactly one file**: `platform-documentation/How-To-Guides/Alert-Routing.md` (early commits) or `internal/How-To-Guides/Alert-Routing.md` (later commits — the path was renamed mid-series; both still single-file diffs). Zero `.yml`, zero `.yaml`, zero `.tf`, zero Helm values, zero kustomization.
4. `find . -type f \( -name '*.tf' -o -name 'values.yaml' -o -name 'Chart.yaml' -o -name 'Deployment*.yaml' -o -name '*.tmpl' -o -name '*.gotmpl' -o -name 'kustomization*' \)` → no matches anywhere in the repo (excluding `.git`).
5. `find . \( -name '.azuredevops' -o -name 'azure-pipelines*' -o -name '*.pipeline.yml' \)` → no matches. No ADO pipeline that consumes wiki markdown into a deployable artifact.
6. `cat .pre-commit-config.yaml` → only `pre-commit-hooks` (trailing-whitespace, end-of-file-fixer, check-yaml, check-added-large-files) and `markdownlint-cli`. Pure formatting; not a templating engine.
7. `git show bec3c72:platform-documentation/How-To-Guides/Alert-Routing.md | head -80` → content is prose plus an **example** `AlertmanagerConfig` YAML embedded in fenced ``` blocks for human reading. No `{{ ... }}` template syntax, no consumer-by directive. Nothing renders this markdown into a cluster manifest.

**Finding.** The wiki repo has zero mechanism (CI, hook, templating engine, kustomize/helm post-render) that could promote a wiki markdown change into a Kubernetes spec. Conclusion (1) of the followup verdict — "**PR 172896 cannot have fixed today's CPU throttling alerts**" — **SURVIVES** with full A1 evidence.

**Secondary find (defect for the followup author):** the followup `rca-2026-05-12-followup.md:22` cites "`git diff --stat` of merged commits on branch `rootly`" as A1. The 8 commits are **not on `origin/rootly`**; they are on `origin/add-how-to-guide-for-alert-routing` and **are NOT yet merged to `origin/main`**. The local-clone HEAD of `origin/main` (commit `a4bd153`, "Add PoC guide for cross-tenant NuGet in ADO") does not contain any `Alert-Routing.md`. This does not change the verdict (the wiki-PR-cannot-fix-capacity argument stands whether the PR is merged or open), but the **evidence label is wrong** ("merged" → "open on `add-how-to-guide-for-alert-routing`") and the **L4 commit table caption** "branch `rootly` merged into `origin/main`" is fabricated. Fix in the followup before promotion to `status: complete`.

---

## Attack lane W2 — could prod CPU/memory throttling page WITHOUT appearing in trade-platform group?

I could not dispatch `mcp__rootly__listAlerts` against the live API from this dispatched context (the prompt says the tool is available; in my actual tool set it is not). I attacked from the captured evidence and the AlertmanagerConfig topology instead.

**Probes executed:**

1. `cat antecedents/rootly-alert-meta.json | jq 'keys'` → top-level attributes of a Rootly alert are `[alert_routing_rule_id, alert_urgency, created_at, ended_at, environments, groups, id, services, short_id, source, started_at, status, summary]`. **No `external_url`**, **no `description`** at this level, no `cluster` field, no environment label, **no `environments[]` populated** for the `ln2I9h` example (it's `[]`).
2. `cat antecedents/rootly-alert-payload.json` (the AlertManager-side webhook body Rootly received) shows `routing_rules[0].id = f4a0e4c1-f2ab-4ee8-8309-21b56db807ad` and `alerting_targets[0]` is the trade-platform EscalationPolicy `1b6ee744-...`. The `receiver` is `eneco-vpp/alertmanagerconfig/rootly-trade-platform` — i.e. **set by the AlertmanagerConfig CR in the `eneco-vpp` namespace of the dev cluster**.
3. The Alert-Routing.md content (W1 probe 7) explicitly documents that each cluster (dev/acc/**prd**) has its own `default-alerting/{cluster}/{namespace}/alertmanagerconfig.yaml` in the `VPP-Configuration` repo, all using the same receiver mapping (`team=trade-platform → rootly-trade-platform`).

**Open hole the coordinator did not close:** assuming prd's AlertmanagerConfig binds `team=trade-platform → rootly-trade-platform` identically (which the wiki documentation does claim), prd CPU throttling on `otc-container` SHOULD route to the trade-platform Rootly group. **BUT**: I cannot verify this without either (a) listing the prd `AlertmanagerConfig` CR live, or (b) running a non-broken Rootly listAlerts cross-group query. The followup itself flags this as **A3 UNVERIFIED** (`rca-2026-05-12-followup.md:24` — "A3 UNVERIFIED whether other Rootly groups paged for prod") and the playbook explicitly punts to the live tool. That's honest — but the TL;DR's "**There is no prod alert in the last 24 h**" is a stronger claim than the underlying evidence supports.

**Plausible W2 falsifiers the playbook should screen for:**
- The prd AlertmanagerConfig binds `team=trade-platform` to a **different receiver** (e.g., `pagerduty-prod` instead of `rootly-trade-platform`), bypassing Rootly entirely on prd. Probe: `oc -n eneco-vpp get alertmanagerconfig -o yaml` on prd, compare to dev.
- Prd alerts have `noise:true` / suppressed status. Probe: Rootly listAlerts with `filter[status]=open,acknowledged,resolved,noise` (the captured probe only filters `status=acknowledged`).
- Prd routes through a sibling group that is NOT `e04f0c98-...`. Probe: Rootly listAlerts with NO `filter[groups]` plus a body-grep for `prd.ceap.nl`.

**Finding.** Conclusion (2) **PARTIALLY FALSIFIED**: not by positive evidence of prod alerts (I have none), but by the fact that the supporting probe in oc-probes.md cannot actually detect cluster identity (see W4) AND three plausible alternative routing paths are unscreened. The right epistemic label is **A3 UNVERIFIED[blocked: cross-group listAlerts + per-cluster alertmanagerconfig probe not executed]**, not the followup's **A1**.

---

## Attack lane W3 — could the user have meant a different subsystem / a different "prod"?

I do NOT have the user's verbatim message about "resources on prod were undersized." There is no `slack-intake.txt` in this incident dir (only `rootly-alert-raw-decoded.txt`, which is the AlertManager payload, not a Slack DM). The followup paraphrases the user once at line 16 ("the user's 'prod undersized' framing") and line 217 ("Resources on prod were undersized").

**Two readings the followup conflates:**

1. **Strict reading:** "prod" = production cluster `apps.eneco-vpp-prd.ceap.nl`. Falsifier = zero prd alerts in trade-platform group last 24 h (partially established; see W2).
2. **Loose reading:** "prod" = production-class workload, the OTel Collector as the trade-platform team deploys it (regardless of env). The parent RCA H-A is verbatim "**Suspected undersized CPU budget (regression vs. legacy chart suspected, unverified)**" — `output/rca.md:440` — and `output/rca.md:312` mentions "anti-pattern in production". A user paraphrasing days later could easily compress "the Collector resources were undersized (it used to have `cpu: 256m / memory: 1Gi` in the legacy Helm chart, the migration to the Operator dropped them)" into "**resources on prod were undersized**" using "prod" as a generic gloss on "what we ship".

The followup commits to reading (1) and concludes the recall doesn't survive — but reading (2) is **directly supported by the parent RCA H-A label** and is **operationally identical to what the followup itself recommends** (file capacity PR in MC-VPP-Infrastructure). On reading (2), the user is RIGHT and the verdict's "either the cohort is wrong or the recall is wrong" framing (`rca-2026-05-12-followup.md:217`) is a false dichotomy.

**Finding.** Conclusion (2) **PARTIALLY FALSIFIED on user-intent grounds.** The followup should either (a) capture the user's exact wording (Slack scroll-back) and resolve the strict-vs-loose ambiguity, or (b) downgrade the L10 lesson 4 ("Recall framing must be challenged") to "Confirm with @atorres.ruiz which env / which workload he meant by 'prod' before treating either reading as load-bearing." The current text reads as a stronger debunk than the data permits and burns trust if the user actually meant reading (2).

---

## Attack lane W4 — broken / under-specified probe commands in `oc-probes.md`

**Defect W4-1 — the prod-count JQ filter cannot match cluster identity.** `oc-probes.md:49–52`:
```bash
curl ... "https://api.rootly.com/v1/alerts?filter[groups]=${TRADE_PLATFORM_GROUP_ID}&filter[started_at][gte]=$(date -u -v-24H +%Y-%m-%dT%H:%M:%SZ)" \
  | jq '[.data[] | select(.attributes.external_url | contains("prd.ceap.nl"))] | length'
```
The captured `antecedents/rootly-alert-meta.json` is the **exact response shape** of `/v1/alerts` and has no `.attributes.external_url` field (the cluster URL is buried in `data.alerts[].generatorURL` inside the webhook payload, not surfaced at the top of the Rootly API response, and in `alert_fields[]` keyed by UUIDs `fd42a8bc-...`/`5d772678-...`). The JQ `select(.attributes.external_url | contains(...))` returns no matches **because the field is null on every alert**, not because no prod alerts exist. The count `0` is **vacuously true** as written.

Fix shape:
```bash
curl ... | jq '[.data[] | select(.attributes.summary // "" | tostring) | select((.. | strings? | contains("prd.ceap.nl")))] | length'
```
or the simpler raw-body approach the L12 playbook line 230 already uses (`grep -c "prd.ceap.nl"`). Followup's TL;DR claim of "zero prod alerts" only holds if the latter was actually run; the in-playbook command as written cannot reproduce it.

**Defect W4-2 — the H-B PromQL probes a 12 h window but the confirmation rule says "May 1–12".** `oc-probes.md:108–112`:
```promql
max_over_time(
  (container_memory_working_set_bytes{namespace="eneco-vpp",container="otc-container"} /
   container_spec_memory_limit_bytes{namespace="eneco-vpp",container="otc-container"})[12h:1m]
)
```
Confirmation rule at line 115: "**monotonic memory growth across May 1–12**". A 12 h subquery cannot show a 12-day trend. Fix: change subquery range to `[12d:5m]` (or use `container_memory_working_set_bytes[12d]` as the outer range vector) and increase the step to stay under default scrape-buffer limits.

**Defect W4-3 — Step 9 PATCH endpoint requires a UUID but the playbook does not surface the `short_id → id` mapping.** `oc-probes.md:189–191`:
```bash
curl ... -X PATCH "https://api.rootly.com/v1/alerts/ea1bea42-8e22-4549-a364-fc31ae80b1b4" \
  -d '{"data": {"type": "alerts", "attributes": {"status": "resolved"}}}'
```
The UUID `ea1bea42-...` is hard-coded for `bF0Rn7`. An engineer running the playbook fresh on a different short_id has no documented step to retrieve the long UUID. The captured `rootly-alert-meta.json:2` has `"id": null` (the API actually returns `id` on the data root, not under attributes — the capture script in the antecedents flattens it), so the lookup pattern would be: `curl ... /v1/alerts/${SHORT_ID} | jq -r '.data.id'`. Add this as Step 9.0.

**Defect W4-4 — alert-survey misses non-acknowledged open alerts on dev.** `oc-probes.md:45–47`:
```bash
curl ... "https://api.rootly.com/v1/alerts?filter[groups]=${TRADE_PLATFORM_GROUP_ID}&filter[status]=acknowledged"
```
Filters only `acknowledged`. A `triggered` (not-yet-touched) alert from the same incident class would be invisible. For an on-call playbook the filter should be `filter[status]=triggered,acknowledged` (CSV). Otherwise the next on-call who runs this against a fresh page will miss the live alert.

**Defect W4-5 (minor) — Step 2 `--sort-by=.status.startTime` returns the oldest-first slice when followed by `{.items[-1:].metadata.name}`.** Actually correct (last item = newest after ascending sort). No fix; logging for completeness.

**Defect W4-6 (minor) — Step 3a `yq '.items[].spec'`** assumes a List shape but if there's exactly one OTel CR in the namespace it's still a List from `oc get OpenTelemetryCollector`, so OK. No fix.

**Finding.** Four real probe defects (W4-1 through W4-4); the verdict's recommended-action remains executable but the playbook needs surgical fixes before it's a clean handover artifact. None of these defects bend the verdict itself.

---

## Receipts for the coordinator

Per `.claude/rules/governance/adversarial-dispatch-discipline.md`:

| Finding | Receipt | Evidence |
|---------|---------|----------|
| Conclusion (1) — wiki PR cannot have fixed CPU throttling | **REBUT** (verdict survives) | W1 probes 1–7. `git show --stat` for all 8 commits = single-markdown-file diffs; zero CI/templating in `platform-documentation` repo; markdownlint-only pre-commit. |
| Conclusion (3) — today's alerts are continuation of yesterday's `ln2I9h` | **REBUT** (verdict survives) | Same container/namespace/rule confirmed via captured Rootly timeline in followup L7; my role didn't widen this. |
| Conclusion (4) — recommended action (don't touch PR, run probes, file capacity PR in MC-VPP-Infrastructure / GitOps) | **REBUT** (verdict survives) | Routing topology in W2 evidence: capacity changes land where the CR is reconciled, not in the wiki repo. |
| Conclusion (2) — "user's 'prod undersized' recall is hollow because zero prod alerts" | **DEFER** | W2: probe to detect cross-group / non-trade-platform-group prod alerts not executed. W3: user-intent reading (loose "prod" = production-class workload, not prd-the-cluster) is not disambiguated. Downgrade A1 → A3 UNVERIFIED until: (a) Rootly cross-group query rules out prod surface, AND (b) user roundtrip confirms which "prod" was meant. |
| Followup TL;DR / L4 / verdict-table evidence cell "merged on branch `rootly`" | **RESOLVE** (factual fix needed) | The 8 commits are on `origin/add-how-to-guide-for-alert-routing` and not on `origin/main`. Replace "merged" with "open on `add-how-to-guide-for-alert-routing`" wherever it appears; replace branch name `rootly` (a different unrelated branch). |
| oc-probes.md step 1 prod-count JQ filter (W4-1) | **RESOLVE** | Field `.attributes.external_url` does not exist on `/v1/alerts` response shape (captured `rootly-alert-meta.json`). Replace with raw-body grep or alert_fields walk. |
| oc-probes.md H-B PromQL window mismatch (W4-2) | **RESOLVE** | Subquery `[12h:1m]` cannot evaluate "May 1–12" confirmation rule. Change to `[12d:5m]` or similar. |
| oc-probes.md step 9 missing short_id → id lookup (W4-3) | **RESOLVE** | Add `curl .../v1/alerts/${SHORT_ID} \| jq -r '.data.id'` as step 9.0 to make the playbook reproducible for any future alert. |
| oc-probes.md alert-survey filter only `acknowledged` (W4-4) | **RESOLVE** | Add `triggered` to the status filter so the next on-call doesn't miss fresh pages. |

---

## What I did NOT attack (out of scope or already covered upstream)

- The four hypotheses (H-A/H-B/H-C/H-D) — already adversarially reviewed in the parent RCA antecedents (`socrates-framing-attack.md`, `sherlock-diagnosis-attack.md`).
- The `bF0Rn7` short_id correctness — surfaced live via Rootly tool by coordinator; no contradictory evidence in captured artifacts.
- The "13 memory alerts overnight" count — would require widening Rootly listAlerts which my dispatched context cannot do; coordinator's L7 timeline is internally consistent.
- Whether the user (Mr. Alex) authorized the PR-172896 reference in the first place — that's the parent task's framing, not in scope here.
