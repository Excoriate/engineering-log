---
title: "Goal-fidelity adversarial — BTM RCA/fix deliverables vs user's verbatim ask"
status: complete
timestamp: 2026-06-22T00:00:00Z
task_id: 2026-06-22-010
agent: socrates-contrarian
attack_lane: "goal fidelity only — ask↔deliverable divergence, scope/omission. NOT technical mechanism."
summary: |
  Attacked the team-lead's planned deliverables against the user's EXACT words. The
  plan's diagnosis and reframing are strong, but I found 9 goal-fidelity gaps where the
  PLAN-AS-STATED would diverge from the literal ask. Two are GATE-class: (G1) the user
  said "verify 100% everything, NO space for unverified claims" yet V14 — the single
  load-bearing claim that the fix works — is A2/A3, and the plan's own closing probe is
  POST-FIX (you cannot verify-100%-then-deliver; you deliver, THEN it self-proves). (G2)
  the prior feynman/RCA TAUGHT a now-overturned mental model ("runner switch is a mask",
  "fix = one line --detect false"); if the new feynman reuses that spine the user
  "replicates by myself" a WRONG model — the exact "if not, it's a failure" condition.
  Also: Q1 (why was dta-sp created / configure-or-delete) is reframed but the explicit
  configure-OR-delete decision the user asked for is at risk of being answered only as
  "recommendation", and the "tested locally" requirement collides with Thread B (the real
  blocker is NOT locally reproducible as the user runs it).
---

# Goal-fidelity adversarial review

## Key Findings

- **G1** — "verify 100%" vs V14 (fix-works) claim is A2/A3, closed only POST-delivery [GATE]
- **G2** — prior feynman taught an overturned model; reuse = user replicates a wrong mental model [GATE]
- **G3** — Q1 configure-OR-delete decision must be answered, not deferred to a vague recommendation
- **G4** — "tested locally" — Thread B is NOT locally reproducible under the user's own identity
- **G5** — HTML is a user requirement with NO skill-native contract — needs explicit producer + render proof
- **G6** — "actually work" must close on the EFFECT and name target repo(s); B2B already on Niels' fix
- **G7** — prior fix.md headline answer to Anton's cost question is now WRONG — must be retracted, not silently superseded
- **G8** — feynman "replicate by myself" requires the SP-precedence fact (V2) be reproducible, not asserted
- **G9** — destructive-delete gate on dta-sp must live IN the .md (user reads the .md, not chat)

## Steelman (Rule 9 — I can advocate for the plan)

The plan's central move is correct and is the thing the prior attempt missed: it separates
**Thread A** (TF401019, the loud symptom — prior fix is correct for it) from **Thread B**
(empty `workItems` — the actual blocker, in `requirements.md`), proves the live identity is
the **SP not the Build Service** (overturning the inherited "PAT ⇒ Build Service" assumption
that poisoned both the prior RCA and the sherlock sidecar), and closes the fix on the realized
tag (H-EFFECT-1) rather than the exit code. The verbatim corpus is captured accurately in
`01-task-requirements-initial.md`. If the deliverables faithfully render the synthesis, this
is a materially better package than the prior one. My job is only to find where the PLANNED
deliverables, as described, would still MISS the user's literal words.

---

## GAPS (user's exact phrase → how the plan misses it → minimal correction)

### G1 — GATE — "verify 100% everything, no space for unverified claims"

**User's exact words:** "verify 100% everything, no space for unverified claims."

**How the plan misses it:** The single most load-bearing claim in the entire package —
**"the fix actually works"** — rests on **V14**, which the synthesis itself labels
**"A2 (strong) / A3 to fully close"** and whose closing probe is the **post-fix realized-tag
check (H-EFFECT-1)**. Read literally, the user wants verification BEFORE acting on the
deliverable; but the plan can only verify the fix AFTER the PR is merged and the pipeline
re-runs. The deliverable, at delivery time, contains an A2/A3 at exactly the load-bearing
joint. There are also three other open A3 items (A3-a Build Service effective ACL, A3-b Apr-22
audit log, A3-c purged 04-15 build). Leaving A3s is acceptable under the harness ONLY IF each
names its exact closing probe — but the USER did not say "name the probe", the user said
"no space for unverified claims". This is an ask↔deliverable divergence even if the harness is
satisfied.

**Minimal correction:** Do not let "verify 100%" silently degrade to "every claim is labelled".
The deliverable MUST contain an explicit, top-of-document **"What is proven vs what is not yet
proven"** honesty box that states, in the user's own framing: the *diagnosis* (Thread B = SP
cannot see the board) is **100% verified live** (V1–V13, A1), but the *fix efficacy* (V14) is
**A2 until the post-fix tag check runs**, and that this is structurally unavoidable because
proving it requires an ADO pipeline run the agent has not performed. Each A3 must carry its
one exact closing command/owner. If this box is not present, the deliverable claims more
certainty than it has = the precise thing the user forbade. **If TRUE → the RCA/feynman get a
mandatory proven-vs-unproven section; if FALSE → no change.**

---

### G2 — GATE — "/how-to-feynman that will ACTUALLY work … so I can replicate it by myself. If not, it's a failure."

**User's exact words (this command):** "a /how-to-feynman that will actually work."
**User's exact words (original UAC):** "I must be able to understand deeply your rationale,
and **replicate it by myself**. If not, it's a failure."

**How the plan misses it:** The prior `feynman-explanation.md` teaches a mental model the
synthesis now **OVERTURNS**:
- It teaches the reader to **"Reject the false fix ('move it to the Core Platform runner')
  with a mechanism"** (Knowledge Contract item 5) and frames the sibling runner switch as a
  **mask**. The synthesis (V12) proves the sibling fix works **because it drops
  `azure-login.yml` → no SP session → the PAT/Build-Service identity is actually used** — the
  runner switch was incidental but the **identity change was the real fix**. So the old doc
  trained the reader to reject the *correct* mechanism.
- It teaches **"the one-line root-cause fix" (`--detect false`)** as sufficient. The synthesis
  proves `--detect false` is **necessary but INSUFFICIENT** (Thread B remains).

If the new feynman reuses that spine, the user will "replicate by myself" a **wrong model** —
which is, by the user's own definition, **a failure**. The plan says "honor /how-to-feynman"
but does not explicitly state the new doc must **retract and replace** the old teaching.

**Minimal correction:** The new feynman doc MUST (a) explicitly correct the two now-false
lessons (sibling fix is an identity change, not a mask; `--detect false` alone is
insufficient), and (b) make the **az-login precedence** step (V2: SP session beats
`AZURE_DEVOPS_EXT_PAT`) reproducible by the reader, because that single counter-intuitive fact
is the whole new diagnosis. Replicability of THAT step is the pass/fail line (see G8).
**If TRUE → feynman gets an explicit "what I told you before was incomplete — here is the
corrected model" section + a reproducible precedence demo; if FALSE → no change.**

---

### G3 — GATE — Q1: "Do you know why mcc-btm-deployment-dta-sp was created in ADO? If needed configure it; if not, could you try deleting it?"

**User's exact words:** three sub-asks — (1) **why** was it created, (2) **configure** it if
needed, (3) **delete** it if not.

**How the plan misses it:** The synthesis answers *what* dta-sp is (V7: ADO user created
2026-04-22, Basic, AAD, principalName 7edd1af1…) and *that* it lacks board read (V6). But it
does **not** answer the user's actual decision question: **why was it created** (A3-b: audit
log, PCA-only — currently unknown), and therefore cannot cleanly resolve **configure-vs-delete**.
The plan risks delivering "here is what it is" while the user asked "**decide** for me:
configure or delete". An RCA that describes the SP but does not give a configure-or-delete
recommendation **with the gate** leaves Q1 functionally unanswered.

**Minimal correction:** The deliverable MUST contain an explicit **Q1 decision block**:
- *Why created:* state plainly it is **A3[blocked: ADO audit log is PCA-only]**, name the
  exact closing step (Org Settings → Auditing, filter 2026-04-22, actor of the user-add), and
  give the strong INFER (it was auto-created as a byproduct of the `dta-sp` `az login` against
  ADO, same as any AAD SP first touching the org — corroborated by V7 timestamp matching the
  onset window).
- *Configure or delete:* recommend **configure** (grant the *tagging* identity board read) and
  **do NOT delete**, because (i) `dta-sp` is the dev/acc **deployment** SP and is used by the
  terraform steps, deletion would break deploys, and (ii) deletion is destructive +
  authorization-gated. This must be a stated recommendation **with a NN-4 destructive-action
  authorization gate**, never an auto-action. **If TRUE → Q1 block added; if FALSE → no change.**

---

### G4 — "Ensure the script can be tested locally, so I can inspect it."

**User's exact words:** "tested locally, so I can inspect it."

**How the plan misses it:** This is a real collision the plan does not flag. For **Thread A**,
the prior package's local repro works (read-only `az boards query --debug | grep vsts/info`).
But the plan's NEW root cause is **Thread B: the deployment SP cannot see the board**. The user
running locally authenticates as **Alex (913 work items, V5)**, NOT as `dta-sp`. So the user
**cannot locally reproduce the empty-result symptom** the way it happens in the pipeline —
local repro of Thread B requires the SP credential, which the user should not hold/run. The
"tested locally so I can inspect it" UAC is **partially unsatisfiable for the actual blocker**,
and the plan does not say so.

**Minimal correction:** The .md must separate two things the user will otherwise conflate:
(a) **what IS locally inspectable** — the script logic, the az-login-precedence demo (G8), the
Thread-A `/vsts/info` repro; and (b) **what is NOT locally reproducible by the user** — the
SP's empty-board result, because it requires the SP identity. For (b), provide the **next-best
local inspection**: the recorded pipeline `--debug` evidence (build 1668639 log#19 showing
`ServicePrincipalCredential` + `workItems:[]`) as the inspectable artifact, and the read-only
ACL probe the user CAN run as Alex to see the contrast (913 vs []). State explicitly: "the
full bug cannot be reproduced on your laptop because it is identity-specific; here is the
closest inspectable proof." Silence here = the user runs the local test, sees 913 items, and
concludes the bug doesn't exist. **If TRUE → .md adds an explicit local-vs-ADO-only inspection
split for Thread B; if FALSE → no change.**

---

### G5 — "use /rca-holistic (both .md and HTML)"

**User's exact words:** "both .md and HTML."

**How the plan misses it:** I verified the `rca-holistic` SKILL.md has **NO native HTML
emission contract** — it specifies Mermaid parser/render checks for the .md, but never an
`.html` output file (grep for `\.html|emit html|single-file html` returns empty). So "HTML" is
a **user requirement that the skill does not produce by default**. The plan lists ".html" as a
deliverable but inherits no skill machinery to generate or verify it. Risk: an .html is
produced that (a) does not render the Mermaid diagrams (markdown→HTML without a Mermaid runtime
leaves raw fenced code), or (b) is a trivial `pandoc` dump that loses the evidence-label
formatting — either way "HTML" is technically present but not honoring the intent (a readable,
rendered companion).

**Minimal correction:** Treat HTML as an **explicit, separately-verified deliverable**: name
the exact producer (e.g. `pandoc rca.md -s --embed-resources -o rca.html` with a Mermaid
filter, OR a Mermaid-rendering converter), and add a **render-proof step** to P8 (open/parse
the HTML, assert the diagrams are rendered images/SVG not raw fences, assert evidence tables
survive). The GENERATED-ARTIFACT LOCK applies: an HTML claimed as delivered without a
renderer/parser check is `[UNVERIFIED[blocked]]`. **If TRUE → HTML gets a named producer + P8
render proof; if FALSE → no change.**

---

### G6 — "actionable fix … that will actually work" — for WHICH pipeline(s)?

**User's exact words (command):** "an actionable fix … a how to fix it. So I can implement
it, or an agent." **User's exact words (requirements.md):** the blocking ticket is **BtM B2C**
(buildId 1676583), and the original is **Eneco.Vpp.BehindTheMeter** (B2C). The sibling
**B2B** was already fixed by Niels (PR 178802).

**How the plan misses it:** "Actually work" has a scope ambiguity the plan does not pin down.
The synthesis fix targets `Eneco.Vpp.BehindTheMeter` (B2C). But the user's corpus references
**three** surfaces: B2C (broken, the target), B2B (already on Niels' fix — V12), and the
general "Agg team uses the same pipeline." If the fix .md does not state **which repos it
applies to and which are already fixed**, the user/agent may apply it to the wrong repo or
re-fix B2B. Also: the synthesis offers **three** fix variants (own-job no-azure-login;
`az logout`; permission grant). "So I can implement it, or an agent" demands ONE default with
exact steps — not a menu the implementer must adjudicate.

**Minimal correction:** The fix .md must (a) name the **exact target repo(s)** and explicitly
say B2B is already fixed (do not touch), and (b) designate **ONE primary fix** with
copy-paste steps for a human or agent, with the alternatives clearly demoted to "only if the
realized-tag check still fails." An agent executing a 3-option menu without a default is not
"actionable." **If TRUE → fix gets a single default + explicit repo scope; if FALSE → no
change.**

---

### G7 — "verify 100% / no unverified claims" applied to the PRIOR answer to Anton's question

**User's exact words:** the original Slack thread the user is continuing — Anton's cost
concern: "I'd like to avoid splitting our deployment job between two different runners because
my intuition says it would increase the overall cost." The prior `fix.md` answered:
**"No, the runner switch is not … the correct fix … the pool swap does not change what is
denied"** and explained the sibling's success as **"[A2 INFER — not probed] a pool-correlated
… az/extension version difference, or a broad cached credential."**

**How the plan misses it:** The synthesis (V12) **overturns** that headline answer. The sibling
fix works specifically because the separate job **omits `azure-login.yml`** → identity change.
The plan supersedes the old package but I see no requirement to **explicitly retract** the old
answer Anton was given. Under "no unverified claims / verify 100%", a previously-delivered
WRONG answer that the user may have relayed to Anton cannot just be quietly replaced — it must
be **named and corrected**, or the user repeats a wrong statement to the requester.

**Minimal correction:** The RCA must contain an explicit **"correction to the prior answer"**
note: the earlier "pool swap is incidental / it's a version-or-credential difference (INFER)"
was **wrong**; the real reason the sibling works is the **dropped `azure-login.yml` (identity)**,
now A1 (V12). This also REFINES the answer to Anton's cost question: the sibling did NOT need a
second paid runner for the *mechanism* — a separate job WITHOUT azure-login on the **same**
MS-hosted pool achieves it (the synthesis primary fix), directly serving Anton's cost concern.
**If TRUE → RCA adds a prior-answer-correction block; if FALSE → no change.**

---

### G8 — "replicate it by myself" — the NEW load-bearing fact must be reproducible, not asserted

**User's exact words:** "replicate it by myself. If not, it's a failure."

**How the plan misses it:** The entire new diagnosis pivots on **V2: `az login` SP session
takes precedence over `AZURE_DEVOPS_EXT_PAT`.** This is counter-intuitive (the script author
clearly believed setting the PAT env var would control auth). If the feynman/RCA merely
**asserts** V2 with a citation to PROBE 6/7, the user cannot "replicate it by myself" — they
have to take it on faith. The plan references the probes but does not commit to giving the user
a **runnable** precedence demonstration.

**Minimal correction:** The feynman doc MUST include the **exact local commands** that let the
user reproduce precedence on their own machine: `az login` (as themselves), set a deliberately
invalid `AZURE_DEVOPS_EXT_PAT`, run `az boards query`, observe it STILL succeeds (PAT ignored,
login session used) — i.e., PROBE 6 rewritten as a user-runnable recipe. This is read-only and
fully local, so it satisfies BOTH "replicate by myself" AND "tested locally." Without it, the
single most surprising claim is unverifiable by the user = failure-by-the-user's-definition.
**If TRUE → feynman gets a runnable precedence demo; if FALSE → no change.**

---

### G9 — "If the solution requires ADO, it must be specified in the .md document"

**User's exact words:** "If the solution requires ADO, it must be specified in the .md
document." Plus the destructive sub-ask: "could you try deleting it?"

**How the plan misses it:** The plan correctly intends to gate the destructive delete — but the
gate must live **in the .md the user reads**, not only in agent reasoning or a chat message.
The user explicitly said ADO-requiring steps must be IN the document. The fix involves at least
two ADO-only, non-local actions: **(1) a PR** to `Eneco.Vpp.BehindTheMeter`, and **(2) possibly
a permission grant** on Team BtM, and **(3) the dta-sp delete the user asked about**. All three
are ADO mutations the agent has not and (for delete) must not auto-perform.

**Minimal correction:** The .md must have a clearly-labelled **"ADO-only actions (cannot be
done locally)"** section listing: the PR (write on the repo), the optional permission grant
(PCA/Project Admin on Team BtM), and the dta-sp delete — the latter marked **DESTRUCTIVE,
requires explicit authorization, recommended AGAINST (it is the dev/acc deployment SP, deleting
it breaks deploys)**, per NN-4. "Tested locally" applies to inspection; these are explicitly
flagged as the ADO boundary. **If TRUE → .md gets an explicit ADO-only-actions section with the
destructive gate in-document; if FALSE → no change.**

---

## Dot-connection (Rule 15)

G1, G7, G8 share one root: **the user's "verify 100% / replicate by myself" is an
EPISTEMIC-HONESTY demand, and the deliverable's weakest joints are the new/overturned claims**
(fix efficacy V14, the retracted sibling-mask answer, the counter-intuitive precedence V2). The
unified correction is a single discipline applied across all three deliverables: **every
load-bearing claim that is new or overturns the prior package must be either (a) reproducible by
the user locally, or (b) explicitly marked unproven with its exact closing probe — and the
overturned prior claims must be named as corrections, not silently replaced.** A package that
quietly supersedes the old one fails "verify 100%" even if every NEW claim is labelled, because
the user was previously handed WRONG claims under the same trust.

G3, G4, G9 share a second root: **the user reads the .md, not the chat or the agent's head.**
Q1's decision, Thread B's local-irreproducibility, and the destructive-delete gate must all be
IN-DOCUMENT, because the user explicitly said so ("specified in the .md document").

## Meta-falsifier (Rule 11)

- What would prove THIS review wrong: if the team-lead's actual rendered deliverables already
  contain (i) a proven-vs-unproven honesty box, (ii) an explicit retraction of the old
  "sibling=mask / one-line fix" teaching, (iii) a user-runnable precedence demo, (iv) a Q1
  configure-or-delete decision with gate, (v) a single default fix with repo scope, and
  (vi) named HTML producer + render proof — then G1–G9 are already satisfied and this review is
  redundant. I reviewed the PLAN description + the synthesis + the PRIOR deliverables, NOT the
  not-yet-written new deliverables, so every gap is "the plan as described does not commit to
  X"; if the rendered output commits to X, the gap closes.
- Assumption I am making: that the new feynman/RCA will draw on the synthesis AND the prior
  package (the plan says "honor the skills" but does not enumerate the corrective deltas). If the
  author writes entirely from the synthesis and never reuses the old spine, G2/G7 risk is lower
  — but the corrections still must be stated because the USER saw the old answers.
- Domain gap: I did not re-probe ADO live; I take V1–V13 (A1) as given per the synthesis. My
  attack is purely ask↔deliverable fidelity, not re-litigating the diagnosis.

## Verdict

**PROBLEMATIC (plan-as-described) — fixable with in-document additions, no re-diagnosis needed.**
The diagnosis is strong; the divergences are all about what the *delivered documents* must
explicitly say to honor the user's literal words. Two GATE-class gaps (G1 verify-100%-honesty,
G2 overturned-feynman-model) must be closed before status=complete, or the deliverable triggers
the user's own "if not, it's a failure" clause.
