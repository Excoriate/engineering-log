---
task_id: 2026-07-19-003
agent: socrates-contrarian
status: complete
timestamp: 2026-07-19T00:00:00Z
summary: |
  Adversarial receipt on FBE feature-flag 401 RCA + how-to-fix, lane = goal
  fidelity + hidden assumptions + fabrication. Fabrication sweep SURVIVES (every
  load-bearing identifier live-verified). Two BROKEN findings: (P2) the headline
  "reproduced Duncan's 401 across 5/7 slots" conflates the deleted-store drift
  (HTTP 000, per the RCA's own L7) with Duncan's resolving-store 401 — no slot
  reproduced his actual symptom; (P3) live pod-start times POSTDATE each current
  store's creation, falsifying the RCA's "pod froze the credential current at
  birth, store recreated later" mechanism and undercutting the 2s-CSI-freshness
  claim that justifies the P2 Reloader fix. Goal fidelity on the fix SURVIVES
  (commits to P1+P2, honest that P4 is the restart-free variant) but rests on an
  unreconciled create-vs-recreate reframe of Duncan's own words.
---

# Socrates adversarial receipt — FBE feature-flag 401 RCA

## Key Findings

- **P1 goal_fidelity — SURVIVES-with-caveat**: fix answers "no manual restart" via automated restart; but RCA silently reframes Duncan's "when creating an FBE" as "recreate".
- **P2 causal_conflation — BROKEN**: "reproduced Duncan's 401" is false; all 5 reproduced slots serve DELETED stores (HTTP 000), not Duncan's resolving-store 401.
- **P3 timing_contradiction — BROKEN**: every drifted pod started AFTER its current store existed, yet baked the older deleted store; "froze-at-birth" mechanism unsupported.
- **P4 fabrication — SURVIVES**: all identifiers/paths/line-refs/live drift verified real; only imprecision is "5 of 7" (live = 6 frontend slots + 1 no-frontend operations store).

Lane: goal fidelity + hidden assumptions + fabrication. NOT reliability, NOT Terraform correctness (other frames own those). Zero-trust; tried to falsify, not confirm.

Evidence gathered live 2026-07-19: repo greps under `Dropbox/@AZUREDEVOPS/.../myriad-vpp`, read-only `kubectl --context vpp-aks01-d`, read-only `az` (sub `7b1ba02e-…`, RG `rg-vpp-app-sb-401`).

---

## POINT 1 — Ask↔deliverable divergence — SURVIVES (with a real sub-BROKEN)

**Duncan's exact ask** (slack-intake.md:74): *"Could you look into how this can be correct from the FBE creation without needing to manually drop the frontend pod?"*

**Does the deliverable commit?** YES. how-to-fix.md:24 commits: "Ship **P1 + P2** together; add P3; schedule P4." It does not merely list options — it ranks and recommends. Not a dodge.

**Is the recommended fix "correct from creation" or still a restart?** Still a restart. P1 (how-to-fix.md:63-102) and P2 both re-bake `appconfig.js` by rolling the pod; only P4 (dynamic appconfig.js, line 188) is restart-free. BUT Duncan's words are "without needing to **manually** drop the frontend pod" — an automated pipeline/Reloader restart literally satisfies "not manually." The RCA is transparent about this (L8:141 calls P1 "exactly the manual step Duncan wants removed … automated"). **Not a semantic dodge — an honest, literal answer.** SURVIVES.

**Sub-finding — BROKEN (create vs recreate):** Duncan reports the failure *"When creating an FBE and all is green in creation pipeline"* (slack-intake.md:70). The RCA asserts the **opposite** for first-create: *"First-create ordering is **correct** … a brand-new slot's first pod bakes the correct credential"* (rca.md:120, L6) and pins the bug on **recreate** only. The RCA never explicitly reconciles "filer says create, RCA says recreate." The plausible bridge (finite planet-name pool → a "create" almost always reuses a torn-down slot → recreate) is *hinted* (fixed planet names, ledger line 21) but never stated as the reconciliation. If Duncan genuinely hits this on a true first-create, the RCA's mechanism does not explain his case at all.
- **Discriminating check:** identify Duncan's actual slot + whether his branch name was previously torn down (ADO pipeline 2412/2629 history for his branch). Un-run. The RCA identifies no slot for Duncan.
- **IF TRUE → action change:** RCA must add an explicit "Duncan's 'create' = slot-name reuse = recreate; here is the evidence" clause, or test one genuine first-create end-to-end (already listed as regression, line 210, but not yet run).

---

## POINT 2 — Load-bearing causal conflation (401 vs 000) — BROKEN

**Claim under attack** (rca.md:9 STATUS, rca.md:38 Summary): *"Verified Root Cause (depth 3) — reproduced live across 5 of 7 active FBE slots."*

**The RCA's own evidence refutes "reproduced Duncan's 401":**
- Duncan's symptom = clean **HTTP 401** in the network tab (slack-intake.md:70).
- RCA L7:135 + evidence live-probe-findings.md:70-80 establish the discriminator: **live store → HTTP 401 `WWW-Authenticate: HMAC-SHA256`; DELETED store → does not resolve, `HTTP=000`.**
- All 5 "reproduced" slots bake stores that are **GONE** from Azure. Live-confirmed by me: `az resource list` shows existing = `{jupiter-vlt, boltz-tec, ishtar-xql, operations-oyk, kidu-gqk, thor-ubn, veku-xsy}`; the baked `{boltz-qzz, ishtar-oyn, kidu-dfm, thor-dyf, veku-ckg}` appear **nowhere**. So the 5 drifted browsers point at non-resolving hosts → **000 / DNS failure, NOT 401.**

**Therefore no slot in the fleet reproduces Duncan's actual 401.** What was reproduced is the *drift* (baked ≠ current), which is the **000 variant** — temporally the aged tail of the mechanism, not Duncan's fresh-window 401. The RCA reframes this as "**Same root cause, two timing variants**" (evidence:80). The shared *root cause* (frozen `appconfig.js`) is plausible, but the headline verb "**reproduced**" is an over-claim: the discriminating probe was already run and it **contradicts** the reproduction of Duncan's specific symptom. "Consistent with" is the honest claim; "reproduced" is not.

- **Single probe that would settle it:** capture the browser Network tab (or `curl -so /dev/null -w '%{http_code}'`) against a freshly-recreated slot **during the store-overlap window** (old store still resolving, key rotated) → expect 401 = Duncan's variant. None of the 5 aged slots can serve this; their old stores are already deleted (000).
- **IF TRUE → action change:** downgrade rca.md:9 from "reproduced across 5/7" to "drift reproduced across 5/7; Duncan's 401 variant inferred but not directly reproduced (no slot captured in the resolving-store window; Duncan's slot never identified)." Depth-3 "Verified" should become "Verified drift; INFERred 401-variant."

---

## POINT 3 — Timing contradiction — BROKEN

**Claim under attack** (rca.md:38, L3:62-70, L4): pod runs init-once at start, bakes whatever `application-secret` holds **at pod birth**; CSI keeps that secret **current within 2 s**; the store is recreated **later**, so only the pod lags ("froze the credential current at birth, store recreated after").

**Live timestamps falsify the ordering for EVERY drifted slot** (kubectl pod `.status.startTime` vs `az … systemData.createdAt` of the CURRENT store):

| slot | pod started (Z) | CURRENT store created (Z) | gap | pod baked |
|------|-----------------|---------------------------|-----|-----------|
| boltz  | 07-08 **14:48:55** | boltz-tec  07-08 **13:24:30** | pod **+84 min** | OLD `-qzz` (gone) |
| ishtar | 07-13 **14:36:07** | ishtar-xql 07-13 **09:33:47** | pod **+5 h**  | OLD `-oyn` (gone) |
| kidu   | 07-16 **12:06:17** | kidu-gqk   07-16 **11:13:13** | pod **+53 min** | OLD `-dfm` (gone) |
| thor   | 07-16 **13:27:37** | thor-ubn   07-16 **12:36:56** | pod **+51 min** | OLD `-dyf` (gone) |
| veku   | 07-17 **09:15:32** | veku-xsy   07-17 **08:21:03** | pod **+54 min** | OLD `-ckg` (gone) |
| jupiter| 07-07 **13:15:36** | jupiter-vlt 07-07 **12:28:40** | pod +47 min | `-vlt` (MATCH) |

In **every** drifted slot the pod was born **after** the current store already existed, yet it baked the **older, now-deleted** store. Under the RCA's stated mechanism a pod born at 14:48 (with `-tec` live since 13:24 and CSI 2 s) must bake `-tec`. It baked `-qzz`. **The "froze-at-birth, recreated-later" story is contradicted by its own supporting fleet.**

Two consequences the RCA does not surface:
1. At pod birth `application-secret` still held the OLD store for ≥51 min–5 h after the current store's `createdAt`. That means store-`createdAt` ≠ secret-update-time, **or** `application-secret` was not as fresh as claimed. Either way the RCA's confident **A1** "CSI keeps `application-secret` current (2 s)" (L4:89, evidence:39) is not demonstrated by these slots — it is demonstrated only for the *steady-state snapshot taken today*, not across the recreate window.
2. This is the exact justification cited for **P2 Reloader** ("on the 5 drifted slots `application-secret` already holds the new store … Reloader would have rolled the frontend", how-to-fix.md:152-156). If there are multi-hour windows where the secret lags the newest store, a Reloader could roll the pod onto a credential that is itself not-yet-final → residual race the fix does not address.

**Honesty of A2/A3 labels:** the RCA flags only "precise per-slot recreation count/time is `A3 [blocked: store history not retained]`" (L7:135). It does **not** flag the live-checkable pod-postdates-store ordering hole — which needed no retained history, just `startTime` vs `createdAt` (both readable, as I just showed). The clean depth-3 mechanism is labelled with more certainty than the timestamps earn.

- **IF TRUE → action change:** RCA must either (a) reconcile why a pod born after the current store baked the prior store (probe KV secret version history / the `keyvaultandappconfigentries` stage run-time for these slots), or (b) relabel the freeze mechanism as INFER and add the secret-lag residual risk to the P2 Reloader section.

---

## POINT 4 — Fabrication sweep — SURVIVES

Every load-bearing identifier, path, line-ref, and live datum checked against reality; all real:

| RCA/fix claim | Verified |
|---|---|
| init container `init-myservice`, `echo … > /etc/nginx/html/appconfig/appconfig.js` | `development/azure-pipeline/Helm/frontend/templates/deployment.yaml:45,58` ✓ |
| chart `frontend-0.4.2` | `Chart.yaml:18 version: 0.4.2` ✓ |
| `app_configuration_name = format("%s-appconfig-fbe-%s-%s", …, random_string.random.result)` | `terraform/fbe/app-config.tf:7` ✓ |
| browser handed **primary WRITE key** | `app-config.tf:15 …primary_write_key_connection_string` ✓ (security smell confirmed) |
| `random_string.random` length=3, keepers | `common.tf:1-6` ✓ |
| appconfig module `…/appconfig?ref=v0.1.0` | `app-config.tf:2` ✓ |
| pipeline stages DeployInfra→keyvaultandappconfigentries→DeployServices→DeployFBEInArgoCD | pipeline `:309,525,554,578` ✓ |
| "blind 180 s sleep", `waitDeploy`, "lines ~638-651" | `$totalTime = 180` at `:640`, `name: waitDeploy` at `:650` ✓ |
| live baked≠current drift, 5 slots + jupiter match | reproduced exactly via my kubectl exec ✓ |
| baked stores GONE from Azure | `az resource list` confirms `-qzz/-oyn/-dfm/-dyf/-ckg` absent ✓ |
| Reloader absent cluster-wide | not my lane (reliability); not re-probed |

**Only imprecision:** "5 of **7** active FBE slots" (rca.md:9,38). Live frontend deployments = **6** planet slots (boltz, ishtar, jupiter, kidu, thor, veku); az shows a 7th `vpp-appconfig-fbe-operations-oyk` store that has **no frontend deploy**. So it is "5 drifted of 6 frontend-bearing slots (+ jupiter healthy)." The "7" is unexplained — cosmetic, not fabrication.

---

## Meta-falsifier (how THIS receipt could be wrong)

- **P2:** if Duncan's slot's baked store were still *resolving* at his observation (rotated key, store not yet deleted), the fleet's 000-variant and Duncan's 401 would be two faces of one mechanism and "reproduced" is defensible shorthand. I cannot see Duncan's historical slot state; I attack the *word* "reproduced" given the RCA's own 000/401 discriminator, not the root cause. Root cause (frozen appconfig.js) stands.
- **P3:** if the KV secret `connectionstrings-app-config` for the current store was written **long after** the store's `systemData.createdAt` (e.g., a later terraform apply / `keyvaultandappconfigentries` re-run), then a pod born between store-create and secret-write would legitimately bake the old store, and the mechanism holds — but *then* the RCA's "CSI current within 2 s of the recreate" framing is still the thing that is imprecise. Either branch leaves an over-claim. I did not read KV secret version history (would settle it).
- **P4:** I verified the `development` and `main` working copies; if the *deployed* ArgoCD revision differs from these checkouts, line-refs could drift. Chart 0.4.2 matches the live pods' behavior, so low risk.

**Overall grade: PROBLEMATIC.** Root cause and fix direction are sound and fabrication-free, but two load-bearing claims ("reproduced Duncan's 401" and the "froze-at-birth" timing mechanism) are over-stated relative to the RCA's own evidence and live timestamps. Recommend: relabel P2/P3 claims (Verified→INFER where noted), reconcile create-vs-recreate against Duncan's words, and either capture a true 401-window repro or state it as inferred.
