---
agent: el-demoledor
task_id: 2026-06-22-009
lane: technical-destruction
target: "RCA + fix for telemetryfunctiontestsfn/healthz 404 on agg.dev.vpp.eneco.com"
status: complete
verdict: conditional
summary: "Diagnosis SURVIVES demolition and was re-confirmed live (404/200/404, context vpp-aks01-d). Fix approach is sound but ship-diff is not byte-identical to the only artifact that produced a witnessed public 200: F1 HIGH pathType divergence (proof used ImplementationSpecific, diff keeps Prefix), F2 MEDIUM siteregistry-overlap specificity unproven for the deployed shape. CONDITIONAL: mergeable once F1 (match-or-reprove pathType) and F2 (regression guard as hard gate) are closed; diagnosis needs no change."
findings_count: 7
findings_by_grade: "EXPLOIT-VERIFIED: 3 (re-ran live probes), PATTERN-MATCHED: 3, THEORETICAL: 1"
---

# EL DEMOLEDOR — Technical Destruction Receipt

**Target:** `rca.md` + `how-to-fix.md` + `evidence/01..08` for the telemetryfunctiontestsfn 404.
**Lane:** TECHNICAL ONLY (diagnosis correctness + fix-will-work + load-bearing-claim evidence). Writing-quality / goal-fidelity explicitly out of scope.
**Independent re-probe this session:** `kubectl context = vpp-aks01-d`; live ingress paths/types match evidence/02 exactly; edge re-probe returned `telemetry=404, siteregistry=200, deliveryreportfn=404` — byte-identical to `evidence/01`. The diagnosis substrate is real and current.

## BOTTOM LINE FOR THE COORDINATOR

I could **NOT** destroy the diagnosis. Root cause (prefix-mounted Azure-Functions ingress with no `rewrite-target`) is witnessed seven ways and I reproduced the core split live. That part is bulletproof.

I **DID** find a real gap in the **fix**: the diff the doc tells the engineer to merge is **NOT** byte-identical to the ingress the doc proved live. Two concrete divergences (F1 HIGH, F2 MEDIUM) mean the deployed chart could behave differently from the witnessed `200`. Neither is fatal to the approach; both must be closed before "proven live" is allowed to stand in for "deployed result."

---

## FINDINGS

### F1 — HIGH — The proven test ingress used `pathType: ImplementationSpecific`; the chart diff leaves `pathType: Prefix`. The doc admits the template hard-codes `Prefix` but the diff does NOT change it.

- **Mechanism:** Live proof (`evidence/08`) + playbook (`rca.md:403`) used `pathType: ImplementationSpecific` with `path: /tf-rewrite-proof(/|$)(.*)`. The actual chart diff (`how-to-fix.md:71-81`, `rca.md:261-271`) changes only `path` + two annotations. It does NOT touch `pathType`. The chart template hard-codes `pathType: Prefix` — stated explicitly at `how-to-fix.md:92` and `rca.md:277`.
- **Why this is break-shaped:** With `pathType: Prefix`, the Kubernetes Ingress API validates `path` as a literal path that must begin with `/` and contain a valid path value. A regex value like `/telemetryfunctiontestsfn(/|$)(.*)` under `pathType: Prefix` is at minimum semantically inconsistent and, depending on nginx-ingress v1.14.0's validation, may be (a) rejected by the admission webhook, (b) silently treated as a literal-prefix match of the regex string (which no real path matches → still 404), or (c) honored as a regex only because `use-regex:"true"` overrides path-type interpretation. The doc ASSERTS (c) — "`use-regex: "true"` makes nginx honour the regex anyway" (`how-to-fix.md:92`) — but that assertion is **NOT in the captured evidence**. Evidence/08 proved the `ImplementationSpecific` path, not the `Prefix`+regex path. The proven artifact and the shipped artifact differ on exactly the field whose behavior is in question.
- **Evidence grade:** PATTERN-MATCHED (the divergence is witnessed in the files; the failure mode is the known nginx-ingress pathType/use-regex interaction, which I did not execute against `Prefix`).
- **file:line:** `how-to-fix.md:77` (diff keeps implicit Prefix) vs `how-to-fix.md:92` (admits hard-coded Prefix, only "optionally" change it) vs `rca.md:403`/`evidence/08:8` (proof used ImplementationSpecific).
- **Counter-hypothesis:** `use-regex:"true"` genuinely overrides pathType matching in nginx-ingress, so `Prefix`+regex works identically to the proven `ImplementationSpecific`+regex. I favor the finding over this because the doc itself flags the hard-coded `Prefix` as a thing "to verify before merge" (`rca.md:277`) and used the OTHER value in the only live proof — i.e., the author had reason to switch it for the proof and did not carry that switch into the diff. The proof does not witness the shipped config.
- **CONDITIONAL → if true, the coordinator must change:** Promote `pathType: ImplementationSpecific` from "optional / for cleanliness" (`how-to-fix.md:92`, `rca.md:277`) to a **required line of the diff**, OR add a captured proof that `Prefix`+regex+`use-regex` returns 200 on this exact controller. As written, the doc proved config A and ships config B.

---

### F2 — MEDIUM — Capture-group / regex coupling is correct, but the diff's `path` regex was never proven on the chart's host/pathType combination; only on a different path string.

- **Mechanism:** `rewrite-target: /$2` requires `$2` to be the 2nd capture group. Proven path `/tf-rewrite-proof(/|$)(.*)` → group1=`(/|$)`, group2=`(.*)` → `$2` = everything after the prefix. Chart path `/telemetryfunctiontestsfn(/|$)(.*)` has the identical group structure, so `$2` is correctly the tail. **This sub-claim survives** — the `$2` (not `$1`) choice is right, and trailing-slash is handled by `(/|$)`. Where it does NOT survive: the proof ran on a NEW host-less-conflicting path (`/tf-rewrite-proof...`) that did not coexist with a `/` catch-all in a way that exercises specificity. The chart path coexists with `siteregistry`'s live `path: / pathType: Prefix` (re-confirmed live this session). The doc claims "a more specific prefix wins" (`how-to-fix.md:93`, `rca.md:278`). Under nginx-ingress with `use-regex:"true"` present on ONE ingress, regex matching semantics and location-ordering across SEPARATE Ingress objects are governed by nginx-ingress's location-sorting, not by naive "longest prefix wins." The regression guard in evidence/08 proved siteregistry stayed 200 **while the test ingress was on a non-overlapping unique path** — it did NOT prove siteregistry survives when a regex ingress is mounted whose regex could, under some controller versions, broaden location matching.
- **Why break-shaped:** if the deployed regex ingress reorders nginx locations such that `/` catch-all is shadowed or the regex captures `/api/siteregistry`, the fix would REGRESS siteregistry (200→404) — turning a fix into an outage of the one working path.
- **Evidence grade:** THEORETICAL (mechanism plausible; reachability depends on nginx-ingress v1.14.0 location-sort behavior across multiple Ingress objects, which the evidence does not exercise because the test path never coexisted-and-overlapped with the catch-all).
- **file:line:** `how-to-fix.md:93` / `rca.md:278` (specificity claim) vs `evidence/08:15-25` (regression guard ran on a non-overlapping path, not the deployed path).
- **Counter-hypothesis:** separate Ingress objects with distinct hosts/paths don't cross-contaminate, and the deployed config is functionally identical to the merged generated nginx.conf the proof already exercised. I partially accept this — the proof IS strong — but the post-deploy regression guard (`how-to-fix.md:119-120`) is exactly the right control and is currently listed as an owner-run FUTURE step, which means the specificity claim is asserted, not yet witnessed for the deployed shape.
- **CONDITIONAL → if true:** Keep the regression guard as a HARD acceptance gate (it already is at `how-to-fix.md:119`), and downgrade the in-text "it will not shadow siteregistry — a more specific prefix wins" from a flat assertion to "expected; gated by the post-deploy regression check." The fix approach stays; the certainty of the side-claim must drop until the deployed shape is witnessed.

---

### F3 — MEDIUM — "100% verifiable / proven live" framing risks reading the post-deploy public 200 as already witnessed. It is NOT — it is an owner-run future step. (Verifying the doc is honest about this.)

- **Result of attack:** The doc IS honest, but only if read carefully. `rca.md:33,273,311` say the fix "is a witnessed result" / "not an inference" — TRUE for the test-ingress path `/tf-rewrite-proof/healthz=200`. The deployed-chart public 200 on `/telemetryfunctiontestsfn/healthz` is correctly marked as expected/owner-run (`rca.md:316`, `how-to-fix.md:118` "expect 200"). E11/`rca.md:82` honestly flags the ADO-PR attribution as A3 blocked.
- **Where it slips:** Executive summary `rca.md:18` "confirmed live this session in seven independent ways — including a live, reversible proof that the fix produces a public 200." Combined with F1, the witnessed 200 was the **test-ingress** config (ImplementationSpecific), not the **shipped** config (Prefix+regex). So "the fix produces a public 200" overclaims by one notch: *a* rewrite ingress produced 200; *the diff as written* has not been witnessed end-to-end.
- **Evidence grade:** PATTERN-MATCHED (claim-vs-evidence gap, located in files).
- **file:line:** `rca.md:18` and `rca.md:311` ("strongest possible pre-merge evidence") vs F1 divergence.
- **Counter-hypothesis:** "the fix" colloquially means "the rewrite mechanism," which WAS proven, and the doc separately lists the deployed checks. Reasonable — this is why it is MEDIUM not HIGH. But for a release-blocking change the one-notch gap (proved config A, ship config B) should be explicit.
- **CONDITIONAL → if true:** One sentence in the exec summary / L9: "the live 200 was witnessed on an `ImplementationSpecific` test ingress; the chart diff must either match that pathType or be re-proven." This closes F1 and F3 together.

---

### F4 — LOW — `deliveryreportfn` fix is asserted by analogy, never proven; the proof only covered telemetry's backend.

- **Mechanism:** Fix instructs mirroring the change into `deliveryreportfn/values.yaml` (`how-to-fix.md:69`, `rca.md:259`). Evidence that deliveryreportfn 404s exists (`evidence/01:6`). Evidence that the rewrite FIXES deliveryreportfn does not — evidence/08 pointed the test ingress at the `telemetryfunctiontestsfn` backend service only (`evidence/08:18` "same backend: no HTTP fns"). The deliveryreportfn backend's root-`/healthz` behavior was never port-forwarded (evidence/06 is telemetry only).
- **Why only LOW:** same chart family, same Azure-Functions base image is the most likely reality, and deliveryreportfn is not the release blocker.
- **Evidence grade:** PATTERN-MATCHED (absence: the analogical claim has no witness for the second service).
- **file:line:** `how-to-fix.md:69` vs `evidence/06` (telemetry-only port-forward).
- **Counter-hypothesis:** identical chart + identical base image ⇒ identical behavior; near-certain. Accepted as low-risk.
- **CONDITIONAL → if true:** Label the deliveryreportfn change "by analogy, unverified" or add a one-line port-forward check for its `/healthz` before claiming it fixed. Does not block the telemetry release.

---

### F5 — LOW — "App is healthy, only the edge is wrong" is well-supported, but the scope claim "/healthz is the ONLY HTTP surface" rests on a non-exhaustive 3-path probe.

- **Attack on the scope claim (`rca.md:156`, `how-to-fix.md:53`):** Derived from `evidence/06`: `/api/*=404`, `/admin/*=401` ⇒ "no HTTP-invocable functions." That is **3 probed paths**, generalized to "no HTTP functions exist." A timer/Kafka-triggered function set is the stated design (`rca.md:156`), which makes the generalization plausible, but `/api/siteregistry` 404 only proves THAT route is absent, not that NO `/api/<x>` route exists. The conclusion is an INFER presented adjacent to A1 facts.
- **Does it threaten the fix?** No. The fix restores `/healthz`, which IS witnessed 200 at root (`evidence/06:9`). Even if a hidden HTTP function existed, the rewrite (`/$2` → strips prefix → backend root) would route it correctly too. So the scope claim is a completeness nicety, not a fix dependency.
- **Evidence grade:** THEORETICAL→downgraded to LOW (does not affect route or fix).
- **file:line:** `rca.md:156` ("this host exposes no HTTP-invocable functions") generalized from `evidence/06:10-12`.
- **Counter-hypothesis:** the design (timer/Kafka triggers) is the author's domain knowledge and makes "no HTTP functions" true by construction. Likely correct; hence LOW.
- **CONDITIONAL → if true:** none required for the fix. Optionally soften "the only meaningful HTTP surface" to "the only HTTP surface observed."

---

### F6 — EXPLOIT-VERIFIED (re-ran live) — The 301→`http://` plaintext downgrade is real and is correctly DEFERRED, but it interacts with the new regex path in a way the doc does not analyze.

- **Mechanism I confirmed:** `evidence/01:13-14` shows bare prefix → `301 Location: http://agg.dev...`. After the fix, the new path is `/telemetryfunctiontestsfn(/|$)(.*)`. A request to `/telemetryfunctiontestsfn` (no trailing slash) matches group1=`$` (empty), group2=`(.*)`=empty → rewrite-target `/$2` = `/` → backend root banner (200), NOT a 301. So the fix actually CHANGES the bare-prefix behavior from "301 to http" to "200 root banner." The doc defers the 301 (`rca.md:333`, L10 #6) as untouched, but the rewrite silently alters it. This is benign (200 > a plaintext-downgrade 301) but the doc's claim that the fix "does NOT change" anything but the path routing (`how-to-fix.md:63` "Nothing else changes") is slightly off: it also eliminates the bare-prefix 301 for this service.
- **Why LOW-leaning-MEDIUM:** it's an improvement, not a regression, so it doesn't break the fix — but "nothing else changes" is technically false and the deferred-latent-301 lesson (L10 #6) no longer applies to the rewritten service post-fix.
- **Evidence grade:** EXPLOIT-VERIFIED for the 301 (re-derived from live evidence/01 + regex semantics).
- **file:line:** `how-to-fix.md:63` ("Nothing else changes") vs `rca.md:333` (defers 301) vs regex at `how-to-fix.md:77`.
- **Counter-hypothesis:** the 301 originates at the App Gateway or a different nginx server-block and the per-ingress rewrite won't touch it. Possible — but the 301 Location is the prefix path itself, which is exactly what the new regex ingress now owns. Worth a one-line note.
- **CONDITIONAL → if true:** Note in L8/L10 that the rewrite incidentally resolves the bare-prefix 301 for the rewritten service; remove the implication that the latent 301 (L10 #6) still applies to it post-fix.

---

### F7 — MEDIUM — Confidence arithmetic and "depth-3 / seven ways" are sound; the ONLY load-bearing inference (E10 "fix never merged") is correctly graded A2 and does not touch the fix.

- **Attack result:** I tried to find an A1 FACT label on a claim the evidence does not witness. The grading holds up:
  - E10 "fix never merged" is correctly A2 (`rca.md:81`), explicitly inferred from E3+E6, with the ADO probe deferred to L11 step 7. Honest.
  - E11 attribution is correctly A3 blocked (`rca.md:82`).
  - The chart-default `annotations:{}` claim (E6) is witnessed in `evidence/05:11`. A1 stands.
  - App Gateway `urlPathMaps:[]` (E8) witnessed in `evidence/07:38`. A1 stands.
- **The one I'd push on:** `rca.md:18,434` "depth-3 ... seven independent ways." Observation #2 in the seven ("deliveryreportfn control 404s identically") proves a CLASS bug but, per F4, the rewrite was never proven to FIX deliveryreportfn — so it's a valid diagnosis witness, not a fix witness. The "seven ways" count conflates diagnosis-confirmations (legit, all 7 support the diagnosis) with fix-confirmations (only #3 backend-root-200 and #7 test-ingress-200 are fix witnesses, and #7 is F1-divergent). The count is honest for the diagnosis; do not let it transfer to the fix.
- **Evidence grade:** PATTERN-MATCHED (grading audit).
- **Counter-hypothesis:** the seven-ways claim is explicitly about the diagnosis (`rca.md:434` "Confirmed ... by seven independent observations"), not the fix, so there's no conflation. Reading the line literally, this is correct — hence I do not escalate. The risk is only in the exec-summary compression at `rca.md:18`.
- **CONDITIONAL → if true:** none required; the diagnosis confidence is well-founded. Just keep "seven ways" attached to the diagnosis, never to the fix.

---

## ABSENCE AUDIT (what the evidence does NOT witness)

| Missing witness | Impact | Severity |
|---|---|---|
| Public 200 on the DEPLOYED `Prefix`+regex config (only `ImplementationSpecific` proven) | Deployed fix may differ from proof | F1 HIGH |
| siteregistry 200 while a regex ingress overlaps the `/` catch-all on the SAME deployed path | Possible siteregistry regression | F2 MEDIUM |
| deliveryreportfn backend `/healthz`=200 + rewrite proof | Second service fix unproven | F4 LOW |
| Exhaustive HTTP-route enumeration (only 3 paths probed) | "no HTTP functions" is INFER | F5 LOW |
| nginx-ingress v1.14.0 admission acceptance of regex value under `pathType: Prefix` | Diff may be rejected/mishandled at apply | F1 HIGH (same root) |

## ADVERSARIAL SELF-CHECK

- **Pattern-matching check:** F1 is NOT a generic "missing field" nitpick — it is witnessed in the files that the proof config and the ship config differ on the exact field whose behavior is contested. Survives.
- **False-positive conditions:** F1 is a false positive IF `use-regex:"true"` provably overrides pathType on v1.14.0 (no captured proof either way → finding stands as a verification gap, not a defect claim). F2 is a false positive IF separate Ingress objects never cross-influence nginx location ordering (likely true for distinct paths, but the regression guard is exactly why it's only MEDIUM).
- **Redundancy / root-cause grouping:** F1 and F3 share ONE root cause — "proved config A, ship config B." Count them as **1 root issue, 2 manifestations** (HIGH). F2 is distinct (specificity/overlap). F4/F5/F6/F7 are independent low-severity nicks. Net actionable: **1 HIGH root + 1 MEDIUM + low-severity polish.**
- **Severity-inflation check:** I did NOT rate the diagnosis as broken — it survived and I re-confirmed it live. Only the fix's proof-vs-ship gap is HIGH, and even that is a verification gap, not "the fix is wrong."

## META-FALSIFIER

- **Strongest argument against my top finding (F1):** nginx-ingress's `use-regex` annotation is documented to switch path interpretation to regex regardless of pathType, so `Prefix`+regex+`use-regex` is a common, working pattern. If the coordinator confirms this against v1.14.0 docs/admission, F1 collapses from HIGH to a one-line "make pathType explicit for clarity." I could not confirm or refute it from the captured evidence — that is precisely the gap. **F1 stays HIGH as a VERIFICATION-GAP, not a defect.**
- **Confirmed after self-attack:** F1+F3 (proof≠ship), F2 (specificity gated, not witnessed for deployed shape).
- **Downgraded:** F5, F7 (do not affect route/fix; honest grading) → LOW/no-action.

## VERDICT

**Diagnosis: SURVIVES. Could not break it. Re-confirmed live (404/200/404, context vpp-aks01-d).** Root cause depth-3 is sound and witnessed.

**Fix: SOUND APPROACH, but ship≠proof.** The merged diff is not byte-identical to the only artifact that produced a witnessed public 200 (pathType divergence, F1). Before "proven live" is allowed to substitute for "deployed result," the coordinator must EITHER (a) make `pathType: ImplementationSpecific` a required line of the diff (matching the proof), OR (b) capture a 200 on the exact `Prefix`+regex config, AND keep the siteregistry regression guard (F2) as a hard post-deploy gate. With those two closed, the fix is as strong as the diagnosis.

**Recommendation: CONDITIONAL — fix is mergeable once F1 (pathType match-or-reprove) and F2 (regression guard as gate) are closed. Diagnosis needs no change.**

---
*El Demoledor — proving resilience through destruction. Diagnosis withstood; the fix's proof-to-ship gap did not.*
