---
title: "Socratic Adversarial Receipt — FBE/Duncan App-Config 401 RCA: assumptions + hypothesis ranking attack"
type: research
status: complete
task_id: 2026-06-22-006
agent: socrates-contrarian
timestamp: 2026-06-22T15:40:00+02:00
summary: >-
  Adversarial attack on the assumption layer and hypothesis ranking of rca.md. Eight findings.
  The two-ticket separation is DIRECTIONALLY sound but rests on an over-literal reading of a
  paraphrased "401" and silently assumes a data-plane Entra call (H1/H3 frame) the evidence does
  not establish for the FBE READ path. The hypothesis ranking has a frame collision: H1 (interactive
  token) is ranked High but no evidence shows Duncan ran an interactive `az appconfig` command —
  the documented set-path is a PIPELINE. A better-fit hypothesis (un-applied/un-approved pipeline,
  the Sep-2025 precedent) is ranked H-absent/buried despite Duncan's verbatim "FFs cannot be set"
  matching it. Two A1-labeled claims are FACT-laundered (rest on sidecar A2 inference). The
  "portal = control-plane only" inference is over-claimed against a vault note saying portal 401s
  ALSO happen on private-endpoint resources (Edge). Verdict: framing survives but is OVERCOMMITTED;
  ranking needs reordering. All verdicts INFER pending coordinator source-verification.
---

# Socratic Adversarial Receipt — FBE/Duncan App-Config 401 RCA

**Win condition (mine alone):** destroy the RCA's *assumptions* and *hypothesis ranking*. I do not
review formatting, safety gates, or goal-fidelity. Every verdict below is **INFER** until the
coordinator source-verifies the cited file:line / quote.

**Target:** `log/employer/eneco/02_on_call_shift/2026_june/2026_02_22_003_feature_flags_fbe_duncan/rca.md`
**Source-of-truth for attack:** the five sidecars under `.ai/tasks/2026-06-22-006_fbe-duncan-rca-deliverables/context/`.

**Steelman first (Rule 9):** The RCA's central move is defensible and, frankly, well-executed. It
refuses to converge on a single cause, ships a ranked hypothesis SET, names the one collapsing probe,
and is explicit that the probe is AVD-gated. The "401 ≠ 403 ≠ timeout" spine is correctly sourced to
Microsoft Learn (msdocs §Q2/Q3/Q5, all A1). The author clearly understood the problem they were
solving: stop the next on-call from treating the new ticket as a recurrence of the closed network
ticket. My attacks below do not dispute that the two tickets are *probably* different. They dispute
that the RCA has *earned* the confidence it asserts, and that its ranking points at the best-fit cause.

---

## FINDING 1 — The two-ticket separation is over-committed: it assumes the new "401" is literal AND assumes a data-plane call, neither of which the evidence establishes

**Claim attacked (rca.md:56-60, Exec summary):**
> "The new symptom is an **HTTP 401 from inside AVD** — i.e. the network path already succeeded and
> the *credential* was rejected. **They are two different failures at two different layers...**"

**Why it is over-claimed.** The separation is built on a TWO-LINK chain, and the RCA treats both links
as solid when only one is:

- Link A: "the new symptom is a literal HTTP 401." Source = Duncan's verbatim CSV text
  (slack-harvest.md:48): *"the calls for app configuration are failing. So the FFs cannot be set
  properly as I am getting 401's."* This is a **frontend engineer who self-describes as rusty**
  (slack-harvest.md:75, *"I have not worked on VPP in a bit"*) **loosely paraphrasing** an error in a
  one-line intake ticket. The RCA's own diagnosis-synthesis admits this in passing (diagnosis-synthesis.md:60-62:
  *"If the tooling is loosely reporting an auth error that is really a 403, the cause shifts to RBAC"*)
  — but the RCA prose (rca.md:56-77) then proceeds as if the literal-401 reading is settled.
- Link B: "therefore the network path succeeded and a credential was rejected." This only follows IF
  the 401 is literal AND the call is a data-plane call. A `403 ip-address-rejected` (network) ALSO
  means the network path *reached the server* — so even a network-class error from a misconfigured
  AVD (DNS zone not linked, per vault §2b) reaches the endpoint. The RCA correctly notes a network
  block is 403 not 401 — but that defense is only as strong as Link A (the literal-401 assumption).

**Mechanism of failure (Rule 8).** If Duncan's "401" is a paraphrase of a 403 (or even a tooling
banner that said "401/403 unauthorized"), then the entire layer-separation argument
(network-vs-auth) loses its load-bearing premise, because a 403 is *also* not the EARLIER timeout but
is *also* not a "credential rejected" story — it would be RBAC or network. The two tickets could
still be different, but the RCA's *stated reason* for why ("it's a credential failure") would be wrong.

**What evidence would collapse the separation (the Socratic falsifier):** if the exact failing call
turns out to be a **403 `ip-address-rejected`** from an AVD whose private-DNS zone is not linked for
`vpp-applicationconfig-d` (vault §2b documents AVD-without-zone-linked → public IP → timeout; a
partial-link state could plausibly produce a network 403), then the new ticket IS a near-cousin of the
earlier network ticket — same root family (MC private-endpoint reachability), different surface. The
RCA explicitly forbids this reading ("the timeline forbids treating the new ticket as a recurrence,"
rca.md:378) with more confidence than the evidence supports.

**If accepted → which RCA section must change:** Exec summary (rca.md:56-60) and L7 (rca.md:378) must
downgrade from "they ARE two different failures at two different layers" to "they are *probably*
different layers *conditional on the 401 being literal*; the discriminator probe (L11 Step 2) is what
confirms the separation, not the timeline." The framing-confidence line in §Confidence (rca.md:602-606,
*"Confidence in the framing ... is high"*) must drop to MEDIUM until Link A is probed.

**Classification: DEFER** — risk: the separation may be correct, but it is asserted with unearned
confidence. Revisit condition: L11 Step 2 returns the literal status. If it is 401 → finding partially
dissolves (separation confirmed). If it is 403-network → separation as *stated* is wrong.

---

## FINDING 2 — Literal-401 over-commitment: the RCA's own spine is built on a paraphrase, and the librarian sidecar already flagged the key 401 status as INFER not FACT

**Claim attacked (rca.md:71-77, the self-described "spine"):**
> "What does a 401 actually mean here? Microsoft's own documentation is unambiguous and it is the spine
> of this RCA: on the App Configuration data plane, **401 = authentication failed**..."

**Why it is wrong/overclaimed.** Two distinct over-commitments:

1. **The "401" input is a paraphrase, not an observed status line.** slack-harvest.md:63 explicitly
   warns: *"the literal Details text says 'though AVD' (typo)"* — i.e. the harvester was careful about
   verbatim fidelity precisely because Duncan's text is informal. The "401" is Duncan's word, not a
   captured `HTTP/1.1 401` status line. The RCA builds an entire "the credential itself failed"
   spine on a noun typed by a self-described rusty frontend dev in a tracker field. The RCA *does*
   carry C16 (exact status) as A3-blocked — good — but the prose does not propagate that uncertainty
   into the spine; it states the spine as decisive (rca.md:71, *"unambiguous ... the spine of this RCA"*).

2. **Even the Microsoft contract has an INFER hole the RCA quietly promotes to FACT.** msdocs-appconfig-auth.md:74
   states plainly: *"No Microsoft Learn page states the disabled-keys-connection-string status code
   verbatim ... the specific number is INFER, not FACT."* Yet rca.md C9 (rca.md:587) labels
   *"Disabling local auth deletes all keys; connection-string callers then 401"* as **A1**. The "deletes
   all keys" half is A1 (quoted). The "then 401" half is the librarian's **A2 INFER** (msdocs §Q1
   reasoning chain (1)-(4)). See Finding 4 for the FACT-laundering detail; flagging here because it
   *directly* weakens the spine: the H2 ("literal-401 access-key path") branch's status prediction is
   itself an inference, not a documented fact.

**Mechanism.** The RCA presents "401 = credential" as a documented dichotomy that mechanically routes
the fix. But (a) the input "401" is unverified, and (b) one of the two 401 sub-mechanisms (disabled-key
→ 401) is itself INFER. So the spine is a probabilistic argument dressed as a deductive one. That is an
epistemic-status error, not a factual error — but it changes how much weight the next on-call puts on
"it must be the credential."

**If accepted → which section changes:** rca.md:71 — soften "unambiguous and it is the spine" to "the
*best-supported* reading, *conditional on the reported 401 being literal*." C9 label (rca.md:587) must
split to A1 (deletes keys) + A2 (then 401), matching the librarian's own labeling.

**Classification: REBUT** (it carries doc evidence): the over-commitment is provable against
msdocs-appconfig-auth.md:74 (verbatim: *"the specific number is INFER, not FACT"*) and the C9 A1 label
at rca.md:587.

---

## FINDING 3 — Hypothesis ranking frame collision: H1 (interactive token) ranked High, but NO evidence shows Duncan ran an interactive data-plane command; the documented set-path is a PIPELINE

**Claim attacked (rca.md:80-87 + diagnosis-synthesis.md:133, the ranking):**
> H1 = "Duncan is driving the set/fetch from AVD with an **interactive identity whose token is stale
> or points at the wrong tenant**" — ranked **High / leading**.

**Why the ranking is mis-ordered.** H1 silently assumes Duncan personally executed an interactive
Entra data-plane call (`az appconfig ...`) from AVD. But the mechanism sidecar establishes that **the
"set the flags" path is an Azure DevOps Terraform pipeline**, not an interactive command
(fbe-ff-mechanism.md:34-41, Q5; rca.md:62-69 itself says the write path "is an Azure DevOps Terraform
pipeline"). There is **zero evidence in any sidecar** that Duncan ran `az appconfig feature set`
interactively. Duncan is a **frontend engineer** (slack-harvest.md:203) whose actual described action
is "looking at it through AVD" and "the FFs cannot be set" — language that fits **the pipeline didn't
apply them** at least as well as "my interactive token was rejected."

The RCA L6 even surfaces the better-fit precedent and then under-weights it: rca.md:354-357 cites the
**Sep-2025 case where Duncan himself hit "FF didn't appear" because the App Config pipeline was
waiting for approval** — *the same engineer, the same FBE-flag-not-set symptom, resolved with no auth
fix at all.* In diagnosis-synthesis.md this is **H-absent from the ranked auth set** and demoted to a
"cheap exclusion" (L11 Step 7). That is a ranking inversion: the **strongest base-rate prior for THIS
filer on THIS symptom** is "unapplied/unapproved pipeline," yet it is not even in the H1-H7 table as a
peer hypothesis (diagnosis-synthesis.md:131-139 lists H1-H7; "un-approved pipeline" appears only as the
Sep-2025 precedent, not as a ranked hypothesis).

**Counter-hypothesis (Rule 2) — H0, the missing hypothesis:** *The Jupiter FBE feature flags were
never applied because the `appconfiguration/devmc.pipeline.yml` run is pending its approval gate
(`vpp-core-appconfiguration-devmc`), and Duncan — rusty, frontend — paraphrased the FE's downstream
failure ("calls failing / FFs cannot be set / 401") without a literal captured status.* Discriminating
evidence: the ADO pipeline run state for the jupiter prefix (L11 Step 6/7). This hypothesis predicts
**no 401 at the data plane at all** — the "401" would be a frontend/SDK artifact of missing config.
The RCA cannot rule it out and does not rank it.

**Mechanism of the ranking error.** The ranking is ordered "by fit to the literal evidence ('401', 'on
AVD', 'can see FFs in portal')" (diagnosis-synthesis.md:128-129). By anchoring on the literal "401," it
*assumes its own conclusion* (that the 401 is real and data-plane) to do the ranking — circular. Strip
the literal-401 anchor (Finding 2) and the base-rate-strongest hypothesis (pipeline not applied/approved)
should lead, with H1 (interactive token) DEMOTED because its precondition (Duncan ran an interactive
data-plane write) is unevidenced.

**If accepted → which section changes:** L8 fix table (rca.md:390-397) and diagnosis-synthesis.md:131-146
ranking table must (a) promote "un-applied/un-approved pipeline" from L11-Step-7 exclusion to a **ranked
peer hypothesis (H0)** with explicit base-rate justification (same filer, same symptom, Sep-2025), and
(b) demote H1 from "leading" to "conditional on evidence that Duncan ran an interactive set," noting
that precondition is currently unevidenced.

**Classification: REBUT** (file:line evidence): pipeline-is-the-set-path at fbe-ff-mechanism.md:34-41
and rca.md:62-69; Sep-2025 same-filer precedent at slack-harvest.md:195 and rca.md:354-357; ranking
omission at diagnosis-synthesis.md:131-139.

---

## FINDING 4 — FACT-laundering: at least two A1-labeled claims rest on sidecar A2 INFER, not on a witnessed source

**Claim attacked (rca.md Evidence Ledger):**

- **C9 (rca.md:587):** *"Disabling local auth deletes all keys; connection-string callers then 401
  ('Invalid Credential'); rotation also yields 401"* — labeled **A1**.
- **C14 (rca.md:592):** *"The 22 Jun symptom is most consistent with a data-plane auth gap for the AVD
  identity, not the network cause"* — labeled **A2** (this one is honestly labeled; included as the
  contrast case).

**Why C9 is FACT-laundered.** The librarian sidecar is explicit that the "then 401" status for the
disabled-key + connection-string case is **A2 INFER**, not quoted fact: msdocs-appconfig-auth.md:74
verbatim — *"A connection-string (HMAC) request after disableLocalAuth=true returns HTTP 401 ... so the
specific number is INFER, not FACT."* The RCA collapses the librarian's A1-fact ("deletes all keys")
and A2-inference ("then 401") into a single **A1** ledger row. That is precisely the
`Source-Verified ≠ Claim-Safe` violation: the source proves the *deletion*, not the *status code*. The
inference may well be correct (it is well-reasoned), but **mislabeling an inference as a witnessed fact
is the exact failure the evidence-ledger discipline exists to prevent.**

**Second instance — softer.** C8 (rca.md:586) bundles *"401 = authentication ... 403 = RBAC or network"*
as A1. The 401/403 *category* split is genuinely A1 (multiple Learn quotes, msdocs §Q2/Q3). But the
specific clause *"deleted/stale/mis-signed key"* → 401 inherits the same INFER hole as C9 for the
disabled-key sub-case. C8 is *mostly* A1; flagging the overlap so the coordinator checks the seam.

**Mechanism / impact.** A reader auditing the ledger sees C9 as A1 and treats "disabled keys → literal
401" as a witnessed fact when ranking H2. If the true post-disable status were ever a 403 or a
different 401 sub-shape, H2's "uniquely explains a literal 401" selling point (rca.md:84-85,
diagnosis-synthesis.md:142-146) would weaken. The label inflates H2's apparent discriminating power.

**If accepted → which section changes:** C9 (rca.md:587) relabel to **A1 (keys deleted) + A2 (→ 401,
per msdocs §Q1 reasoning)**; C8 (rca.md:586) annotate the disabled-key 401 sub-clause as A2. The
§Confidence claim that "the system model (C3-C11) is well evidenced (A1)" (rca.md:600-601) must carve
out C9's inferential half.

**Classification: REBUT** (doc quote): msdocs-appconfig-auth.md:74 ("INFER, not FACT") vs rca.md:587 (A1).

---

## FINDING 5 — "I can see the flags in the portal = control-plane only" is over-claimed; a vault note says portal access to private-endpoint App Config ALSO 401s (Edge), and "see the flags" could be a cached/stale render

**Claim attacked (rca.md:67-69, 286-288, 436-438; L10 lesson 2):**
> "*seeing the flags in the portal* uses a **third, separate permission** (the Azure Resource Manager
> control plane) — so 'I can see the flags' proves nothing about whether the data-plane call ... was
> allowed to authenticate." (rca.md:67-69)
> L10.2: "Control-plane visibility is not data-plane authority ... This single confusion explains the
> whole ticket." (rca.md:436-438)

**Why it is over-claimed.** Three cracks:

1. **The portal feature-flag blade reads the DATA plane, not pure control plane.** The Azure Portal's
   App Configuration "Feature manager" / key-value explorer fetches key-values over the **data plane**
   (the same `azconfig.io` surface), not ARM. The RCA asserts the portal view is "ARM, not the data
   plane" (rca.md:251, 260-261) as a clean fact, but provides **no source** for the portal's read path
   being control-plane. msdocs-appconfig-auth.md does NOT establish that the portal flag view is ARM;
   it establishes only that *control-plane roles ≠ data-plane roles* (msdocs §Q4). The RCA conflates
   "control and data planes have different roles" (true, sourced) with "the portal flag view uses the
   control plane" (asserted, unsourced). If the portal blade actually uses the data plane, then
   "I can see the flags" would *partially evidence* working data-plane read auth — directly undercutting
   L10.2's claim that this confusion "explains the whole ticket."

2. **The vault directly contradicts the clean control-plane story.** vault-appconfig-knowledge.md:100-103
   records a real incident: *"Azure Portal 401 on App Configuration resources. Root cause: browser-specific
   issue. Edge has known problems with private endpoint resources."* So the portal **does 401 against
   private-endpoint App Config** — meaning the portal path is NOT a frictionless control-plane window
   immune to the private-endpoint/auth problems. The RCA captures this only as H4 ("medium") in
   diagnosis-synthesis.md:136 but then in the prose asserts the portal view "proves nothing" and is a
   clean separate plane (rca.md:436-438) — the two are in tension.

3. **"Can see the flags" may be a stale/cached render, not a live successful read.** Even if the portal
   read succeeded, it may have succeeded *earlier* / be cached. "I can see the FFs set properly" is a UI
   observation at an unknown time, not a timestamped live 200. The RCA treats it as a current positive
   signal (the basis for C15, rca.md:593).

**Mechanism.** L10.2 elevates "portal = control plane, proves nothing about data plane" to "the single
confusion that explains the whole ticket" (rca.md:438). If the portal flag blade is actually data-plane,
the inference inverts: "I can see the flags" would be *weak positive evidence that data-plane READ auth
works*, pushing the cause toward the **write/set path or pipeline** (Finding 3's H0), not the read
credential. The over-claim does not just overstate confidence — it may point the next on-call at the
wrong plane.

**If accepted → which section changes:** rca.md:67-69, 251, 260-261, 286-288 must add a source for "portal
flag view = control plane" OR downgrade to "the portal view's plane is not established here; if it is
data-plane, 'I can see the flags' weakly evidences working read auth and shifts suspicion to the set/write
path." L10.2 (rca.md:436-438) must drop "explains the whole ticket" to "is *a* confusion to rule out."
C15 (rca.md:593) must note the staleness/cached-render caveat.

**Classification: REBUT** for crack 2 (vault quote at vault-appconfig-knowledge.md:100-103 contradicts the
clean separation). **DEFER** for crack 1 (the portal-blade-plane claim is unsourced in the sidecars;
resolving probe: Microsoft Learn on which plane the portal Feature manager reads, OR observe the portal's
network calls). Revisit condition: confirm the portal flag-blade read path.

---

## FINDING 6 — H2's "the only literal-401 path" claim is internally contradicted: H1 ALSO predicts a literal 401

**Claim attacked (rca.md:24, 84-85, summary + Exec):**
> "(H2, the only literal-401 path)" (rca.md:24)
> "the connection-string secret in Key Vault is stale ... (the only path that produces a *literal* 401
> on a service fetch)" (rca.md:84-85)

**Why it is wrong (internal contradiction).** The RCA's own H1 is defined as a **literal 401** (rca.md:80-83,
*"interactive identity whose token is stale or points at the wrong tenant (a literal 401)"*; L8 table
rca.md:392, *"401 invalid_token / wrong issuer → H1"*; decision tree rca.md:298, *"401 invalid_token →
H1"*). The diagnosis-synthesis ranking table marks **both H1 and H2 as "Predicts 401? Yes"**
(diagnosis-synthesis.md:133-134). So "H2 = the only literal-401 path" is **false within the document** —
H1 is also a literal-401 path. The two qualifiers the RCA uses ("the only literal-401 path" rca.md:24 vs
"the only path that produces a literal 401 *on a service fetch*" rca.md:84-85) are trying to rescue this
with the "service fetch" scope, but the summary line (rca.md:24) drops that scope and states it flatly.

**Impact.** Minor in isolation, but it props up H2's apparent uniqueness/discriminating power. Combined
with Finding 4 (H2's "then 401" status is itself INFER), H2 is being sold as the clean literal-401
explanation when (a) H1 also predicts 401 and (b) H2's prediction is inferential.

**If accepted → which section changes:** rca.md:24 summary — change "(H2, the only literal-401 path)" to
"(H2, the literal-401 path *on the connection-string read*)"; reconcile with H1 also being a literal-401
path. Ensure the decision tree (rca.md:292-300) makes clear BOTH 401 branches are literal-401, split by
`WWW-Authenticate` shape (Bearer vs HMAC), not by "literal vs non-literal."

**Classification: REBUT** (internal file:line): rca.md:24 vs rca.md:80-83, rca.md:298, diagnosis-synthesis.md:133-134.

---

## FINDING 7 — Unexamined store-identity assumption: the RCA reasons about `vpp-applicationconfig-d` while two sidecars flag the FBE may use a DIFFERENT store, which would invalidate the IaC-grounded RBAC reasoning

**Claim attacked (the whole L5/L6 RBAC/network reasoning, e.g. rca.md:316-339):** all of it is grounded
in the Terraform for `vpp-applicationconfig-d` (the shared store).

**Why it is a load-bearing unverified assumption.** Three sidecars independently warn the FBE may not
read the shared store:

- fbe-ff-mechanism.md:100-107 (Q1 A3): *"the legacy FBE IaC `app-config.tf` provisions its OWN store ...
  so FBE historically had a SEPARATE App Config instance, distinct from the shared `vpp-applicationconfig-d`."*
- vault-appconfig-knowledge.md:27-35 (naming caveat): *"the vault has no note literally containing
  `vpp-applicationconfig-d` ... Do not assume the vault's `vpp-appconfig-d` is the same store ... this is
  a load-bearing discriminator."*
- diagnosis-synthesis.md:82-88 (A3 discrepancy): read-path access-key (repo) vs managed-identity (vault)
  contradiction, AND shared-vs-FBE-specific store unresolved.

The RCA carries this honestly as an "Open structural question" (rca.md:219-223) and as C17 (A3-blocked,
rca.md:595). **But the prose then reasons confidently about the shared store's RBAC group
(`sg-vpp-core-release-masters`, rca.md:326-328) and network posture as if it is THE store in play.** If
Jupiter uses an FBE-specific store, then: the Data Owner group is different, the connection-string secret
is different, the `disableLocalAuth` state is a different resource, and H2/H3's specific mechanisms point
at the wrong object. The "no IaC change in 2 months" reassurance (rca.md:212-214, C7) is also about the
*shared* store's IaC, not the FBE store's.

**Mechanism.** This is a Boundary-Failure (SW2): the RCA assumes producer (FBE service) and the object
it reasons about (shared store) are the same, when the contract between them is explicitly unverified.
Every store-specific A1 (C5 Data Owner group, C6 network/local-auth, C7 no-change) is only load-bearing
*if* Jupiter uses that store.

**If accepted → which section changes:** L5/L6 and the L8 fix table must be prefixed with an explicit
conditional: "all store-specific facts below assume Jupiter reads/writes `vpp-applicationconfig-d`; if
L11 Step 6 shows an FBE-specific store, re-run L5/L6 against THAT store's IaC." C5/C6/C7 ledger rows
should be tagged "scope: shared store — unconfirmed as Jupiter's store (see C17)."

**Classification: DEFER** — the RCA already flags C17 as A3; the gap is that the *prose confidence* does
not propagate the C17 caveat into L5/L6/L8. Revisit condition: L11 Step 6 resolves which store Jupiter uses.

---

## FINDING 8 — The "returning/rusty engineer raises the prior on human-side cause" reasoning cuts AGAINST the leading hypotheses, not for them

**Claim attacked (rca.md:192-193, L1):**
> "That 'returning, rusty' detail is itself load-bearing: it raises the prior on a **human-side
> identity/permission/tooling** cause over a platform regression."

**Why it is half-applied (Socratic consistency probe).** The RCA invokes "rusty engineer" to raise the
prior on identity/permission/tooling causes (H1/H3/H5). But the *same* "rusty engineer" prior cuts
HARDER toward the causes the RCA *under-ranks*:

- A rusty frontend dev is **more likely to mis-report a status code** ("401's") — strengthening Finding
  2 (paraphrase risk), which the RCA does not let weaken its spine.
- A rusty dev is **more likely to forget the approval-gate step** — which is *exactly* what happened to
  this same Duncan in Sep-2025 (slack-harvest.md:195). So "rusty" raises the prior on H0 (unapplied/
  unapproved pipeline, Finding 3) at least as much as on "stale token."
- A rusty dev is **less likely to be running interactive `az appconfig` data-plane writes at all**
  (H1's precondition), since that is a platform-team-shaped action, not a frontend workflow.

The RCA uses the "rusty" prior selectively — to boost the auth-identity hypotheses it already favors —
while ignoring that the same prior boosts the misreport and pipeline-approval hypotheses it demotes.
That is motivated reasoning (confirmation bias, Rule 6).

**If accepted → which section changes:** L1 (rca.md:192-193) must apply the "rusty" prior even-handedly:
it raises the prior on (a) status-code misreport, (b) forgotten approval gate, AND (c) identity/tooling —
which on net *flattens* the ranking toward H0/misreport rather than sharpening it toward H1.

**Classification: DEFER** — reasoning-consistency issue, not a factual error. Revisit condition: re-rank
after Findings 2 and 3 are adjudicated.

---

## DOT-CONNECTION (Rule 15) — the findings share two root generators

- **Generator A — over-literal anchoring on "401":** Findings 1, 2, 3, 6, 8 all trace to the RCA
  treating a rusty frontend dev's paraphrased "401's" as a captured HTTP status line, then ranking
  hypotheses *by fit to that literal anchor*. Strip the anchor and the ranking reorders (H0 pipeline /
  misreport rise; H1 interactive-token falls). This is one architectural flaw, not five isolated issues.
- **Generator B — confidence not propagating from ledger to prose:** Findings 4, 5, 7 all trace to A3/A2
  caveats that exist correctly in the Evidence Ledger (C9 seam, C15 portal, C17 store) but are NOT carried
  into the confident prose of L4/L5/L6/L10. The ledger is honest; the narrative over-commits beyond it.

**Emergent risk:** the next on-call reads the *prose* (Exec summary + L10 lessons), not the ledger. The
prose's overcommitment ("they ARE two different layers," "the credential itself," "portal proves nothing,"
"explains the whole ticket") could steer them away from the cheapest, highest-base-rate checks (is the
pipeline approved? did Duncan capture a real status?) toward token/key/RBAC rabbit holes — the exact
"per-incident toil" the RCA's own L10.5 warns about.

---

## SUPERWEAPON DEPLOYMENT (Rule 14)

- **SW1 Temporal Decay:** N/A — this is a point-in-time diagnosis, not a stateful system aging over time.
  (One sub-note: the "can see flags in portal" observation has no timestamp — staleness covered in F5.)
- **SW2 Boundary Failure:** Applied → **Finding 7** (producer FBE ↔ assumed store `vpp-applicationconfig-d`
  boundary unverified; all store-specific RBAC/network facts hang on it).
- **SW3 Compound Fragility:** Applied → the framing rests on a CHAIN (401-is-literal ∧ call-is-data-plane ∧
  store-is-shared ∧ portal-is-control-plane). Each link is individually plausible; the RCA treats their
  conjunction as solid. If any one fails (F1, F5, F7), the leading hypotheses shift. Correlated trigger:
  a single AVD-DNS/partial-link misconfiguration could produce a network-class error mis-reported as 401,
  breaking links 1 and 2 simultaneously.
- **SW4 Silence Audit:** Applied → **Finding 3** (the un-applied/un-approved-pipeline hypothesis H0 is
  MISSING from the ranked set despite being the same-filer base-rate-strongest prior). Also silent: no
  hypothesis covers "the FF SDK/frontend surfaced a generic auth banner that isn't a real App-Config 401."
- **SW5 Uncomfortable Truth:** Applied → the RCA is rhetorically excellent and its *confidence* is its
  weakness. The uncomfortable truth: a beautifully-structured "hypothesis set" can still smuggle in a
  premature convergence by *ranking* — H1/H3 are asserted "High" on an anchor (literal 401) the document
  itself cannot yet verify. Polish is not evidence.

---

## META-FALSIFIER (Rule 11) — how THIS review could be wrong

- **What would prove this review wrong:** L11 Step 2 returns a *captured* `HTTP/1.1 401` with a
  `WWW-Authenticate: Bearer error="invalid_token"` body from an interactive AVD call Duncan confirms he
  ran. That would (a) confirm the 401 is literal (dissolves F1/F2), (b) confirm an interactive data-plane
  call happened (dissolves F3's H1-precondition attack), and (c) confirm the data plane was reached
  (weakens F5). My central thrust — "the literal-401 anchor is unearned" — collapses if the anchor is
  witnessed.
- **What I am assuming that might be wrong:** I assume the Azure Portal feature-flag blade reads the data
  plane (F5 crack 1). I did not source this — it is my training-derived belief about the portal's
  architecture and is SPECULATIVE until the coordinator checks Microsoft Learn. If the portal blade is
  genuinely ARM/control-plane, F5 crack 1 falls (cracks 2 and 3 still stand).
- **Domain gap:** I have not verified whether `az appconfig kv list --auth-mode login` vs the FF SDK
  surface "401" identically; the exact tooling Duncan used is A3 (the RCA admits this, rca.md:486). My
  H0/misreport argument is stronger if his "tool" was the frontend app, weaker if it was a raw `az` call.
- **Where I pattern-matched vs reasoned:** my "rusty dev forgets approval gate" prior (F8) is a base-rate
  argument from one prior incident (Sep-2025); it is suggestive, not deductive. One instance + a named
  mechanism (approval gate exists, rca.md:348) clears the hot-stove bar, but the coordinator should treat
  F8 as the softest finding.

---

## VERDICT (INFER — coordinator must source-verify)

**Grade: PROBLEMATIC (framing survives; ranking and confidence-labels do not).**

The two-ticket separation is *directionally* defensible and the document is unusually disciplined about
its gaps in the *ledger*. But the **prose over-commits beyond the ledger** (Generator B) and the
**hypothesis ranking is anchored on an unverified literal "401"** (Generator A), which (1) inflates
H1/H3, (2) omits the best base-rate hypothesis H0 (unapplied/unapproved pipeline — same filer, same
symptom, Sep-2025), and (3) contains a FACT-laundered ledger row (C9) and an internal contradiction
(H2 "the only literal-401 path" while H1 also predicts 401).

**Highest-priority changes (if findings accepted):**
1. Add **H0 (unapplied/unapproved pipeline)** as a ranked peer hypothesis; demote H1 to conditional on
   evidence Duncan ran an interactive set (Finding 3). — REBUT-backed.
2. Relabel **C9** A1→A1+A2 to match msdocs-appconfig-auth.md:74 (Finding 4). — REBUT-backed.
3. Soften the spine and framing-confidence from "decisive/unambiguous/high" to "best-supported,
   conditional on the literal-401 probe" (Findings 1, 2). — DEFER/REBUT.
4. Source or soften "portal = control-plane, proves nothing" (Finding 5). — REBUT (vault) + DEFER (blade plane).
5. Fix the H2 "only literal-401 path" contradiction (Finding 6). — REBUT.
6. Propagate the C17 store-identity caveat into L5/L6/L8 prose (Finding 7). — DEFER.
7. Apply the "rusty dev" prior even-handedly (Finding 8). — DEFER.

**Findings by classification:** REBUT ×4 (F2, F3, F4, F6) + REBUT-portion of F5 — these carry file:line
or doc quotes and need a real Rebut (file:line/doc) or a fix. DEFER ×4 (F1, F7, F8, + F5-blade-plane) —
risk statements with named revisit conditions (the L11 probes). None are SPECULATIVE-only; all trace to
a cited line or quote.
