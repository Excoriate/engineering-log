---
task_id: 2026-06-22-004
agent: kant-cognitive-scientist
status: complete
summary: |
  Adversarial cognitive-science attack on plan §B size strategy + FORK-2. The
  byte-neutral framing hides a COUNT-driven attention-dilution loss and a
  load-bearing-instruction-destruction risk. FORK-2 verdict: COMPRESS of REASONING
  is cognition-HARMING and violates the skill's own H-KNOW-1 thesis. The move the
  plan MISSED is SPLIT, not compress.
---

# ATTACK — Attention / Context-Window / Size Strategy (Kant Cognitive Scientist)

Win condition: prove plan §B size strategy + FORK-2 degrade the BUILDER's own cognition.
Frame: the builder's `SKILL.md` L2 IS the building-agent's working memory every time the
skill activates. Every byte/heuristic competes for finite attention against the agent's
actual authoring task. All claims graded A1 FACT (file:line witnessed this session) /
A2 INFER (derived) / A3 SPECULATIVE.

Evidence base (witnessed this session):
- L2 body = 70369 B / 1075 lines / ~17592 tok vs 28000 B / 500-line ceiling — 2.51× over
  [A1 `context/map-builder.md:17,287-298`; `check-skill-size.sh` output].
- 40 heuristics, uniform `**H-NAME**` + CONDITION/ACTION/REASONING triple
  [A1 `map-builder.md:46-91`; format `SKILL.md:443-447`].
- `## Operational Surfaces` = `SKILL.md:1005-1069`, ~65 lines, read in full this session [A1].
- H-KNOW-1 `SKILL.md:443-447`; H-KNOW-2 `:449-453`; H-KNOW-3 "Compress, do not merely
  delete" `:455-458` [A1].

---

## ATTACK 1 — Heuristic COUNT dilutes attention regardless of byte-neutrality. CONFIRMED.

**Claim attacked (plan §A/§B):** grouping 9 adds into "TIGHT stubs" + net-neutral bytes
keeps the cognitive load flat.

**Finding (A2 INFER, mechanism-grounded):** byte-neutrality is the WRONG conserved
quantity. The plan optimizes Law 1 (Attention Conservation) on the byte axis while the
real degradation is on the COUNT axis. Two distinct mechanisms:

1. **Set-recall degradation (Law 1 + lost-middle, Liu et al. 2023).** The builder does not
   apply ONE heuristic — at authoring time it must hold the WHOLE applicable set in working
   context and select. Going 40→~49 is a +22.5% increase in competing same-format items.
   Crucially, every heuristic shares the identical `**H-NAME**`/CONDITION/ACTION/REASONING
   surface form [A1 `SKILL.md:443-447`]. Self-attention discriminates poorly among
   near-identical-format, near-equal-salience items: the residual stream cannot privilege
   item 27 over item 41 when both have the same lead-token shape. Adding 9 more raises the
   probability that ANY given heuristic falls below the effective recall threshold. This is
   the builder applying the WHOLE set worse — exactly the question asked. Byte-neutrality
   does not touch this; it is a cardinality effect, not a length effect.

2. **The catalog sits in the LOST MIDDLE.** `## Heuristics` opens at `SKILL.md:344` and runs
   to ~700; the file is 1091 lines. The heuristic block occupies roughly the 31–64% span —
   dead-center of the lost-middle trough (Liu et al.: positions 30–70% receive minimum
   attention) [A2 from line spans `map-builder.md:60-63`]. There is NO name registry / index
   [A1 `map-builder.md:92-98`], so there is no primacy or recency anchor that re-surfaces a
   given heuristic. Adding 9 more items DEEPER into an already-trough-resident, unindexed
   block is the worst possible position for recall.

**WHEN-NOT honesty (Law 1 falsifier):** Law 1 weakens if the builder never loads the whole
catalog at once — if heuristics are retrieved on-demand per sub-task. But there is no
retrieval mechanism (no registry, no loader for L2 heuristics; the loader doctrine is NEW/
ABSENT per `map-builder.md:118`). So the whole block is resident every activation → Law 1
binds. Discriminating test: if a registry/index existed, count would matter less; it does
not exist.

**CONDITIONAL belief-change:**
> IF heuristic COUNT (not bytes) is the dilution driver → THEN "net-neutral bytes" is an
> insufficient acceptance gate. Plan §B/§D must ADD a COUNT gate: max-heuristic-count or a
> mandatory registry/index that creates a recall anchor. Net-neutral bytes alone = GATE-FAIL
> on the actual cognitive risk.

---

## ATTACK 2 — "REPLACE Operational Surfaces with a Reference Map" DESTROYS load-bearing
instruction. CONFIRMED — this is NOT net-neutral, it is net-LOSS of obligation semantics.

I read `SKILL.md:1005-1069` in full [A1]. The plan (§B.1, §Q7.2 of the map) calls this block
"~65 lines of per-surface obligation prose" and proposes REPLACE with "a tighter linked map."
That mischaracterizes what the block DOES.

**What `## Operational Surfaces` actually encodes (A1, witnessed):** it is not a link
inventory. Each entry carries a 4-part ENFORCEMENT CONTRACT per surface:
- `**required** by <which mode/step>` (the trigger binding) — e.g. `:1022,:1023,:1026,:1030`
- `EVIDENCE OF USE:` (the observable that proves the agent ran it) — e.g. `:1016,:1023`
- `BLOCKED-PATH:` (what the agent MUST NOT claim if the surface is missing/fails) — e.g.
  `:1018,:1023,:1026`
- per-surface failure tokens (`STRUCTURE-GATES-UNAVAILABLE`, `CLAIM-LEDGER-MISSING`,
  `GOLDEN-MODEL-MISSING`, `CALIBRATION-LOOP-MISSING`, etc.) `:1022,:1026,:1041,:1050`.

This is the SAME doctrine H-ASSIM-1/2 mandate ("Mandatory means observable" — trigger +
action + evidence + blocked-path) [A1 `map-builder.md:120-127`]. A "tight linked Reference
Map" is, BY DEFINITION (FB-3 = "linked inventory" `map-builder.md:116`), link + load-WHEN
trigger. It carries NO `EVIDENCE OF USE` and NO `BLOCKED-PATH`. So REPLACE silently DELETES
the per-surface enforcement contract for ~14 surfaces — including the master certification
gate's BLOCKED-PATH at `:1018` ("a non-zero exit BLOCKS Create-mode complete… do NOT cite a
subset of gates"). That blocked-path is the instruction stopping the builder from declaring
a skill release-ready on partial validation. Deleting it = the builder's own helpful-
destroyer failure mode (Law 4) goes unguarded.

This collides head-on with the project's OWN `l2-residency-contract.md`: Enforcement Contract
is an L2-REQUIRED, never-relocate section (`L1-010`, H-ENFORCE-3) [A1 `map-builder.md:144-155`].
The Operational-Surfaces obligations ARE enforcement contract. REPLACE-with-map = "trades a
size PASS for a coherence FAIL" — the precise failure that contract exists to block
(`map-builder.md:166-167`).

**CONDITIONAL belief-change:**
> IF Operational Surfaces encodes per-surface EVIDENCE/BLOCKED-PATH enforcement (it does, A1
> `:1016-1069`) → THEN plan §B.1 "REPLACE … with a tight Reference Map" must become
> "ADD a primacy `## Reference Map` (links + load-WHEN only) AND PRESERVE the obligation
> contract." The contract may be COMPRESSED in place (drop prose, keep the 4 tokens per
> surface as a table) but NOT replaced-away. Net-neutral funding must come from elsewhere,
> NOT from deleting enforcement semantics. Bare REPLACE = HALT.

---

## ATTACK 3 — FORK-2 CRUX: COMPRESSING REASONING prose is COGNITION-HARMING and
self-refuting. The deferred §8 COMPRESS pass VIOLATES the skill's own thesis.

The §8 deferred pass = "collapsing each heuristic's REASONING prose into a denser single-line
form" to recover ~80–120 lines [A1 `map-builder.md:309-310`].

**The skill's own thesis (A1):**
- H-KNOW-1 `SKILL.md:447`: "Reasoning turns instructions into transferable JUDGMENT."
- H-KNOW-2 `:451-453`: keep a line only if "the model already knows it" is false AND it
  "changes a decision."
- H-KNOW-3 `:455-458`: **"Compress, do not merely delete… Shorter is only better if the
  resulting skill is SMARTER."**

**Mechanistic verdict (A2 INFER):** The REASONING line is the part of each heuristic that is
NOT inferable from the ACTION. CONDITION+ACTION = an imperative the model can pattern-match.
REASONING = the WHY that lets the model GENERALIZE the heuristic to an unseen case (transfer).
Stripping REASONING to a single dense line risks crossing H-KNOW-2's own filter in reverse:
it removes the lines that DO change a decision (the transfer signal) to save bytes — the
exact "weak shorter" H-KNOW-3 forbids. The skill would be applying a COMPRESS that its own
H-KNOW-3 classifies as "merely deleting dressed up as compression" unless each collapsed
REASONING demonstrably stays decision-changing. There is no evidence that mechanical single-
lining preserves transfer; the §8 note frames it purely as line-recovery, i.e. byte-driven,
not judgment-driven. **A compression justified by byte count, applied to the judgment-bearing
field, is the skill failing its own H-KNOW-1/3 test.** This is the self-refutation.

**Caveat (honest):** SOME of the 40 REASONING lines may genuinely be padding (H-KNOW-2 would
have caught them already, but drift happens). A SELECTIVE, per-line, judgment-driven compress
(each line re-tested against H-KNOW-2) is legitimate. A BLANKET "single-line them all" pass to
hit a byte target is not. FORK-2 as written ("full COMPRESS pass of the existing 40
heuristics' REASONING") is the blanket form.

**FORK-2 VERDICT (cognition-grounded):**
> **REJECT "full COMPRESS pass" as a byte-funding mechanism. REJECT "net-neutral-now via
> REPLACE" as written (Attack 2). The correct move is NEITHER fork as framed.**
> - Full-compress: harms transfer, self-refutes H-KNOW-1/3. NO.
> - Net-neutral-via-replace: destroys enforcement contract (Attack 2). NO as written.
> - **Verdict → the third option the plan under-weighted: net-neutral via a JUDGMENT-DRIVEN,
>   PER-LINE compress (re-test each touched REASONING against H-KNOW-2, keep transfer signal)
>   IF any compress at all — but the structurally correct fix is SPLIT (Attack 4).**

---

## ATTACK 4 — The move the plan MISSED: the meta-skill needs SPLITTING, not compressing.

**The deepest finding (Deep Why → Law 1).** The root cause is not prose verbosity. It is that
ONE L2 surface (70369 B) is forced to hold TWO distinct cognitive jobs at once:
(a) the AUTHORING decision-core (heuristics + endgame + structure the agent applies WHILE
building), and (b) the OPERATIONAL/REFERENCE doctrine (the 65-line Operational Surfaces gate
catalog + reference obligations the agent consults ON-DEMAND). These have different
activation profiles: (a) is needed every authoring decision; (b) is needed only when running
gates. Co-residency forces (b) to consume activation-time attention it does not earn — which
is LITERALLY what `SKILL.md:1007` already admits: *"Use these on demand instead of inflating
L2."* The block announces it is on-demand content yet sits in the always-loaded L2.

**Mechanism:** Law 1 says every co-resident token subtracts attention from the authoring core.
The Operational Surfaces catalog (~65 lines of gate-invocation detail) is reference material
that, per the skill's own `skill-structure.md` L3 doctrine [A1 `map-builder.md:324-326,331`],
belongs in a reference. Compressing it leaves it co-resident (still stealing attention, just
less). SPLITTING it to its own loaded surface (an L3 `references/operational-surfaces.md`
holding the full EVIDENCE/BLOCKED-PATH contract, with only a primacy `## Reference Map` of
links + load-WHEN remaining in L2) does BOTH: preserves the enforcement contract (fixes
Attack 2) AND removes ~65 lines of always-on attention cost (funds Attack 1's adds) WITHOUT
touching judgment-bearing REASONING (avoids Attack 3). The l2-residency-contract's "allow-list"
already permits relocating verbose protocols/catalogs to L3 (`map-builder.md:155`) — the
Operational Surfaces catalog qualifies; the ENFORCEMENT semantics stay protected by keeping
the contract intact in the L3 file and a residency row pointing to it.

**Why the plan missed it:** §B framed the choice as compress-vs-replace (both operate on the
SAME co-resident block). It never questioned whether the block should be CO-RESIDENT at all.
That is the un-complect move (separate authoring-core from operational-reference).

**CONDITIONAL belief-change:**
> IF Operational Surfaces is on-demand reference content (it self-declares so, `:1007`) AND
> L3 relocation of catalogs is allowed (`map-builder.md:155`) → THEN plan §B should SPLIT:
> extract the obligation contract to `references/operational-surfaces.md`, leave a primacy
> `## Reference Map` (links + load-WHEN) in L2, add the residency-contract row (C5). This
> funds the 9 heuristic adds via ~65 reclaimed always-on lines, preserves enforcement, and
> never compresses REASONING. Replaces FORK-2 entirely.

---

## HIGHEST-STAKES COGNITIVE RISK (single)

**The byte-neutral framing of §B optimizes the WRONG conserved quantity and, by choosing
REPLACE, would silently delete the per-surface BLOCKED-PATH enforcement (`SKILL.md:1018`,
:1023, :1026) that stops the builder from certifying a skill on partial validation.** If
false → builder under-validates and ships NOT-READY skills as CERTIFIED (Law 4 helpful-
destroyer). Falsifier: after the §B edit, run `validate-skill-complete.sh` against a skill
with one failing gate — if the builder's L2 no longer carries the "non-zero exit BLOCKS
complete / do NOT cite a subset of gates" instruction, the regression is realized.
Stakes-class: HIGH.
