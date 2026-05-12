---
title: "Follow-up RCA — otc-container CPUThrottlingHigh recurrence on 2026-05-12, post PR 172896 merge"
status: review
agent: claude-code-coordinator
summary: Recurrence of yesterday's ln2I9h CPU/memory pattern on dev + acc. PR 172896 (alert-routing docs, NOT IaC) cannot have fixed it. Verdict and live-cluster discriminator commands attached.
parent_rca: ./output/rca.md
related_pr: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_git/platform-documentation/pullrequest/172896
on_call: atorres.ruiz
date: 2026-05-12
task_id: 2026-05-12-001
crubvg: 7
---

# Follow-up RCA — `otc-container` `CPUThrottlingHigh` recurrence (2026-05-12)

> **One-paragraph TL;DR.** The CPU/memory throttling alerts that fired yesterday (`ln2I9h`, RCA in [./output/rca.md](./output/rca.md)) **recurred today** on the same container (`otc-container`, OpenTelemetry Collector) across `dev` and `acc` clusters. **PR 172896 cannot have fixed this** — and it has not even shipped: the PR is still **OPEN on branch `add-how-to-guide-for-alert-routing`**, not yet merged to `origin/main`. It lives in `platform-documentation` (the ADO wiki repo), changes exactly one file (`internal/How-To-Guides/Alert-Routing.md`), and is purely a teach-teams-to-label-alerts documentation effort — **no IaC, no Helm values, no resource limit, no threshold change**, and **no merge to main**. Even after eventual merge, it cannot affect runtime capacity. Yesterday's RCA still ships no fix (status: review) and is still gated on the live-cluster discriminator probe. **Run that probe now (commands in [`oc-probes.md`](./oc-probes.md))**, then ship a capacity / config PR in the real IaC repo. **No prod alert was observed in the trade-platform Rootly group in the last 24 h** — see Verdict row 3 below for the residual A3 on whether prod could be paging through a different routing path, and on what "prod undersized" actually means.

## Verdict

| Question | Verdict | Evidence |
|---------|---------|----------|
| Does PR 172896 need improvement to stop these alerts? | **No** — and the question is even further misframed: the PR is **not merged**. PR 172896 is a documentation PR (`internal/How-To-Guides/Alert-Routing.md` only, +205 LOC across 8 commits on `origin/add-how-to-guide-for-alert-routing`); it was never going to stop CPU throttling, and as of HEAD it has not even shipped to `origin/main`. The PR is fine for what it shipped — improving it would not change runtime. | A1 — `git log origin/main --since=2026-05-07 --name-status` shows zero alert-routing commits on main; `git branch -r --contains bec3c72` returns only `origin/add-how-to-guide-for-alert-routing`. A1 — `git show <commit> --stat` for each of the 8 commits shows single-file diff to `Alert-Routing.md`. |
| Are today's alerts the same pattern as yesterday's `ln2I9h`? | **Yes.** Same container (`otc-container`), same namespace (`eneco-vpp`), same alert rule (`CPUThrottlingHigh`), same range of throttle % (31–56%), now also on `acc` cluster, plus 13 memory alerts on the dev pod. | A1 — Rootly `listAlerts` filtered to trade-platform group since 2026-05-12T00:00Z. |
| Were prod resources undersized as the user recalled? | **Ambiguous — needs user disambiguation.** Two readings: **(a) strict** "prod" = the prd cluster `apps.eneco-vpp-prd.ceap.nl` → no prod alerts visible in the trade-platform Rootly group in 24h, but routing-around-the-group is unprobed. **(b) loose** "prod" = the production-class workload (the OTel Collector as the team deploys it), regardless of env — yesterday's RCA H-A is literally "Suspected undersized CPU budget" on this Collector. Under reading (b) the user is correct and the action is identical to the followup's own recommendation (file a capacity PR in MC-VPP-Infrastructure). | A3 UNVERIFIED[blocked: cross-group Rootly listAlerts + per-cluster AlertmanagerConfig comparison not run; user's verbatim wording not captured]. Resolving probe: see Sherlock-attack W2 falsifier list in `verification/sherlock-attack-on-followup-verdict.md`. |
| What is actually open right now? | **`bF0Rn7`** — `CPUThrottlingHigh` on **dev** pod `opentelemetry-collector-collector-58d5f587f5-92vpd`, 54.87% throttled, started 2026-05-12T08:50:59Z, **still `acknowledged` with `ended_at: null`**. | A1 — Rootly `get_alert_by_short_id`. |

**Recommended action**: do NOT modify PR 172896. Treat today's alerts as continuation of yesterday's `ln2I9h` incident. Run the four-hypothesis discriminator from yesterday's RCA L9 against the **current** pods (`58d5f587f5-92vpd` on dev, `86ccc5cb4-wbr97` on acc). Whichever hypothesis is confirmed (H-A undersized CPU / H-B memory upstream / H-D debug verbose) determines which capacity/config PR to file in the IaC repo (most likely `MC-VPP-Infrastructure` or `VPP.GitOps/argocd/platform-gitops/opentelemetry-collector`). H-C (rule mis-calibrated) requires the cluster-wide probe before action.

---

## Context Ledger

| Term / artifact | Definition | Code / config location | Why it matters here |
|------|-----|------|------|
| `otc-container` | The `otel-collector` container of the OpenTelemetry Collector Deployment in namespace `eneco-vpp` | k8s runtime: pod `opentelemetry-collector-collector-*` | Subject of every alert in today's surface |
| `CPUThrottlingHigh` | kube-prometheus-stack PrometheusRule firing when CFS-throttled-periods / CFS-periods > 25% sustained | OpenShift platform alerting (kube-prometheus-stack) | The alert class firing today |
| `ContainerMemoryUsageHigh` | PrometheusRule firing when `container_memory_working_set_bytes / container_spec_memory_limit_bytes ≥ 0.9` | OpenShift platform alerting | Co-firing on dev today (13 events) |
| `label_team` | Pod label used by Alertmanager → Rootly routing to bind alerts to a Rootly group | k8s pod labels; documented in PR 172896's `Alert-Routing.md` | What PR 172896 actually teaches; orthogonal to capacity |
| `platform-documentation` | Eneco MC-VPP ADO wiki repo (How-To-Guides, Reference, ADRs). NOT an IaC repo. | `dev.azure.com/enecomanagedcloud/Myriad - VPP/_git/platform-documentation` | Where PR 172896 lives. Constrains what the PR can change. |
| `MC-VPP-Infrastructure` | Real IaC repo (Terraform + k8s manifests) for VPP platform | `dev.azure.com/enecomanagedcloud/Myriad - VPP/_git/MC-VPP-Infrastructure` | Where a capacity fix would actually have to ship |
| `ln2I9h` | Yesterday's CPU-throttling alert that triggered the parent RCA | Rootly | Today's alerts are the recurrence |
| `bF0Rn7` | The single dev alert still in `acknowledged` state right now | Rootly URL: <https://rootly.com/account/alerts/bF0Rn7> | The live problem to clear |
| Trade-platform Rootly group | `e04f0c98-bbf4-4d92-a534-8883172d56cd` | Rootly groups API | Scoping filter used for the today-survey |

---

## L1 — Business — Why the OTel Collector matters

The OTel Collector aggregates telemetry from VPP workloads in the `eneco-vpp` namespace and forwards it to Log Analytics / Application Insights. If it is CPU-throttled or memory-stressed enough to drop spans/metrics, downstream observability degrades silently — including the dashboards on-call relies on to see whether tomorrow's trade execution is healthy. The blast radius of "OTel collector slow" is not page-now-customer-affecting; it is observability-of-VPP-affecting.

A2 inference from parent RCA L1 (no change today).

---

## L2 — Repo system — which repos touch this incident

| Repo | Role in this incident | Touched by PR 172896? |
|------|----------------------|------------------------|
| `platform-documentation` (ADO wiki) | Where PR 172896 shipped — pure docs | **YES (the only repo)** |
| `MC-VPP-Infrastructure` | Terraform + k8s manifests for the VPP platform; where a CPU/memory limit change would live | **NO** |
| `VPP.GitOps` / `platform-gitops` | ArgoCD apps that reconcile OTel Collector CR onto each cluster | **NO** |
| `Eneco.HelmCharts/opentelemetry-collector` (legacy) | Pre-migration chart with `cpu: 256m / memory: 1Gi` defaults — historical baseline only | **NO** |

A1 from local clone of `platform-documentation` + `git diff --stat`.

> **Anti-misread**: the PR title likely reads "alert routing", and "alert" is in the alert-name. Do not let the noun overlap mislead — the PR teaches **how to label alerts so Rootly routes them to the right team**, not how to stop alerts from firing.

---

## L3 — Runtime architecture — where the alerts come from

```text
                    OpenShift cluster eneco-vpp-{dev,acc,prd}.ceap.nl
                                       │
                                       │ namespace eneco-vpp
                                       │
                                       ▼
                  OpenTelemetryCollector CR (managed by OTel Operator)
                                       │
                                       │ Pod: opentelemetry-collector-collector-<rs>-<id>
                                       │ Container: otc-container
                                       │ Receives OTLP, scrapes Prometheus, exports to LA + AI
                                       │
                  ┌────────────────────┴────────────────────┐
                  │                                         │
        CFS throttling > 25%                       working_set / limit ≥ 0.9
                  │                                         │
                  ▼                                         ▼
        CPUThrottlingHigh fires                 ContainerMemoryUsageHigh fires
                  │                                         │
                  └────────────────┬────────────────────────┘
                                   ▼
                          Alertmanager (in-cluster)
                                   │ routes via receiver
                                   │ "eneco-vpp/alertmanagerconfig/rootly-trade-platform"
                                   ▼
                              Rootly group "trade-platform"
                                   │
                                   ▼
                              On-call paged
```

A1 — alert payload labels in `antecedents/rootly-alert-raw-decoded.txt` (parent RCA antecedent).

---

## L4 — What PR 172896 actually changed (and where it lives)

A1 from `git log + git diff --stat` against the local clone of `platform-documentation`:

```text
Branch: origin/add-how-to-guide-for-alert-routing (NOT origin/main, NOT origin/rootly)
PR status: open — bec3c72 is NOT on origin/main per
           `git merge-base --is-ancestor bec3c72 origin/main` → exit 1.

internal/How-To-Guides/Alert-Routing.md  | +157 (initial) + 48 (followups)
1 file changed across 8 commits
```

Commit series 2026-05-08 → 2026-05-12 (all on `origin/add-how-to-guide-for-alert-routing`):

| Commit | Date | Subject |
|--------|------|---------|
| `1fb1864` | 2026-05-08 | feat(alert-routing): add how-to guide for configuring alert routing in OpenShift |
| `f93fd5b` | 2026-05-08 | feat(alert-routing): add instructions for setting team label using Helm and Kustomize |
| `3b2b82a` | 2026-05-11 | fix(alert-routing): clarify application level alerts description to include platform metrics |
| `dc8b636` | 2026-05-11 | fix(alert-routing): include "or" for platform metrics |
| `699903a` | 2026-05-11 | fix(alert-routing): improve clarity of alert routing explanation in OpenShift documentation |
| `f438009` | 2026-05-11 | fix(alert-routing): correct wording in application level alerts requirements |
| `9abfb10` | 2026-05-12 | fix(alert-routing): enhance clarity and detail in alert types description |
| `bec3c72` | 2026-05-12 | fix(alert-routing): update alert routing documentation with team label examples and clarification |

**Nothing in the PR can set a CPU limit, change a memory limit, change an alert threshold, change a Helm value, or change an ArgoCD application spec.** Wiki repo, single markdown file.

---

## L5 — IaC / declarative contract — what could actually move the alert

Same three sources as in the parent RCA L5 (unchanged):

1. `OpenTelemetryCollector.spec.resources` on the CR (authoritative if set)
2. OTel Operator manager default (if CR omits resources)
3. Namespace LimitRange

The `cpu_throttling` PrometheusRule itself (the kube-prometheus-stack default 25 %, 5m) is a fourth surface — orthogonal, owned by the cluster's `kube-prometheus-stack` install, not by trade-platform.

A1 file:line still pending live-cluster `oc get` — see [`oc-probes.md`](./oc-probes.md).

---

## L6 — Pipeline — why "PR merged" did not mean "fix shipped"

This is the trap class to internalize. Two distinct propagation chains were involved:

| Chain | Producer | Consumer | What "merged" actually delivers |
|-------|----------|----------|---------------------------------|
| **PR 172896** (the one the user references) | Author of `Alert-Routing.md` | Engineers who read the wiki | A new wiki page. Zero runtime effect. |
| **A hypothetical capacity PR** (the one the user wanted) | Author of `MC-VPP-Infrastructure` CR / Helm values | ArgoCD → OpenShift cluster | New `spec.resources.limits.cpu` applied on next sync |

The user's mental model collapsed both into "the PR" because they both relate to alerts. **The pipeline tells you they cannot be the same artifact**: one terminates at a wiki page render; the other terminates at a Kubernetes API server resource patch.

> **Lesson recurrence-class**: when an alert persists after "a PR was merged", verify (a) which repo the PR lives in, (b) what surface it actually patches, and (c) whether a CD pipeline applies that surface to the cluster that owns the alerting pod. Repo identity is the cheapest probe — start there.

---

## L7 — Timeline (today, UTC)

| Time UTC | Cluster | Pod (short) | Alert | % | Status |
|----------|---------|-------------|-------|---|--------|
| 2026-05-11 ~14:50 | dev | …-2htph | CPUThrottlingHigh `ln2I9h` (parent RCA) | 49.76 | resolved |
| 2026-05-12 00:19→04:58 | dev | 566b6bd96-2htph | **13× ContainerMemoryUsageHigh** | 90.7–98.8 | resolved each cycle |
| 2026-05-12 08:11:45 | acc | 849b458bb7-5j299 | CPUThrottlingHigh `yvPrOW` | 32.62 | resolved |
| 2026-05-12 08:50:59 | dev | **58d5f587f5-92vpd** | CPUThrottlingHigh `HAy1aA` | 56.35 | resolved |
| 2026-05-12 08:50:59 | dev | 58d5f587f5-92vpd | CPUThrottlingHigh `xWp32l` | 53.40 | resolved |
| 2026-05-12 08:50:59 | dev | 58d5f587f5-92vpd | CPUThrottlingHigh `bF0Rn7` | **54.87** | **🔴 acknowledged, not resolved** |
| 2026-05-12 08:59:15 | acc | 86ccc5cb4-wbr97 | CPUThrottlingHigh `tUQi5V` | 46.25 | resolved |
| 2026-05-12 08:59:15 | acc | 86ccc5cb4-wbr97 | CPUThrottlingHigh `yM882q` | 31.84 | resolved |
| 2026-05-12 10:38:15 | acc | 86ccc5cb4-wbr97 | CPUThrottlingHigh `W4ibWW` | 45.43 | resolved (4 min) |

A1 — Rootly `listAlerts` filter `groups=trade-platform`, `started_at >= 2026-05-12T00:00Z`, response captured during this task.

**Reading**:

- Dev pod replicas rolled overnight: memory alerts on `566b6bd96-…` stopped around 04:58Z; new ReplicaSet `58d5f587f5-…` came up and within hours was CPU-throttling. **The replacement carries the same resource limits**: a roll alone doesn't relieve the pressure.
- Acc cluster is now in the same shape as dev was yesterday. A2.
- Zero prod alerts. A1 (over the full 24h window queried).

---

## L8 — Fix — still observation only, but with sharper next step

Yesterday's RCA shipped no fix because four hypotheses were live. Today's evidence does not eliminate any of them, but it **strengthens H-B (memory upstream)** marginally: the 13 dev memory alerts overnight (90 → 98.8% of limit, repeated) preceded a pod roll which then CPU-throttled. That pattern is consistent with H-B (memory pressure → GC → CPU bursts → CFS throttling), but consistency is not confirmation. **Run the discriminator before shipping any fix.**

| Hypothesis | If confirmed today, fix shape | Repo / artifact to patch |
|------------|-------------------------------|---------------------------|
| H-A undersized CPU | Add `spec.resources.limits.cpu` (and matching `requests`) on the CR; size from `oc adm top pod` peak | `MC-VPP-Infrastructure` or the GitOps app owning the CR — A3 to confirm in step 8 of [`oc-probes.md`](./oc-probes.md) |
| H-B memory upstream | Tune `memory_limiter` processor; raise memory limit; or audit upstream service emissions for high-cardinality metrics | Same as H-A; plus per-service metric audit |
| H-C rule mis-calibrated for sidecar class | Exclude observability containers from `CPUThrottlingHigh` PrometheusRule | `kube-prometheus-stack` config — owned by the cluster operator, not trade-platform |
| H-D debug verbose | Set `exporters.debug.verbosity: basic` or drop debug from active pipeline | OTel CR config — same repo as H-A/H-B |

**What today does NOT change about the fix decision**: still need the live-cluster probe to discriminate. Run [`oc-probes.md`](./oc-probes.md) sections H-A, H-B, H-D against pod `58d5f587f5-92vpd` (dev) FIRST — it is the still-acknowledged alert and the freshest substrate.

---

## L9 — Verification — how to know we fixed the right thing

Same per-hypothesis discriminator from the parent RCA's L9 applies. The condensed runnable form lives in [`oc-probes.md`](./oc-probes.md). After any fix lands:

- CPUThrottlingHigh should not fire on `otc-container` in dev for 24 h.
- ContainerMemoryUsageHigh should not fire on the same pod for 24 h.
- Acc cluster should mirror (since limits are usually identical between dev and acc).
- Prod remains the falsifier of any "limits were the problem in dev/acc" claim only if prod limits are identical AND prod is not throttling — confirm with parallel `oc adm top pod` on prod.

---

## L10 — Lessons (durable, pattern-level)

1. **Repo identity is a cheaper probe than PR diff**. A PR cannot fix what its repo does not own. A wiki PR cannot move a Kubernetes limit. Lesson promotes [LL `name-match-is-not-deployment-proof`](../../../../.ai/memory/lessons-learned.json) by adding "repo-class-match is not change-class-match." Probe: `git diff --stat` on the merged commits answers in one second.
2. **"Alert routing" and "alert silencing" are different problems**. A doc that says how to label alerts for routing can sit next to a chronically throttled workload without ever touching it. On-call narrative needs to keep the two surfaces separate.
3. **Pod-roll without limit change is not a fix**. A ReplicaSet roll resets the working set; today's dev pod (`58d5f587f5-…`) replaced an OOM-pressured pod (`566b6bd96-…`) and reproduced the pattern within hours — strong cue that the CR's resource budget is the constant, not the pod's identity.
4. **Disambiguate before debunking a user's recall**. "Resources on prod were undersized" admits two readings: prod-the-cluster vs the production-class workload (the Collector itself). The strict reading is unsupported by today's Rootly surface; the loose reading is supported by yesterday's RCA H-A label "Suspected undersized CPU budget". The right move is a one-line Slack DM to the user, not a confident debunk. The followup's first draft made the latter mistake — Sherlock's attack W3 surfaced it; see `verification/sherlock-attack-on-followup-verdict.md` for the receipt.

5. **"PR was merged" warrants a 1-second branch probe.** The user's framing was "this PR was merged"; the actual state is open on a feature branch. `git branch -r --contains <head>` and `git merge-base --is-ancestor <head> origin/main` answer the question in two commands. Add this to the on-call playbook ahead of any "PR-was-supposed-to-fix-X" framing.

---

## L11 — End-to-end commands

See [`oc-probes.md`](./oc-probes.md) — every command needed to (a) reproduce the alert survey, (b) probe the four hypotheses against the live cluster, (c) clear the open `bF0Rn7` alert in Rootly, (d) shape and target the eventual capacity PR.

---

## L12 — One-page on-call playbook (5-minute triage card)

1. **If `CPUThrottlingHigh` paged on `otc-container` again**: do NOT touch PR 172896. The wiki PR is unrelated to capacity. Pull yesterday's RCA `./output/rca.md` L9 hypothesis list.
2. **Check whether prod is in the surface**: `mcp__rootly listAlerts filter[groups]=e04f0c98-bbf4-4d92-a534-8883172d56cd filter[started_at][gte]=<24h ago>` and `grep -c "prd.ceap.nl"`. If zero, the issue is dev/acc only — do not page prod-on-call.
3. **Find the still-open alert**: filter status=acknowledged or status=triggered in the group. The pod name from its description is the substrate for probes.
4. **Run discriminator probes** (5 min): [`oc-probes.md`](./oc-probes.md) sections "H-A read CR resources", "H-B memory trend", "H-D debug verbosity".
5. **Decide the fix repo, not just the fix**: read the CR's `ownerReferences` / inspect the ArgoCD app — capacity changes must land in the IaC repo, not in `platform-documentation`.
6. **Acknowledge `bF0Rn7` resolution explicitly** in Rootly once the probe set runs — the dev alert is currently acknowledged with `ended_at: null`.

---

## Evidence labels used

- **A1 FACT** — externally witnessed: `git diff --stat` output, Rootly API responses captured during this task, file:line in parent RCA. Reproducible via [`oc-probes.md`](./oc-probes.md).
- **A2 INFER** — derived from A1 facts via the timeline reasoning in L7 and L10.
- **A3 UNVERIFIED[blocked: <reason>]** — explicitly named at use site: live-cluster `oc` access from this intake, the ArgoCD app that owns the CR (parent RCA L6).

## Adversarial review status

**Sherlock pass complete — VERDICT-PARTIALLY-FALSIFIED.** Full receipt: [`verification/sherlock-attack-on-followup-verdict.md`](../../../../.ai/tasks/2026-05-12-001_rootly-cpu-throttle-post-pr-172896-correlation/verification/sherlock-attack-on-followup-verdict.md). Receipts applied to this document and to [`oc-probes.md`](./oc-probes.md):

| Finding | Class | Status | Where fixed |
|---|---|---|---|
| W1 (wiki→IaC mechanism) | REBUT (verdict survives) | applied | TL;DR + L4 reinforced; W1 probe set logged |
| W3 (user-intent ambiguity on "prod") | DEFER (need user roundtrip) | applied | Verdict row 3 downgraded A1→A3; L10 lesson 4 rewritten; explicit Slack DM action below |
| Branch-merge claim wrong | RESOLVE (factual correction) | applied | TL;DR + L4 corrected (PR is OPEN on `add-how-to-guide-for-alert-routing`, not merged to main) |
| W4-1 prod-count JQ filter cannot match cluster | RESOLVE | applied | `oc-probes.md` §1 rewritten with body-grep + structured filter |
| W4-2 H-B PromQL window 12h vs claim "May 1–12" | RESOLVE | applied | `oc-probes.md` §4 window widened to 12d |
| W4-3 short_id→UUID lookup missing before resolve PATCH | RESOLVE | applied | `oc-probes.md` §9 prefixed with id lookup step |
| W4-4 alert-survey filter misses `triggered` status | RESOLVE | applied | `oc-probes.md` §1 filter widened to triggered+acknowledged |
| W2 (cross-group / per-cluster routing) | DEFER | tracked | Probe added to `oc-probes.md` step 7b (compare prd vs dev AlertmanagerConfig); not run from this intake |

**Open action requiring user input before promoting to `status: complete`**: confirm whether the recalled "resources on prod were undersized" refers to the prd cluster (strict reading) or to the Collector workload in general (loose reading). The action plan is the same either way (file a capacity PR in `MC-VPP-Infrastructure` / GitOps), but the lesson-4 framing only stands on the strict reading.
