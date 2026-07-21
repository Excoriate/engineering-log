---
task_id: 2026-07-19-003
agent: socrates-contrarian
status: complete
timestamp: 2026-07-19T00:00:00Z
summary: |
  Adversarial gate on the FBE-401 vault build. Executor's correction DIRECTION is
  right (June's "transient/self-heals/NONE needed" is falsified by the RCA's A1
  fleet evidence and the proven no-refresh-path). But two calibration overclaims and
  one placement violation must be fixed before write: (A) "PERMANENT ... on slot
  destroy->recreate" overclaims an A2-INFER mechanism and an A3-unreconstructable
  ordering as demonstrated fact; (B) "does NOT self-heal" is false absolute — the
  pod recovers on any restart (June's was incidental), and the fleet symptom is
  HTTP 000, not Duncan's 401, so both must not hide under a bare "401" headline;
  (C) new pattern note is premature abstraction from ONE system and overlaps two
  existing parent lessons; (D) a generic K8s credential-drift heuristic is routed
  to 3-resources by BOTH _index contracts, not llm-wiki/patterns/debugging.
  Verdicts: A REVISE, B REVISE, C REVISE, D REJECT-as-proposed.
---

# Socrates Contrarian — FBE-401 Vault Build Challenge

## Key Findings

- **Lane A: REVISE** — mechanism is A2/A3 in the RCA; write it as INFER, not fact; "permanent" must mean "standing gap", per-slot symptom clears on restart.
- **Lane B: REVISE** — preserve "recovers on pod restart (June incidental)"; name BOTH surface variants (401 store-resolves vs HTTP 000 store-deleted).
- **Lane C: REVISE** — no new note yet on one-system evidence; strengthen LL-036 + backlink the two existing parent lessons.
- **Lane D: REJECT-as-proposed** — generic heuristic → 3-resources per fbe/_index:116 and debugging/_index:22; Eneco specifics stay in F22/LL-036.
- **Silence:** correction must NOT delete the "do NOT rotate keys / re-run IaC / destroy store" guardrails (destroying the store regenerates the drift).

**Win condition met:** yes — ≥1 non-trivial flaw found that changes what gets written
(Lane A overclaim, Lane B 401/000 conflation, Lane D placement), plus a Silence finding
(dropped guardrails) that would make a naive rewrite operationally dangerous.

## Steelman (Rule 9 — the executor is substantially right)

The correction's DIRECTION is evidence-backed and must not be rolled back:

- June's framing "transient / self-heals / NONE needed" IS falsified. `A1`: 5 of 6 active
  slots have served a stale credential for up to ~11 days with `restarts=0`
  (rca.md L7 lines 132-137; live-probe-findings lines 50-55). A condition that persists
  11 days without clearing is not "transient".
- There is provably NO internal refresh path (`A1`, rca.md L4 line 93; live-probe-findings
  lines 31-41): no Reloader, no checksum annotation, healthz-only probe, init-once emptyDir.
- The permanent fix (pipeline rollout-restart + Stakater Reloader) is genuine net-new
  engineering (how-to-fix.md P1/P2; live-probe-findings line 121).

So every verdict below is about CALIBRATION and PLACEMENT, not about reversing the correction.
Do not over-rotate to "leave F22/LL-036 as they were" — that would re-institutionalize a
diagnosis the RCA has disproven.

---

## LANE A — OVERCONFIDENCE SWAP

**Verdict: REVISE.**

The executor's proposed root cause — *"PERMANENT frozen-snapshot credential drift on slot
destroy->recreate; the store name embeds a Terraform random_string that regenerates on state
rebuild -> new store + new HMAC keys"* — overclaims on two axes the RCA itself refuses to make.

**Discriminating evidence:**

1. The store-regeneration mechanism is **A2 INFER**, not A1 FACT, in the RCA's own claim table:
   > rca.md line 219 — Claim 3 "Store identity/keys change on slot recreate (random suffix
   > regenerates on state rebuild)" → **A2**.
   The executor plans to write an A2 mechanism as demonstrated causal fact.

2. The per-slot recreation ORDERING is **A3 [blocked: not reconstructable]**, and the naive
   "recreate regenerated the suffix" story is explicitly FALSIFIED for at least some slots:
   > rca.md L7 line 141 — "The current stores' `createdAt` ... *predates* several pods ... that
   > nonetheless bake an *older, now-deleted* store. This falsifies any clean 'pod baked the
   > current store at birth, store recreated afterwards' story ... The exact per-slot recreation
   > ordering is **not reconstructable** ... and is not asserted."
   The same line shows the `application-secret` can itself **lag** the live store — i.e. drift
   can arise WITHOUT a clean destroy->recreate.

3. "PERMANENT" is defensible ONLY in the RCA's own sense — a standing architectural gap
   ("permanent variant ... that recurs until the refresh gap is closed", rca.md L10 line 166) —
   NOT in the sense "never recovers." Any individual slot's symptom clears on a pod restart
   (Lane B).

**Exact corrected wording allowed (F22 cause / LL-036 root cause):**

> **Cause:** The frontend bakes the per-slot App Config HMAC connection string **once** into a
> static `appconfig.js` (init container `init-myservice` → emptyDir) at pod start. When the
> slot's App Config store is regenerated with a new name + new HMAC keys, CSI updates the K8s
> `application-secret` but **nothing restarts the frontend pod** (no Stakater Reloader, no
> config-checksum annotation, healthz-only probe, and the credential is out-of-band so ArgoCD
> sees no manifest diff). The pod keeps serving the stale credential and **cannot self-correct**;
> it recovers only when the frontend pod is next restarted for any reason.
> The primary known regeneration trigger is a slot **destroy→recreate** (delete pipeline 2629 →
> create 2412), where the store-name `random_string` suffix regenerates — **[A2 INFER]**, not a
> per-incident-demonstrated sequence. **[A3]** exact per-slot recreation ordering is not
> reconstructable, and `application-secret` can itself lag the live store, so verify against the
> **live Azure store**, not merely `application-secret`.
> Demonstrated live 2026-07-19: 5 of 6 active slots bake a since-deleted store (`A1`).

Keep the `[A2]`/`[A3]` labels in the note (the fbe catalog and llm-wiki both use evidence
labels). Dropping them is the overconfidence swap.

---

## LANE B — SELF-HEAL SEMANTICS

**Verdict: REVISE** (highest operational value — protects the catalog's status-routing purpose).

**B1 — "does NOT self-heal" is a false absolute.**

Discriminating evidence:
> LL-036 lines 36-38 — "the healthy pod serving a valid `appconfig.js` was rebuilt at 20:17Z,
> after which the calls return 200. **Self-resolved.**"
> rca.md L4 line 93 / L10 line 163 — the pod "cannot self-correct" (no internal refresh path).

Reconcile: the **pod cannot self-refresh** (true, `A1`), but an **external pod restart**
(incidental or forced) recovers it. June looked "self-resolving" only because an incidental
rebuild happened ~9.5h after Duncan tested. A future reader who reads a bare "does NOT self-heal"
may over-escalate.

Allowed wording (recurrence/behaviour line):
> Does **not** clear on its own (no internal refresh path); the symptom persists until the
> frontend pod is restarted — for ANY reason (deploy, node drain, eviction, manual). June's case
> looked "transient" only because an incidental pod rebuild masked it ~9.5h later.

Set `recurrence_status: active_inherent` (architectural; persists until the refresh gap is
closed) — NOT "transient, self-heals".

**B2 — filing HTTP 000 and 401 under one "401" headline is a distortion.**

Discriminating evidence:
> rca.md line 40 ("Precise surface note") — "the 5 drifted slots bake a *deleted* store, so their
> flag call currently fails to connect (`HTTP=000`), **not with a 401** ... the RCA does not claim
> the aged fleet slots currently emit Duncan's exact 401."
> live-probe-findings lines 70-80 — live store → 401 `WWW-Authenticate: HMAC-SHA256`; deleted
> store → `HTTP=000`. "Same root cause, two timing variants."

This matters MORE here than anywhere because F22 lives in a catalog whose entire discipline is
status-based routing (F22 "Gotcha" line 636; the 401-vs-403 lesson). The Symptom→F# matrix keys
F22 on "Browser 401" (fbe-catalog line 669). If the rewrite keeps a bare "401" headline, a future
on-call seeing an HTTP 000 / connection error / DNS-not-resolve will NOT match it to F22, and the
mechanism's own fleet evidence (000) contradicts the headline.

Required: name BOTH surface variants explicitly, and update the Symptom→F# matrix row.
Allowed wording (symptom):
> **Symptom (two surface variants, one mechanism):** (a) **HTTP 401** `WWW-Authenticate:
> HMAC-SHA256` when the baked store still resolves but presents a rotated/stale key (Duncan's
> variant); (b) **HTTP 000 / connection failure** when the baked store has been fully deleted
> (the aged-fleet variant). Both = a frozen snapshot of a mutable credential; both fixed by a
> frontend pod restart. Portal shows flags fine (control-plane ≠ data-plane).

Add matrix row: `Browser connection-error / HTTP 000 / DNS-not-resolve on .appconfig.featureflag
for an aged FBE slot | F22 | baked store deleted; compare baked appconfig.js endpoint to live
Azure store; restart frontend`.

---

## LANE C — NEW-NOTE SPRAWL

**Verdict: REVISE** (do not create the standalone pattern note yet; strengthen + link).

**Discriminating evidence:**

- No duplicate exists yet: `find` for `frozen-snapshot` / `credential-drift` / `reloader` /
  `stakater` across the vault → **zero hits**. So it is not a literal duplicate.
- But the debugging/_index bar is **"confirmed effective in at least 2 occurrences"** (debugging/
  _index line 11). The frozen-snapshot mechanism has 2 incidents (June + July) but **ONE system**
  (the VPP FBE frontend `appconfig.js`). That is one system observed twice, not a cross-system
  pattern.
- It substantially OVERLAPS two existing parents as their specialization:
  - `green-status-is-not-realized-effect.md` line 17 — "A GREEN step/probe proves a proxy signal,
    not the realized effect" (ArgoCD Synced + pod Ready are exactly this).
  - `kubernetes-running-ready-does-not-imply-functional.md` line 29 — "Running 1/1 proves process
    aliveness, not functional health" (healthz-only probe is exactly this).
  The frozen-snapshot note would restate both unless it isolates its UNIQUE increment.

The genuinely NEW, reusable increment (not in either parent): *an out-of-band mutable secret is
refreshed in the K8s Secret by CSI but the consumer snapshotted it once (init-once emptyDir) with
no Reloader/checksum trigger → stale-until-restart.* That is the classic "Reloader gap." It is
real and reusable — but it is **generic Kubernetes knowledge**, which drives Lane D.

**Better graph move (allowed):** strengthen **LL-036** with the full mechanism + fix, add the
two surface variants, and add **bidirectional backlinks** F22 ↔ LL-036 ↔
`green-status-is-not-realized-effect` ↔ `kubernetes-running-ready-does-not-imply-functional` ↔
the 401-vs-403 note. Defer a standalone note until either (i) a SECOND distinct system exhibits
the frozen-snapshot/Reloader gap, or (ii) it is written as a generic 3-resources note (Lane D).
If a note is created anyway, it MUST open by differentiating its increment from the two parents
and backlink them, or it is graph duplication.

---

## LANE D — PLACEMENT BOUNDARY

**Verdict: REJECT as proposed** (llm-wiki/patterns/debugging/ is not the contract-authorized home).

**Discriminating evidence (the _index contracts):**

- `llm-wiki/patterns/debugging/_index.md` line 15-18 "What belongs here" = **agent-operational**
  debugging (frontmatter hooks, MCP timeouts, vault wikilink repair). Line 22 "What does NOT
  belong here: **Technology-specific debugging guides (goes to 3-resources/)**"; line 23 "General
  troubleshooting unrelated to agent operations (goes to 3-resources/)."
- `fbe/_index.md` line 116 — "Generic Kubernetes / ArgoCD / Terraform knowledge — those graduate
  to **3-resources/** once Eneco specifics are removed."

A "K8s/Azure credential-drift heuristic" (CSI secrets-store + Reloader + emptyDir + App Config
HMAC) is precisely **technology-specific / generic Kubernetes** knowledge. Both contracts route
it to **3-resources/**, not llm-wiki/patterns/debugging.

**The counter-precedent, ruled on:** the sibling `http-status-localizes-the-failing-layer.md`
IS a tech-specific networking heuristic living in patterns/debugging, which superficially
authorizes tech heuristics there. But (i) that note sits in tension with the folder's own literal
"what does NOT belong" (line 22) — it is a de-facto exception, not a stated contract; and (ii) the
frozen-snapshot heuristic is MORE tech-stack-specific (a named controller + volume type + Azure
service) than a generic "read the status code" heuristic, so it is a weaker fit than the exception
that already stretches the rule. One stretched precedent does not override two explicit "→
3-resources" contracts.

**Ruling / allowed placement:**
- Eneco-specific mechanism → **F22 (fbe catalog) + LL-036 (llm-wiki lesson)** — correct homes,
  already exist. Fix them per Lanes A/B.
- Generalized heuristic, IF written → **`3-resources/`** (e.g. a Kubernetes "out-of-band
  secret rotated but consumer not rolled — the Reloader gap" note), with backlinks from F22/LL-036.
- **Not** a new `llm-wiki/patterns/debugging/frozen-snapshot-credential-drift.md`.

---

## SILENCE AUDIT (SW4 — what the plan omits; this is never N/A)

**MUST-PRESERVE guardrail (dropping it makes the rewrite operationally dangerous):** the June
note and 401-vs-403 lesson carry an explicit "do NOT over-react" list — *do not rotate App Config
keys, do not re-run/`terraform destroy` the App Config IaC, do not grant Data roles, do not touch
dev-mc* (F22 line 634; rca.md L12 line 208; how-to-fix "One-way doors" lines 236-247). The
executor's swing to "PERMANENT, needs engineering" risks a future on-call over-reacting with
exactly these actions — and **destroying/recreating the store is the very thing that regenerates
the drift** (how-to-fix line 246: "The FBE delete pipeline 2629 runs `terraform destroy` — it is
... the very step that regenerates the store next create"). The corrected note MUST retain the
do-NOT list alongside the new permanent fix. Verdict: **MUST-FIX**.

Other silences:
- **Metadata not just prose:** F22's title "...provisioning-window 401 (self-heals)", its
  `Mechanism class: F — Configuration not refreshed (provisioning-race sub-class)` (line 624), and
  its `recurrence_status` (line 625) all encode the falsified framing. All three must change
  ("provisioning-race sub-class" → e.g. "out-of-band-credential-snapshot sub-class"), or a reader
  filtering by class/title is misled even if the prose is fixed.
- **Temporal decay (SW1):** "5 of 6 slots drifted" is a 2026-07-19 snapshot; write it as
  "demonstrated live 2026-07-19", never as a standing "5 slots are broken" fact.
- **Fix status honesty (SW2/actionable-artifact-gate):** Reloader is **A2** and **not installed**
  (live-probe-findings line 37; rca.md line 221). Do not write "Reloader fixes it" as an available
  fact — write "proposed fix, requires installing the controller"; note the side-effect that
  `application-secret` has 13 keys so the frontend also rolls on unrelated key changes
  (how-to-fix line 168).
- **Supersession, not silent overwrite (SW5):** LL-036 lines 32-38 currently state the WRONG
  "provisioning-window credential-freshness ... Self-resolved" as `confidence: validated`.
  Overwriting silently loses the meta-lesson. Mark it as superseded/corrected by this RCA and keep
  the epistemic lesson: *a "self-heals" claim must be backed by a proven refresh path; here none
  exists, so the earlier transient framing was a misdiagnosis.*

---

## PRIORITIZED MUST-FIX BEFORE WRITE

1. **[Lane B2 / catalog integrity]** Name BOTH surface variants (401 store-resolves vs HTTP 000
   store-deleted) in F22 symptom AND add the 000 row to the Symptom→F# matrix. Without this the
   status-routing catalog misroutes half the mechanism.
2. **[Silence / safety]** Retain the "do NOT rotate keys / re-run IaC / destroy the store / touch
   dev-mc" guardrails in the rewrite. Destroying the store regenerates the drift.
3. **[Lane A]** Write the destroy→recreate regeneration as **[A2 INFER]** and keep the **[A3]**
   "per-slot ordering not reconstructable; application-secret can lag; verify vs live Azure store"
   caveat. Do not present it as demonstrated per-slot causation.
4. **[Lane B1]** Replace "self-heals"/"does NOT self-heal" with "cannot self-refresh; recovers
   only on a pod restart (June's was incidental)"; set `recurrence_status: active_inherent`.
5. **[Lane A / metadata]** Change F22 title (drop "provisioning-window", drop "(self-heals)") and
   the "provisioning-race sub-class" mechanism-class label.
6. **[Lane D]** Do NOT create `llm-wiki/patterns/debugging/frozen-snapshot-credential-drift.md`.
   Put Eneco specifics in F22/LL-036; if a generic heuristic is warranted, place it in
   `3-resources/` with backlinks.
7. **[Lane C]** Strengthen LL-036 + add bidirectional backlinks to the two parent lessons and the
   401-vs-403 note instead of a standalone pattern note; defer a standalone note until a second
   distinct system or a proper 3-resources write.
8. **[Silence / SW5]** Mark the old LL-036 root cause as superseded (not silently overwritten);
   preserve the meta-lesson about the misdiagnosis.
9. **[Silence / SW2]** State Reloader as a proposed, not-yet-installed **[A2]** fix with its
   multi-key side-effect caveat.

---

## META-FALSIFIER (Rule 11)

- **What would prove this review wrong:** if the RCA elsewhere classified the store-regeneration
  mechanism or the per-slot ordering as **A1** — it does not (line 219 = A2; line 141 = A3), so
  Lanes A/B stand. If patterns/debugging/_index welcomed tech-specific heuristics — line 22 says
  the opposite; the http-status sibling is the only counter-signal and I ruled it a stretched
  exception, so Lane D is a judgement call the coordinator may overrule with the sibling as
  precedent (if so, the new note still MUST differentiate its increment per Lane C).
- **Assumptions I am making:** I treat the RCA + live-probe-findings as accurate per the
  coordinator's instruction; I did not independently re-verify the Terraform ForceNew /
  random_string behaviour (the RCA labels it A2 and my finding is precisely that it be written as
  A2, so no re-probe is needed).
- **Domain gap:** whether an as-yet-unseen SECOND system exhibits the frozen-snapshot/Reloader gap
  would flip Lane C toward "create the note now" — I have no evidence of one in the vault today.
