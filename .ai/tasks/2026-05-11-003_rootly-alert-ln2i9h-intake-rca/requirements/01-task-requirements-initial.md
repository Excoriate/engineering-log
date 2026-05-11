---
task_id: 2026-05-11-003
agent: claude-code
status: draft
summary: Rootly alert ln2I9h intake (eneco-oncall-intake-rootly) + holistic RCA artifact (rca-holistic) at named external path
---

# Task Requirements — Initial (NN-3 Mirror)

## 🎯 Request

Intake Rootly alert `ln2I9h` (URL: `https://rootly.com/account/alerts/ln2I9h`) via
`eneco-oncall-intake-rootly` skill, then produce a holistic RCA via
`rca-holistic` skill at the explicit external path:

```
/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/log/employer/eneco/02_on_call_shift/2026_05_11_rootly_alert_cpu_throtling/
```

Destination folder slug `cpu_throtling` is a HINT, not a verified diagnosis.

## 🗣️ User pre-framing

> "ensure you're writing the RCA (use /rca-holistic) here: <path>"

Directive but not urgency-bypass; gates fully apply.

## 🧩 DOMAIN-CLASS

investigation (alert → causal chain → narrative RCA for personal on-call log)

## 🕹️ CONTROL-PLANE-ARTIFACT

n — output is a knowledge artifact in personal log; no agent/harness surface touched.

## 📊 CRUBVG

| Axis | Score | Evidence tag |
|------|-------|--------------|
| C Coupling | 1 | `[MID: axis=C because investigation crosses Rootly + Azure Monitor + IaC repo + runtime resource]` |
| R Reversibility | 0 | `[ZERO: axis=R evidence="read-only probes + new file in personal log; no mutation"]` |
| U Uncertainty | 2 | `[HIGH: axis=U because alert payload unread; folder slug "cpu_throtling" (sic) is derived-surface and must be re-discovered from canonical alert payload]` |
| B Blast radius | 0 | `[ZERO: axis=B evidence="local file output in engineering-log; no system change"]` |
| V Verification | 1 | `[MID: axis=V because acceptance is probe-cited mechanism + adversarial review of RCA"]` |
| G Context gap | 1 | `[MID: axis=G because needs fresh Rootly + Azure fetch + possibly IaC + wiki"]` |

**Total: 5 → Normal mode** (investigation route). G=1 → +0 since already counted; LIBRARIAN trigger on (Microsoft Learn for metric semantics in Phase 4D).

## 🧱 Phase Compression Mode

Normal. Investigation route. Full 8 phases, 8 gates, but artifact scaling is moderate.

## 🗺️ System view + Frames

- Consumer = Mr. Alex on-call (RCA reader, future self)
- Operator = future on-caller recognising the same pattern via the playbook
- Boundary = Rootly platform ↔ Azure Monitor ↔ IaC (MC-VPP-Infrastructure) ↔ runtime resource
- Time = 2026-05-11 firing window (no exact time yet — Phase 4)
- Derived = folder slug "cpu_throtling" is a DERIVED SURFACE; canonical = Rootly payload

## 🧨 Counterfactual (what degrades if not done)

- Skip intake → write RCA off folder slug → fabricate mechanism (wrong diagnosis blessed)
- Skip RCA depth → terminal quick-triage answer in personal log = waste of artifact slot
- Skip Phase 6D routing decision → conflate ack-level with full RCA

## ✅ Success Criteria (externally-witnessable)

1. Alert `ln2I9h` resolved to a concrete record; 8 triage fields populated from
   `rootly-alert-decode.sh` output (cmd + non-empty payload = witness).
2. Mode selected via Phase 1 reasoned one-liner (state condition that fired).
3. Mechanism chain ≥ depth 2 with cited evidence (file:line OR cmd:output OR
   doc URL) per causal hop.
4. Phase 6D routing decision STATED with which condition fired (terminal vs
   handover); decision recorded in `context/`.
5. `rca-holistic` produces output package at the named external path with A1/A2/A3
   claim-class on every load-bearing claim; adversarial review file present
   before status=complete (rca-holistic contract).
6. `gate_witnesses[]` non-empty at delivery with ≥1 external-agent-artifact or
   external-runtime-output per load-bearing claim.

## 🔬 Hypotheses

- **H1**: Known recurring CPU-throttling pattern on a VPP resource — falsifier:
  alert payload metric is NOT CPU% (could be SQL DTU, Cosmos RU/s, request
  throttling, etc.) OR no recent recurrences of same rule.
- **H2**: Folder slug `cpu_throtling` is a working name the user typed quickly;
  alert is about a different throttling class — falsifier: payload metric
  matches CPU semantics on a compute SKU.
- **H3**: Alert short ID `ln2I9h` may not resolve via `--short-id` lookup if
  Eneco's Rootly workspace is reached via subdomain (e.g. `eneco.rootly.com`)
  while user pasted `rootly.com/account/alerts/`; could be a permalink to a
  different workspace or an old short ID — falsifier: `rootly-alert-decode.sh
  --short-id ln2I9h` returns a payload with HTTP 200.

## 🌐 CONTEXT UNIVERSE — Lane Seeds (74.4.1)

Each lane has an identity (what evidence it yields), a fetch shape (how it
gets read in P4), and a risk flag (what skipped lane costs).

| Lane | Identity | Fetch shape | Skipped-lane risk |
|------|----------|-------------|-------------------|
| L-ROOTLY-ALERT | Canonical alert record (rule name, payload, status, fired_at, escalation) | `rootly-alert-decode.sh --short-id ln2I9h` | Whole task collapses — no canonical |
| L-ROOTLY-HISTORY | Last 20 firings same rule + similar incidents | `rootly-api.sh GET "/v1/alerts?filter[search]=<rule>"` + MCP `find_related_incidents` | Pattern classification (Known/Known-with-change/Novel) cannot be reasoned |
| L-AZURE-RULE | ARM definition of Azure Monitor rule (metric, criteria, action groups) | `az monitor metrics alert show -n <rule> -g <rg>` | L3+ alert-as-code traceback fails; can't connect rule → IaC |
| L-IAC-SOURCE | Terraform file declaring the alert rule + tfvars holding threshold | Read `MC-VPP-Infrastructure/terraform/metric-alert-*.tf` + matching `<env>-alerts.tfvars` | No Link 3-5 of traceback; can't reason about threshold rationale |
| L-GIT-BLAME | Last commit changing the threshold line + commit message | `git log -p` + `git blame` on threshold line in MC-VPP-Infra | Link 5 missing — can't reason about who/why/when of threshold |
| L-VENDOR-DOCS | Microsoft Learn semantics for the metric (what does this counter mean, normal range, SKU constraints) | `microsoft_docs_search` then `microsoft_docs_fetch` | Link 6 missing — diagnosis built without first-principles metric understanding |
| L-RUNTIME-METRIC | Last 7-day metric distribution on the resource (where does current firing sit) | `az monitor metrics list --resource ... --metric ... --interval ...` | Link 7 (threshold rationality observation) is theatre, not evidence |
| L-ENECO-DOCS | ADRs / Trade Platform FAQ / Myriad VPP wiki for the resource class | `eneco-context-docs` skill | Eneco-specific instantiation absent (vendor-default vs Eneco-default mismatch) |
| L-PRIOR-RCAS | Engineering-log + 2ndbrain entries on the same rule/resource/pattern | `find log/employer/eneco -iname '*<keyword>*'` + 2ndbrain search if rule recurs | Reuse of prior reasoning lost; duplicate domain-primer work |
| L-ADVERSARIAL | Sherlock + Socrates typed subagents — diagnosis attack + frame attack | TYPED subagent dispatch with artifact_path | Self-review = HALT per Gate 7 |

## 🧠 SPECIALTY

This skill (`eneco-oncall-intake-rootly`) handles intake; `rca-holistic` skill
handles RCA artifact. Mechanics delegated to `eneco-tools-rootly` scripts
(`rootly-api.sh`, `rootly-alert-decode.sh`, `rootly-iac-fetch.sh`). Adversarial
attacks routed to `sherlock-holmes` (diagnosis), `socrates-contrarian` (framing).

## 🚦 Triggers

- LIBRARIAN: y (Microsoft Learn for metric semantics, P4D step 4D.1)
- FRAME-PRIMARY: Sherlock (investigation) + Socrates (CPU framing challenge)
- EVALUATOR: y (rca-holistic enforces adversarial review pre-complete)
- DOMAIN: y (eneco-platform-mc-vpp-infra if traceback reaches L3 IaC)
- TOOLS: y (verified `rootly` CLI at /opt/homebrew/bin/rootly + 3 delegation scripts present + ROOTLY_API_KEY set len=71)

## ⚠️ BRAIN SCAN

**Most dangerous assumption**: "folder name `cpu_throtling` = correct diagnosis".

**External falsifier**: first Rootly probe returns metric that is NOT CPU
(e.g. throttled-requests on Cosmos, SQL DTU, MaxThrottlePercent on App Service
Plan, etc.).

**Likely failure path if assumption holds and is wrong**: write RCA mechanism
for CPU throttling when alert is actually about a downstream throttling class;
domain primer is correct but pointed at the wrong subsystem; on-call recognition
playbook teaches the wrong pattern.

**Frame**: `[agent=sherlock-holmes via Phase 4D pattern intelligence + agent=socrates-contrarian challenging "CPU" interpretation before rca-holistic writes; artifact_path=$T_DIR/context/diagnosis-challenge.md]`. NOT a fork (forks forbidden for adversarial). Both are TYPED subagents.
