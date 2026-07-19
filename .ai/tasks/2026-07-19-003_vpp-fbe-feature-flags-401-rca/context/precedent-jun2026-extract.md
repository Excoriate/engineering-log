---
title: "Precedent extract — Jun-2026 Jupiter FBE feature-flag 401 (RESOLVED)"
description: "Precision extract of the resolved 2026-06-22-006 / 2026-06-26-004 Jupiter FBE App Config 401 RCA + how-to-fix, for reuse on the near-identical 2026-07-19 Duncan FBE FF-401 incident."
timestamp: 2026-07-19T00:00:00+02:00
status: complete
category: on-call-context
authors: ["Claude Code (extraction sidecar)"]
task_id: 2026-07-19-003
agent: subagent-extractor
summary: >-
  Verbatim-identifier extract from the Jun-2026 precedent. Root cause was a TRANSIENT provisioning-window
  credential-freshness 401 on a per-slot Sandbox App Config store, browser-direct HMAC, that SELF-RESOLVED
  on the frontend pod rebuild. NO permanent fix was shipped/merged. Source docs cited by file:line.
---

# Precedent extract — Jun-2026 Jupiter FBE feature-flag 401 (RESOLVED)

Source docs (both `status: complete`, task_id `2026-06-22-006`; resolution enrichment task `2026-06-26-004`):

- `log/employer/eneco/02_on_call_shift/2026_june/2026_06_22_003_feature_flags_fbe_duncan/rca.md` (777 lines)
- `log/employer/eneco/02_on_call_shift/2026_june/2026_06_22_003_feature_flags_fbe_duncan/how-to-fix.md` (554 lines)

The resolved verdict lives in the CORRECTION BANNER (rca.md:44-67), ledger rows C16/C17/C19-C22 (rca.md:703-708),
Confidence RESOLUTION UPDATE (rca.md:723-729), and Mutation log 2026-06-26 (rca.md:771-777). The L1-L12 body
(rca.md:237-676) analyzes the WRONG store (`vpp-applicationconfig-d`, dev-mc) and is retained only as the
pre-probe reasoning trail — do not reuse its store-specific identifiers.

---

## 1. Root cause mechanism (the causal chain, and transient-vs-permanent)

**Verdict: TRANSIENT provisioning-window credential-freshness condition that SELF-RESOLVED on the frontend
pod rebuild. It is (a), not (b). No permanent ordering/race bug was diagnosed; no manual restart was
asserted as "the fix."**

Settling quotes:

- rca.md:60-62 — "**Mechanism:** a **provisioning-window credential-freshness** condition. Store created
  09:29 UTC, flags written 10:03, Duncan tested ~10:49 against a 23-min-old frontend pod; the healthy pod
  serving a valid `appconfig.js` was rebuilt at 20:17 — after which the calls return 200. **Self-resolved.**"
- rca.md:19-21 (frontmatter summary) — "the 401 was a provisioning-window credential-freshness condition
  that self-resolved when the frontend pod rebuilt."
- rca.md:727-728 — "The single asserted root cause is now **the per-slot FBE store + browser-direct HMAC,
  transiently failing during FBE provisioning** — not any dev-mc auth/RBAC/network/pipeline cause."
- C21 (rca.md:707) — "store created 09:29:36Z, flags 10:03:42Z, frontend RS 10:26:31Z, Duncan filed ~10:49Z,
  healthy frontend pod rebuilt 20:17:18Z → 401 occurred against a 23-min-old pod, self-resolved on rebuild."

CHAIN: FBE create → per-slot Sandbox App Config store provisioned (09:29Z) → flags written (10:03Z) →
frontend replica-set/pod built during provisioning window (RS 10:26Z) serving an `appconfig.js` whose
injected connection-string credential was not yet fresh/valid → browser SPA calls `.appconfig.featureflag/*`
over HMAC → 401 → pod later rebuilt (20:17Z) with a valid `appconfig.js` → 200.

### AMBIGUITY FLAG (critical for coordinator)
The pod rebuild at 20:17:18Z is described as SELF-RESOLUTION, NOT as a deliberate manual pod restart. The docs
never state anyone manually restarted the frontend pod to fix it; they say it "was rebuilt" and "self-resolved"
(rca.md:62, :729). So the coordinator's framing "fixed by frontend pod restart" is only APPROXIMATELY what the
precedent concluded. The precise mechanism the RCA underspecifies: exactly WHY the 23-min-old pod's injected
connection string was rejected 401 while the store/key were healthy throughout (it names it "credential-
freshness" but does not nail the credential lifecycle). If the new incident was resolved by an explicit MANUAL
restart, that is a stronger/different claim than this precedent proves.

---

## 2. The fix — shipped/merged, or only recommended?

**NO permanent fix was shipped or merged. No PR/branch reference exists. The durable "repair" was the FBE
finishing provisioning (the pod rebuild) — i.e. nothing was changed.**

- how-to-fix.md:30-32 — "the store/key were healthy; ... The closest branch below is **Branch B (access-key
  read path)**, but the key was never broken — so the durable repair was simply the FBE finishing
  provisioning. The decision tree below remains a sound *general* App Config 401 guide; for THIS incident it
  is superseded by the RCA correction."
- The how-to-fix.md decision tree (Branches A/A-SP/B/C/D/E/F) is a GENERAL App Config 401 guide targeting the
  WRONG store; none of its branches was the applied fix. No `az`/IaC change was executed for this incident.
- L10 lesson 5 (rca.md:541-543) only recommends STRUCTURAL treatment of the recurring credential/access class
  (`LL-006`: deterministic identities, documented "use AVD + correct role") — a class recommendation, NOT a
  shipped fix and NOT validated.
- Durable lesson captured as `LL-036` (rca.md:777). `rca.html` was noted stale vs the `.md` (rca.md:776-777).

---

## 3. Resolved identifiers (verbatim — the REAL Sandbox caller)

| Item | Value (verbatim) | Source |
|---|---|---|
| App Config store (data-plane host) | `vpp-appconfig-fbe-jupiter-qvc.azconfig.io` | rca.md:48, :16, C17:704 |
| Store name pattern (per-slot) | `vpp-appconfig-fbe-<slot>-<rand>` (here slot=`jupiter`, rand=`qvc`) | rca.md:48; MEMORY note |
| Resource group | `rg-vpp-app-sb-401` | rca.md:46, :16, C17:704 |
| Environment | **Sandbox** (NOT dev-mc; store is public-with-allow-list, reachable directly, NOT AVD-gated) | rca.md:46, :332, C16:703 |
| AKS cluster / context | `vpp-aks01-d` (Sandbox AKS) | rca.md:46, :771 |
| Namespace pattern | `<slot>` → here `jupiter` (`kubectl -n jupiter`) | rca.md:704, :593 |
| Frontend workload | deploy `frontend` (probed via `kubectl -n jupiter`) | C17:704 |
| Per-slot secret (k8s) | `application-secret` (probed alongside `frontend` deploy) | C17:704 |
| appconfig.js path in pod | `/etc/nginx/html/appconfig/appconfig.js` | rca.md:53-54 |
| Browser global injected | `window.VUE_APP_AZ_CONFIG_CONNECTION_STRING` | rca.md:53-54 |
| Feature-flag call (browser) | `…/.appconfig.featureflag%2F*` (a.k.a. `.appconfig.featureflag/*`) | rca.md:54-55, :703 |
| HMAC credential source | **access-key connection string** injected into the browser-served `appconfig.js` (from `application-secret`); NOT a Key Vault ref, NOT managed identity | C17:704, rca.md:53-54 |
| Subscription (real Sandbox store) | **NOT GIVEN** in these docs (the `839af51e-c8dd-4bd2-944b-a7799eb2e1e4` sub is the WRONG dev-mc store) | rca.md:217, :567 |
| Init container name | **NOT NAMED** verbatim — only "the frontend init container injects…" | rca.md:53 |
| Frontend pod label selector | **NOT SPECIFIED** beyond deploy `frontend` / ns `jupiter` | C17:704 |

Full live-probe evidence + repro commands cited at:
`.ai/tasks/2026-06-26-004_enrich-jupiter-fbe-appconfig-probe/findings.md` (P2-P9 + Timeline) — rca.md:64-65, :703-707.

---

## 4. HMAC vs RBAC — which auth, and the 401-vs-403 evidence

**CONFIRMED: browser SPA uses HMAC access-key (connection-string) auth. A 401 = bad/stale HMAC credential,
NOT an AAD RBAC 403. The store had keys ENABLED (`disableLocalAuth=false`) and the key was valid throughout.**

- C16 (rca.md:703) — "Exact failing call = browser GET `…/.appconfig.featureflag%2F*` to the FBE store; was
  401 (`WWW-Authenticate: HMAC-SHA256, Bearer`), now 200. Store `disableLocalAuth=false`, keys enabled,
  reachable."
- C19 (rca.md:705) — "The FBE's exact connection string returns **200 + real feature flags**
  (`AdditionalAssetPlanningSeries`, …) on the HMAC path → the access key is valid (refutes H2 for the real
  store)." Probe: `az appconfig kv list --connection-string`.
- C20 (rca.md:706) — azconfig.io serves CORS `access-control-allow-origin: *` on preflight and the 401, so
  the browser was not CORS-blocked and rendered the literal 401.
- General auth contract (both docs): 401 = authentication (bad/expired/deleted/stale/mis-signed credential);
  403 = authorization (missing data role) OR network block (`problem+json` `ip-address-rejected`/`nsp-rejected`).
  This incident was a literal 401 on the HMAC arm — the credential, not a role/network.

---

## 5. appconfig.js generation — what writes it, when, why a stale pod serves a bad one

- WHAT/WHEN: "The frontend **init container** injects the store's connection string into a browser-served
  file — `window.VUE_APP_AZ_CONFIG_CONNECTION_STRING` in `/etc/nginx/html/appconfig/appconfig.js` — and the
  SPA calls `…/.appconfig.featureflag%2F*` directly over **HMAC**." (rca.md:52-55). The connection string
  originates from the per-slot k8s secret `application-secret` (C17:704).
- WHY a stale pod serves a bad one: the frontend pod/RS was built DURING the provisioning window (RS 10:26Z),
  so its `appconfig.js` carried a connection-string credential that was not yet fresh/valid; the browser
  therefore got 401. When the pod was rebuilt (20:17Z) it served a valid `appconfig.js` → 200 (rca.md:60-62,
  C21:707). NOTE: the docs label this "credential-freshness" but do not fully mechanize why the earlier pod's
  key was rejected while the store key was valid throughout — see the ambiguity flag in section 1.

---

## 6. "Fix without manual pod restart" recommendation — validated?

**NONE was proposed or validated for this incident.** Because it SELF-RESOLVED, no repair was applied, so there
was nothing to validate. The only forward-looking item is the class-level structural recommendation (L10.5 /
`LL-006`: deterministic identities + documented "use AVD + correct role"; rca.md:541-543) and `LL-036` — neither
is a validated "avoid the restart" fix. So the precedent does NOT hand the new incident a proven non-restart
remedy; it hands it the expectation that provisioning-window FF-401s self-clear on frontend rebuild.

---

## 7. Verification method (EFFECT-based)

**EFFECT-based, flag call returns 200 — not exit-0.**

- C22 (rca.md:708) — "Duncan confirmed (2026-06-26, browser DevTools) the `.appconfig.featureflag/*` calls now
  return **200** ('before these were giving 401's … now it's not a problem anymore')." Source: Slack-Lists
  Rec0BC1FTLV35 reply + screenshot.
- C16/C19 above: live probe showed 200 + real flags on the exact HMAC connection string.
- L9 (rca.md:503-520) and how-to-fix "Verify by EFFECT" gates: a fix closes ONLY on the same failing call
  returning 200 from the failing context (browser DevTools / running slot), never on a green exit or the
  portal view.

---

## 8. A3 / UNVERIFIED / blocked items and open falsifiers

- The original root-cause A3s were RESOLVED by the 2026-06-26 live probe: **C16** (exact failing call/status —
  was A3 AVD-gated, now A1) and **C17** (which store the FBE reads — now A1). rca.md:703-704.
- **C18 (rca.md:709) — STILL A3, blocked:** "Whether Duncan's pending ArgoCD dev-mc access gap is linked to the
  401 — A3 — blocked: no evidence links them." (out of scope; resolving = ask platform / check CMC ticket).
- The dev-mc hypothesis set **H0-H3** (rca.md:126-147) and the entire L1-L12 dev-mc analysis are REFUTED/
  IRRELEVANT for the real caller (rca.md:56-59, :58) — retained only as the pre-probe reasoning trail. Do not
  reuse `vpp-applicationconfig-d`, its RG `mcdta-rg-vpp-d-res`, the AVD-gated boundary, or the H0-H3 ranking.
- Framing was originally conditional on the reported "401" being a literal status from a "rusty filer"
  (rca.md:716-721); that caveat is now moot for Jun-2026 (runtime-witnessed) but is a reusable caution for the
  new intake if the status is again a paraphrase.
- `rca.html` is stale vs the `.md` (rca.md:776-777).

---

## Coordinator-facing bottom line

The Jun-2026 precedent (same filer Duncan, same FBE FF-401) concluded a **transient provisioning-window HMAC
credential-freshness 401 on the per-slot Sandbox store `vpp-appconfig-fbe-jupiter-qvc.azconfig.io`
(RG `rg-vpp-app-sb-401`, AKS `vpp-aks01-d`, ns `jupiter`), served to the browser via
`/etc/nginx/html/appconfig/appconfig.js` (`window.VUE_APP_AZ_CONFIG_CONNECTION_STRING`), that SELF-RESOLVED
on frontend pod rebuild.** No permanent fix was merged; no non-restart remedy was validated. AMBIGUITY: the
precedent frames the resolution as SELF-RESOLUTION on rebuild, not as a deliberate manual pod restart being
"the fix" — treat any "restart fixed it" claim in the new incident as a distinct assertion needing its own
evidence.
