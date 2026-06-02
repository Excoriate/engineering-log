---
task_id: 2026-06-02-001
agent: goal-fidelity
status: complete
summary: Goal-fidelity attack on the 4-doc package against Johnson Lobo's verbatim Slack ask + Alex's UAC. Package is technically strong and honest on the VPP-Core-cert point, but DIVERGES on findability of Nuno's explicit secret-provider question (never answered as a quotable yes/no) and has a UAC replication gap (the Feynman recipe omits the auth/connect step it itself depends on). One BLOCKING, two HIGH, three MEDIUM divergences. Verdict: NOT-YET-SATISFIED pending the two BLOCKING/HIGH fixes.
timestamp: 2026-06-02T11:05:00Z
---

# Goal-Fidelity Adversarial Receipt — vpp-agg Sandbox `keys` secret

## Win condition

Find DIVERGENCE between (a) Johnson Lobo's verbatim Slack ask + Nuno's question, (b) Alex's standing instructions + UAC, and (c) what `context.md / rca.md / fix.md / how-to-feynman-explainer.md` actually deliver. I do NOT judge technical correctness (other reviewers own that); I judge ask↔deliverable fidelity and findability. Read-only — no deliverable mutated.

## Ground-truth ask (verbatim, from `slack-intake.md`)

- J1: "VPP aggregation sandbox is broken. It is missing the secret called 'keys'." + `FailedMount ... secret 'keys' not found`.
- J2: "Our certificates were also expired. Now I have used the ones from VPP Core."
- J3 (Nuno→Johnson, the secret-provider expectation): "Ideally those secrets needs to be installed via secret provide right ?" / Nuno: "That's what I was going to ask, what is the expectation here. I'm not 100% sure on this as the setup in sandbox is very different from MC envs, but will find out".
- UAC (verbatim): "You have to use ... the `how-to-feynman` skill, so it's explained in a .md document what you did, how, why, etc. So, I learn. I must be able to understand deeply your rationale, and replicate it by myself. If not, it's a failure."
- Standing: "Ensure max verification. No space for assumptions." + "max quality and reliability." + use `eneco-context-repos`, `eneco-context-docs`, `eneco-tools-connect-mc-environments`; turn whitelisting OFF after (note: Sandbox is Azure-CLI only — no MC whitelist, so whitelist toggle is N/A here).

## Coverage matrix (ask → where answered → findable?)

| Verbatim ask | Addressed? | Where | Findable by a fresh reader? |
|---|---|---|---|
| J1a — why `keys` was missing | YES, strongly | rca TL;DR, L5 three-truths, L6 pipeline | YES — clearest part of the package |
| J1b — what `keys` IS | YES | context ledger, rca L4 | YES |
| J2 — expired-cert angle | YES | rca L7 timeline, L10.3 (LL-006 class), fix Layer 2 | YES |
| J3 — "should it be via a secret provider? right?" | PARTIAL — answered implicitly via the durable fix, but Nuno's literal question is never quoted and never given a labeled "Yes, you're correct" | rca L8 / fix Layer 1 (implicit); rca:309 answers a *different* question ("does a provider exist") | NO — see D1 |
| J2b — "is borrowing VPP Core certs correct?" | YES, honestly | rca L10.6, L9.2, fix:32, feynman:139 | YES — see D3 (honest, minor finding only) |
| UAC — teach + replicate unaided | MOSTLY | feynman explainer end-to-end | PARTIAL — see D2 (auth/connect step missing from the recipe) |

## Divergences

### D1 — [BLOCKING] Nuno's explicit secret-provider question is never answered as a findable, quotable yes/no

- Verbatim ask missed: J3 — "Ideally those secrets needs to be installed via secret provide right ?" and Nuno's "what is the expectation here ... the setup in sandbox is very different from MC envs."
- What the docs do: the durable fix (rca L8, fix Layer 1) recommends wiring `keys` into the CSI SecretProviderClass, which *implies* "yes, via the provider." But nowhere is Johnson's/Nuno's question restated and answered directly. A `grep` of all four docs for "secret provide / expectation / installed via" returns only `rca.md:309`, which rebuts a *different* proposition — "Sandbox has no secret provider" (does one EXIST) — not "SHOULD `keys` be installed via the provider, and is Johnson right" (what SHOULD happen). The intended-vs-actual nuance (wiki documents ESO as the *intended* pattern, while CSI is what actually runs — context ledger rows ESO/CSI) is never tied back to "so, to answer your question: yes, ideally via a provider; the documented ideal is ESO, the running one is CSI; here is which we recommend and why."
- Why this is BLOCKING for goal fidelity: J3 is one of only three things the reporter explicitly asked, and the only open *question* (J1/J2 were statements). The package answers the questions the analyst found interesting (mechanism, durable fix) but leaves the reporter's literal question without a locatable answer. A reader scanning for "did they answer my secret-provider question?" will not find it.
- Exact doc+section to fix: add a short, explicitly-titled subsection — e.g. rca.md new heading `L8.0 — Answering Nuno's question: should `keys` go via a secret provider?` (or a callout at the top of fix.md Layer 1) — that (1) quotes the question, (2) states "Yes — ideally `keys` is installed via a secret provider, not by hand," (3) names the documented ideal (ESO) vs the running mechanism (CSI SPC) and which is recommended for Sandbox and why, (4) explicitly scopes the answer to Sandbox and notes the MC setup may differ (honoring Nuno's "sandbox is very different from MC ... will find out").

### D2 — [HIGH] UAC replication gap: the Feynman recipe omits the auth/connect step it depends on

- Verbatim ask missed: UAC — "I must be able to ... replicate it by myself. If not, it's a failure."
- What the docs do: `how-to-feynman-explainer.md` "Reproduce the diagnosis from cold" lists 5 question-driven probe steps — all of which assume `kubectl -n vpp-agg ...` and `$SB` already work. The actual auth/connect ritual (`az login --tenant ...`, `az aks get-credentials ... --file /tmp/sb.kubeconfig`, `export KUBECONFIG=...`, set `SB=...`) lives only in rca.md L11 — NOT in the explainer. The explainer is the document the UAC names ("the `how-to-feynman` skill ... so I ... replicate it by myself"); a reader following ONLY the explainer cannot run step 1 because they were never told how to connect to Sandbox. This is precisely the "I cannot replicate this → failure" trigger.
- Secondary replication gap: the standing instruction names `eneco-tools-connect-mc-environments` as the connect method. The explainer never references that skill or the `mc-connect-sandbox.sh` path; the connect ritual is only the raw `az` commands in rca L11. The teach-yourself doc should point the learner at the connect skill/script by name so they can reproduce the access step the same way the analyst did.
- Why HIGH not BLOCKING: the information EXISTS in the package (rca L11), so a determined reader can stitch it together. But the UAC's bar is "replicate by myself [from the Feynman doc]," and the Feynman doc is not self-contained for the very first action. Cross-link + a one-line "Step 0: connect (see RCA L11 / `eneco-tools-connect-mc-environments`)" closes it.
- Exact doc+section to fix: `how-to-feynman-explainer.md` — add a "Step 0 — get read-only Sandbox access" before probe step 1, with the `az login`/`get-credentials`/`KUBECONFIG`/`SB=` block (or an explicit pointer to rca.md L11 and the `eneco-tools-connect-mc-environments` skill).

### D3 — [LOW] VPP-Core-cert honesty point: handled honestly; minor softening only

- Verbatim ask: J2 — "Our certificates were also expired. Now I have used the ones from VPP Core." Reviewer instruction #3: the live cert is the AGG's own `esp-eet-vpp-dt` identity, NOT VPP Core's — is the discrepancy surfaced honestly?
- Finding: YES, honestly surfaced and NOT glossed. rca L10.6 states plainly: "The live `keys` client cert is the AGG's *own* identity `esp-eet-vpp-dt` (valid to 2027), not a VPP Core identity ... Flagging so nobody 'fixes' a non-problem." Reinforced at rca L9.2, fix:32, feynman:139, and self-test Q4. This satisfies "no space for assumptions" — the discrepancy between Johnson's claim and the observed identity is named, not assumed away. PASS.
- Minor softening (LOW, optional): rca L10.6 says Johnson's note "was either a superseded intermediate step or loose phrasing" — that itself is a small INFER about Johnson's intent presented without a probe. It is appropriately hedged ("either/or") and does not drive any action, so it does not breach the no-assumptions bar. Optional tightening: state only the observable ("live cert CN = esp-eet-vpp-dt; this is the AGG identity, not VPP Core") and drop the speculation about why Johnson said it. No fix required for satisfaction.

### D4 — [MEDIUM] "No space for assumptions": two inferences sit close to decision points without a probe-or-bound label at the point of use

- Verbatim ask: standing — "Ensure max verification. No space for assumptions."
- Findings (both are honestly A2-labeled in the evidence ledger, so this is a findability/placement issue, not dishonesty):
  - `fix.md` Layer 1 caveat (b) recommends "have the app build the keystore from PEM at startup ... Recommend (b) if the Confluent client supports PEM keystore (it does in recent versions)." The parenthetical "it does in recent versions" is an unprobed capability claim embedded in a recommendation the reader may act on. Per "no space for assumptions," this should carry an explicit `A3 UNVERIFIED[blocked: Confluent/.NET client version not probed]` at the point of recommendation, or be downgraded to "verify the client version supports PEM keystore before choosing (b)."
  - rca L7 / ledger #9: "previous cert expired ~6 months ago" is A2-labeled (good) but the timeline mermaid renders "~late 2025 : previous Kafka cert expires" as if observed; the A2 nature is only disclosed in prose below the diagram. Acceptable but the diagram reads more certain than the evidence. MEDIUM.
- Why MEDIUM: these are correctly classified in the ledger; the gap is that a reader acting on the fix.md recommendation sees the assumption without the label at the decision point. The user's "no space for assumptions" bar wants the caveat visible exactly where the choice is made.
- Exact doc+section to fix: `fix.md` Layer 1 caveat option (b) — append the version-verification gate / A3 label. `rca.md` L7 timeline — annotate the "~late 2025 expiry" node as inferred (it already says A2 in prose; mirror it in/under the diagram).

### D5 — [MEDIUM] Environment scoping is correct but the answer to J3 is not explicitly Sandbox-bounded

- Verbatim ask: Nuno — "the setup in sandbox is very different from MC envs."
- Finding: the package is correctly SANDBOX-scoped throughout (context "Scope = one Sandbox incident"; rca uses `vpp-aks01-d` / `rg-vpp-app-sb-401` / KV `vpp-agg-sb` / sub `7b1ba02e-...`; fix Layer 1 "in *every* environment, Sandbox included"; fix:115 "does not touch MC ... apply ... there only after Sandbox is proven"). No MC mis-scoping detected — environment correctness PASSES. The gap is only that the *answer to the provider question* (D1) does not explicitly carry the "this is the Sandbox answer; MC may differ" caveat Nuno flagged. Folds into the D1 fix.
- Exact doc+section to fix: same subsection as D1 — add the one-line Sandbox-scope caveat.

### D6 — [MEDIUM] Skill-usage evidence (`eneco-context-repos/docs/connect`) is asserted, not shown, in the consumer-facing docs

- Verbatim ask: standing — "use skills `eneco-context-repos`, `eneco-context-docs`, `eneco-tools-connect-mc-environments`."
- Finding: the outcome docs reference the *outputs* of these skills (ADO file fetches, wiki/ADR findings, live Sandbox probes) and the context.md probe table cites lane files (`lane-r1-chart.md`, `lane-d1-docs.md`, `live-sandbox-probe.md`) implying the skills were used. rca L11 names "(eneco-context-repos) ado-repo-search". But `eneco-tools-connect-mc-environments` is never named in the consumer docs — only the raw `az` commands appear. For the user's learning/replication goal, the doc should say "access via the `eneco-tools-connect-mc-environments` skill (Sandbox path)" so the learner reproduces the access the documented way. Read-only discipline: confirmed — every doc states probes were read-only and Johnson's restored secret was NOT deleted (rca:307, feynman:138, the durable fix proposes delete-to-test as a *future acceptance test*, not an action taken). PASS on read-only.
- Exact doc+section to fix: name `eneco-tools-connect-mc-environments` in the explainer Step 0 (folds into D2) and optionally in context.md "Evidence probes run."

## What PASSES (no divergence)

- J1 (why `keys` missing): exemplary — define/deploy/provision distinction, three-truths, dead-code mechanism. Findable and teachable.
- J2b (borrowed-cert honesty): the discrepancy is surfaced, not glossed — meets "no space for assumptions." (D3 is LOW/optional.)
- Environment correctness: consistently Sandbox-scoped; no MC mis-attribution.
- Read-only discipline: stated and consistent; Johnson's manual `keys` secret is preserved, not deleted.
- Feynman doc quality (content): strong — Knowledge Contract, first-principles ladder, mermaid/ASCII visuals, anti-patterns, self-test, transfer test. The teach-and-replicate INTENT is genuinely met for the *reasoning*; the gap (D2) is the missing connect step, not the explanation quality.
- AI-slop check: no empty "this is an important consideration" filler detected; sections carry signal; commands shown were run-shaped (metadata-only, `-o tsv` gotcha, no secret values). No overclaiming beyond the labeled A3 residual.

## Verdict

NOT-YET-SATISFIED. The package is high-quality and honest, but it does not yet clear the user's literal ask + UAC because of two load-bearing gaps:

- BLOCKER 1 (D1): Nuno's explicit "should these be installed via a secret provider, right?" question has no findable, quotable yes/no answer scoped to Sandbox. The reporter's only literal question is answered only by implication.
- BLOCKER 2 (D2): the UAC document (`how-to-feynman-explainer.md`) is not self-contained for replication — the first probe step assumes Sandbox access the doc never tells the reader how to obtain. By the UAC's own standard ("replicate by myself ... If not, it's a failure"), this is a replication gap.

Resolve D1 and D2 and the package SATISFIES the ask + UAC. D4/D5/D6 (MEDIUM) and D3 (LOW) are quality tightenings that should be applied but are not, alone, satisfaction blockers.

## Epistemic note

These findings are goal-fidelity (ask↔deliverable) only. I did NOT re-probe Azure/IaC; technical correctness of the root cause, the CSI-projection feasibility, the pfx caveat, and the cert validity dates are out of this lane and belong to the technical-correctness reviewer. All quotes above are A1 (verbatim from `slack-intake.md` and the four outcome docs, file:line cited). The "BLOCKING" labels are about fidelity to the literal ask, not about technical severity of the incident.
