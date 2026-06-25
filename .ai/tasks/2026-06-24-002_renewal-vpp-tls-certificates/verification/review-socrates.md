---
title: Socrates adversarial review — SCOPE COMPLETENESS of *.vpp.eneco.com wildcard rotation
task_id: 2026-06-24-002
agent: socrates-contrarian
status: complete
timestamp: 2026-06-24T00:00:00Z
summary: |
  Adversarial scope-completeness review. VERDICT: PROBLEMATIC — scope is NOT proven
  complete. The determination enumerated consumers only across 3 MC subscriptions and
  only via App Gateway listeners. It NEVER looked at the Sandbox/Dev-Test sub
  (7b1ba02e) nor any non-AppGateway consumer (AGIC/ingress, Front Door, APIM, App
  Service, Kafka mTLS, function apps). The repo itself contains a Sandbox env running
  AGIC ingress for vpp.eneco.com hosts that the AGW-only method structurally cannot
  see. Seven distinct single-label X.vpp.eneco.com hostnames exist in the repo; only
  four were accounted for. The "production-only / this-one-object" claim is an
  enumeration over an incomplete search space, not a proof of completeness.
---

# Socrates Adversarial Review — Scope Completeness

## Key Findings

- F1: AGW-only enumeration cannot see ingress/Front-Door/APIM consumers — method gap
- F2: Sandbox sub 7b1ba02e (vpp-agg-sb + AGIC) was never enumerated — env gap
- F3: 7 single-label X.vpp.eneco.com hosts exist in repo; only 4 mapped — coverage gap
- F4: apex exclusion may be correct but rests on UNVERIFIED content read, not a SAN argument
- F5: SP-visible vs human-portal-visible divergence never reconciled
- F6: single settling fact + cheapest probe named (Azure Resource Graph cert-usage sweep)

> Lane: SCOPE COMPLETENESS + ASSUMPTIONS. I do not re-verify the AGW match; I attack
> whether the search space that produced the "production-only" claim was complete.
> READ-ONLY: I ran no Azure calls. All probes below are for the executor.
> My output is INFER until source-verified.

## STEELMAN (what the determination got right)

- The cryptographic match is real and well-evidenced: held PFX CN/SAN/issuer ==
  prd `wildcard-vpp-eneco-com` current content (artifact 02 §1, A1 data-plane read).
  `wildcard-vpp-eneco-com` on `vpp-ag-p` IS unambiguously a correct target.
- The 2-label exclusion logic is sound: `*.vpp.eneco.com` matches exactly one label,
  so `*.dev-mc.*` / `*.acc.*` certs are genuinely different certs (artifact 01 §1).
- The author EXPLICITLY left "prd-only vs apex" as an open user decision (02 §7) and
  flagged terraform drift / legacy-PFX / verification-reach as open risks (spec OR-1..6).
  This is not a careless determination. The gap is in the SEARCH SPACE, not the match.

The flaw is narrower and more dangerous than a wrong match: **the method that produced
"used ONLY in production" can only ever find App Gateway consumers in three named
subscriptions. It is structurally blind to everything else, so its "only" is unproven.**

## The core attack: "ONLY in production" is an enumeration, not a proof

Artifact 01 §2 builds the resource map from exactly three subscriptions
(dev `839af51e`, acc `b524d084`, prd `f007df01`) and §3 enumerates consumers exclusively
via `az network application-gateway ssl-cert/http-listener list`. Artifact 02 §2 then
concludes "used **only in production**." That conclusion is only as strong as the search
space. The search space excluded two entire dimensions — other subscriptions, and
non-AppGateway consumers — without ever stating it did so. Absence of evidence was
promoted to evidence of absence.

---

## F1 — Method gap: AGW-only enumeration is blind to non-AppGateway consumers (VERIFIED gap)

- **Finding**: Every consumer in artifact 01 §3 was found via App-Gateway listener
  listing. A KV cert/secret can be consumed without ever touching an App Gateway:
  AKS AGIC or NGINX/OpenShift ingress (CSI Secret Store / cert-manager pulling the KV
  cert), Azure Front Door / CDN custom-domain TLS, API Management custom domain,
  App Service / Function App custom-domain bindings, Kafka/broker mTLS. None of these
  appear in any `application-gateway` list. The determination has zero coverage of them.
- **Discriminating evidence (from THIS repo, A1)**: The Sandbox VPP env runs an **AGIC
  ingress** fronting `operations.dev.vpp.eneco.com` / `argocd.dev.vpp.eneco.com`
  (`.../2026_06_22_001_fbe_404_stefan/slack-intake.md:49,108`). That is a KV-cert-on-ingress
  topology the AGW-only sweep cannot see. Separately the VPP aggregation layer uses
  **Kafka mTLS certs** out of `vpp-agg-sb` (`.../2026_06_02_..._kafka_certs.../diagnosis.md:71`).
  Non-AGW cert consumption in VPP is not hypothetical — it is documented in adjacent incidents.
- **Conditional**: If ANY ingress/Front-Door/APIM/App-Service/Function consumer references
  the `*.vpp.eneco.com` cert (by KV secret URI or by a synced K8s TLS secret) → scope is
  incomplete; rotating only the prd KV object leaves that consumer on the OLD cert and it
  hard-fails at the **Jul 1 2026** expiry. Plan must change to: enumerate cert consumers by
  the cert itself, not by one consumer type, and add each found consumer as a rotation target
  or an explicitly-reasoned exclusion.
- **Status**: The METHOD blindness is VERIFIED (the method provably cannot see these).
  Whether a real non-AGW consumer of *this specific cert* exists is an OPEN question — see F6 probe.

## F2 — Environment gap: the Sandbox/Dev-Test subscription was never enumerated (VERIFIED gap)

- **Finding**: The resource map covers 3 subscriptions. A 4th VPP-bearing subscription
  exists and was never touched: **Sandbox / Dev-Test `7b1ba02e-bac6-4c45-83a0-7f0d3104922e`**,
  which hosts KV `vpp-agg-sb` and VPP workloads
  (`.../2026_06_02_..._kafka_certs.../cross-environment-findings.md:20`;
  `.../2026_06_22_001_fbe_404_stefan/slack-intake.md:51,106`). The user's prompt also
  names a runbook KV `vpp-aks-d` + AGW-with-AGIC in this sub — neither appears anywhere in
  the determination (grep of the task dir: zero hits for `7b1ba02e`, `vpp-aks`, `sandbox`,
  `AGIC`, `front door`, `apim`, `app service`, `openshift`, `kafka`, `ingress`).
- **Discriminating evidence**: `sandbox.vpp.eneco.com` and `sb.vpp.eneco.com` are live
  single-label hosts present in the repo (see F3) — i.e. there IS a `X.vpp.eneco.com`
  surface in the Sandbox namespace, and `*.vpp.eneco.com` would match it.
- **Conditional**: If `vpp-agg-sb` / `vpp-aks-d` (sub 7b1ba02e) holds or consumes a
  `*.vpp.eneco.com` cert → "production-only" is FALSE and scope must add the Sandbox target.
  If it holds only a 2-label `*.sb.vpp.eneco.com` or Kafka mTLS cert → it is correctly
  excluded, but that exclusion must be *stated with evidence*, not silently omitted.
- **Status**: The omission is VERIFIED. The content of the Sandbox KV is an OPEN question.

## F3 — Coverage gap: 7 single-label X.vpp.eneco.com hosts exist; only 4 were mapped (VERIFIED)

- **Finding**: Deduped across the repo, the single-label hosts under `vpp.eneco.com` are:
  `acc.`, `dev.`, `dev-mc.`, `iactest.`, `prd.`, `sandbox.`, `sb.` `.vpp.eneco.com`.
  All seven are matched by `*.vpp.eneco.com`. The determination mapped only the four prd
  app hosts (`agg/gurobi/apollo/flex-trade-optimizer`, artifact 01 §3 prd table) plus the
  env-apexes it reasoned about. It never accounts for `iactest.vpp.eneco.com`,
  `prd.vpp.eneco.com`, `sandbox.vpp.eneco.com`, `sb.vpp.eneco.com` as possible *.vpp cert
  consumers.
- **Caveat (honest)**: a hostname existing in a log ≠ that host is TLS-served by *this*
  wildcard today; some may be apex-style or served by env-specific certs. But the burden is
  on the determination to show coverage, and it did not enumerate these at all.
- **Conditional**: If any of `iactest/prd/sandbox/sb.vpp.eneco.com` terminates TLS using a
  cert object that is (or should be) the rotated wildcard → scope incomplete.
- **Status**: The 7-vs-4 coverage gap is VERIFIED; per-host cert binding is OPEN (F6 probe).

## F4 — Apex exclusion: probably correct, but for a fragile reason (PARTIAL)

- **Finding**: The held SAN explicitly includes `vpp.eneco.com` (artifact 01 §1), so the
  NEW cert *would* technically serve the apex. The determination excludes apex object
  `p-vpp-eneco-com` because a live read showed it is a **separate single-host
  `CN=vpp.eneco.com`** cert (artifact 02 §3, exp Jul 20 2026). That is the right call —
  but it rests entirely on the data-plane content read of `p-vpp-eneco-com`, and the
  exclusion is correct ONLY for "don't overwrite that object." It does NOT establish that
  leaving apex alone is operationally complete.
- **The real question the determination did not answer**: is the single renewal *intended*
  to consolidate apex + wildcard into one cert (the SAN supports it), or to keep two
  objects? That is a user-intent fork, not a technical one. Artifact 02 §7 surfaces it as an
  open decision — good — but the spec (line 25, 149) hard-codes "apex NOT in scope" while
  still flagging it open. That is an internal inconsistency: the scope table asserts a
  decision the open-items list says is undecided.
- **Conditional**: If user intent is "one cert for everything" → apex object should be
  rotated too (or retired), and "apex out of scope" is wrong. If "like-for-like, two
  objects" → current exclusion stands. MUST be resolved by the user before GO, not asserted.
- **Status**: Technical exclusion VERIFIED; intent/consolidation OPEN; spec/scope wording
  internally inconsistent (DEFECT).

## F5 — Actor divergence: SP-visible reality ≠ human-portal reality (OPEN)

- **Finding**: The colleague imported via **portal as a human** (artifact 01 §5/§7); the
  determination read content via the **prd SP** (artifact 02 §1). Azure RBAC + KV
  access-policy/RBAC can grant a human principal cert permissions the SP lacks, and KV data-
  plane visibility is principal-scoped. Artifact 01 §5 itself notes "import/create lookup
  returned empty (likely permission-string casing in legacy policies)" — direct evidence the
  SP's view is not authoritative. If the SP cannot see certain objects/versions, an "absent"
  object may exist but be invisible to the SP sweep.
- **Conditional**: If the SP lacks List on some object the human can see → the negative
  confirmations in artifact 02 §2 ("Neither is *.vpp.eneco.com … NOT a target") are
  under-powered: they prove "SP did not see a *.vpp cert there," not "no *.vpp cert exists
  there." Re-confirm at least the prd KV object inventory with the human identity, OR prove
  SP List parity.
- **Status**: OPEN. Cheap to settle (list objects under both identities and diff).

---

## F6 — The single fact that flips the claim, and the cheapest probe

- **Single external fact that makes "production-only / this-one-object" wrong**:
  *There exists at least one consumer of a `*.vpp.eneco.com` cert outside the prd
  `vpp-ag-p` listener set* — whether in another subscription (esp. Sandbox `7b1ba02e`),
  or via a non-AppGateway consumer (ingress/Front Door/APIM/App Service/Function),
  or an additional prd KV object holding the same wildcard.
- **Cheapest probe (control-plane only, no whitelist, no mutation) — Azure Resource Graph
  cert-usage sweep across ALL accessible subscriptions**:

```bash
# 1. Enumerate ALL subscriptions the actor can see (catch 7b1ba02e + any other)
az account list --query "[].{name:name, id:id}" -o table

# 2. Find every KV object named like the wildcard, in EVERY sub, in one query
az graph query -q "
resources
| where type =~ 'microsoft.keyvault/vaults'
| project kvName=name, sub=subscriptionId, rg=resourceGroup
" -o table   # then list certs per KV where reachable, OR:

# 3. Find non-AGW consumers that could bind a vpp cert (control-plane, no data-plane needed)
#    - Front Door / CDN custom domains, APIM, App Service, AKS (AGIC) — by resource type
az graph query -q "
resources
| where type in~ (
    'microsoft.network/frontdoors',
    'microsoft.cdn/profiles',
    'microsoft.apimanagement/service',
    'microsoft.web/sites',
    'microsoft.containerservice/managedclusters',
    'microsoft.network/applicationgateways')
| where subscriptionId == '7b1ba02e-bac6-4c45-83a0-7f0d3104922e'
   or subscriptionId == 'f007df01-9295-491c-b0e9-e3981f2df0b0'
| project type, name, subscriptionId, resourceGroup
" -o table
```

- **Decisive interpretation**:
  - If the sweep returns ONLY `vpp-ag-p` consuming a `*.vpp.eneco.com` object and no
    cert-bearing Front Door/APIM/App Service/AKS-AGIC references the wildcard →
    "production-only / this-one-object" is SUPPORTED across the full space → proceed.
  - If it returns a `*.vpp` cert in `7b1ba02e` or a non-AGW consumer → scope is INCOMPLETE
    → add target(s) or document an evidenced exclusion before GO.
- **Belief-change**: this is the one probe that converts the determination from an
  enumeration-over-a-subset into an enumeration-over-the-whole-space. Until it runs, the
  "only" is INFER, not FACT.

---

## SUPERWEAPON DEPLOYMENT

- SW1 Temporal Decay: APPLIED — any unmapped consumer on the OLD cert silently keeps working
  until **Jul 1 2026 00:00**, then hard-fails with no rotation pre-staged. The gap is invisible
  today and only manifests at expiry. (F1/F2)
- SW2 Boundary Failure: APPLIED — the cert↔consumer boundary was enumerated from the consumer
  side (AGW) for one type only; cross-type and cross-subscription boundaries unchecked. (F1)
- SW3 Compound Fragility: APPLIED — three correlated assumptions ("only AGW consumes it" +
  "only 3 subs exist" + "SP sees everything the human sees") share one root: the sweep was
  scoped to a convenient subset. One common cause (subset enumeration) breaks all three. (F1/F2/F5)
- SW4 Silence Audit: APPLIED — what is MISSING is the whole point: no Resource-Graph
  cross-sub query, no non-AGW consumer query, no human-vs-SP inventory diff, no enumeration of
  `iactest/prd/sandbox/sb.vpp.eneco.com`. (F1–F5)
- SW5 Uncomfortable Truth: APPLIED — "scope CONFIRMED (100%)" (artifact 02 title) overstates
  the epistemic state. The match is confirmed; the COMPLETENESS is not. A "100%" label on an
  incomplete search space is the most dangerous artifact in the package because it discourages
  the very probe (F6) that would close the gap.

## DOT-CONNECTION

F1+F2+F3+F5 are not four independent nits — they are one root cause: **the determination
enumerated consumers from a convenient subset (AGW listeners, 3 subs, SP identity) and labeled
the result "only."** Fixing the wording is cosmetic; the fix is one cross-space sweep (F6) that
addresses all four at once. The repo's own adjacent incidents (Sandbox AGIC FBE-404; vpp-agg-sb
Kafka mTLS) are the live proof that VPP cert consumption escapes the AGW/3-sub frame.

## VERIFIED vs OPEN (explicit)

- VERIFIED: method is AGW-only (01 §3); only 3 subs enumerated (01 §2); Sandbox sub 7b1ba02e
  is a real VPP env never enumerated (repo A1); 7 single-label vpp hosts exist, 4 mapped (repo
  A1); SP's own lookup returned empty/casing-suspect (01 §5); scope/open-items wording is
  internally inconsistent on apex (02 §7 vs spec §0/§10).
- OPEN (needs the F6 probe / human-identity diff): whether any real `*.vpp.eneco.com` consumer
  exists in 7b1ba02e or via non-AGW resource types; whether `iactest/prd/sandbox/sb` are
  *.vpp-served; whether SP List parity holds; user intent on apex consolidation.

## META-FALSIFIER (how THIS review could be wrong)

- If the F6 Resource-Graph sweep returns nothing outside `vpp-ag-p`, then the determination's
  "only" was accidentally correct and my findings collapse to "you reached the right answer by
  an unproven method" — still worth the probe, but not scope-changing.
- I am ASSUMING repo hostnames (`iactest/prd/sandbox/sb.vpp.eneco.com`) correspond to live
  TLS endpoints; some may be stale, internal-only, or apex-style. I did not (cannot, READ-ONLY
  on Azure) verify their current cert binding — that is exactly what F6 settles.
- I am ASSUMING the Sandbox env uses certs in the `vpp.eneco.com` zone; the documented Sandbox
  cert usage I found is Kafka mTLS (`esp-eet-vpp-dt`), which is a DIFFERENT cert family — so
  Sandbox may legitimately not consume `*.vpp.eneco.com` at all. That weakens F2 to "must check,"
  not "is wrong."
- Domain gap: I lack the Eneco DNS authority and the AGIC ingress manifests; a DNS/ingress dump
  would over-rule my inference either way.

## RECOMMENDATION

REVISE before GO. Do not approve "production-only / this-one-object" as a *proven* scope until
the F6 cross-subscription, cross-consumer-type Resource-Graph sweep runs and the human-vs-SP
object-inventory diff is taken. Concretely:
1. Run F6 probe across all accessible subs incl. 7b1ba02e (control-plane, no whitelist needed).
2. Resolve the apex consolidation fork with the USER (close the spec §0-vs-§7 inconsistency).
3. Re-confirm the prd KV object inventory under the human identity (or prove SP List parity).
4. Re-title artifact 02: drop "100%/CONFIRMED" until completeness — not just the match — is shown.
The AGW match is solid; the rotation can proceed for `wildcard-vpp-eneco-com` regardless. The
risk is purely OMISSION: a second consumer left on a cert that dies Jul 1 2026.
