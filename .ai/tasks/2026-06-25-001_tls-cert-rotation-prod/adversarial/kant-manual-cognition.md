---
title: Kant Cognitive Autopsy — Agent-Driven Step-by-Step Execution of PROD TLS Rotation
task_id: 2026-06-25-001
agent: kant-cognitive-scientist
timestamp: 2026-06-25
status: complete
target: log/employer/eneco/02_on_call_shift/2026_june/2026_06_24_renewal_vpp_tls_certificates/rotation-execution-spec.md
companion: how-the-vpp-tls-rotation-works.md
review_frame: Kant (epistemic / agent-cognition under step execution)
verdict: conditional
verdict_detail: CONDITIONAL-GO (manual agent execution) — BLOCKING on G1, G2, G5; prefer in-process orchestrator
summary: |
  The cert MECHANICS are sound (already reviewed by socrates/el-demoledor/sre-maniac). This review
  attacks only the AGENT-AS-EXECUTOR cognition under the stated model: each step = a FRESH shell, shell
  vars do NOT persist, the agent reads each probe's stdout and decides to advance. Under that model the
  spec has ONE dominant, BLOCKING defect: nearly every probe compares a freshly-computed value against a
  `$VAR` that was set in a PRIOR step's shell and is therefore EMPTY at probe time. Several of those
  comparisons are SUCCESS-SHAPED when the var is empty (empty==empty, or a substituted-empty produces a
  benign-looking string), so the agent advances on a false belief. Three more cognitive traps: control-plane
  success read as user-effect, premature single-host completion, and the `finally` (Step 8) being abandoned
  on an error path. Guardrails below convert each into a probe whose output DIFFERS between truth and the
  self-deception.
---

# Kant Cognitive Autopsy — Manual / Agent Step-by-Step Execution

## Key Findings

- **F1** — cross-shell variable evaporation makes probes compare against EMPTY; several fail success-shaped (BLOCKING)
- **F2** — `az` exit-0 / `provisioningState=Succeeded` mistaken for "cert is served" (BLOCKING — needs wire-handshake gate)
- **F3** — object-name vs ssl-cert-resource-name confusion can target wrong resource and still return 0
- **F4** — premature completion: single host, or pre-AVD-handshake, declared as done
- **F5** — the `finally` (Step 8 firewall removal) can be skipped on an error/abort path (BLOCKING)
- **F6** — probe-interpretation: empty/whitespace tsv read as a value; failure output == expected output
- **F7** — rollback trigger criterion is not mechanically unambiguous for step-by-step execution

**Scope of THIS review:** not the certificate mechanism (sound, already adversarially reviewed), but the
**cognition of a Claude Code agent executing one step per fresh Bash call**, reading each probe's stdout,
deciding whether to advance, with a human confirming each step.

**Execution model under attack (given):** each step is a *fresh shell* — shell variables defined in step N
do NOT exist in step N+1. `AZURE_CONFIG_DIR` survives on disk only if re-exported. The agent's only carried
state between steps is what it (or the human) writes down and re-supplies.

**Win condition:** find where this model lets the agent DRIFT / MIS-JUDGE / SELF-DECEIVE, and name the
per-step guardrail ("before advancing past Step N, the agent MUST OBSERVE Z") that makes the false belief
impossible to hold.

---

## F1 — Cross-shell variable evaporation: probes compare against EMPTY and several fail SUCCESS-SHAPED  [BLOCKING]

**Evidence (spec):** Session setup defines `SUB RG KV OBJ AGW SSL VLESS PFX PW MYIP` and `OLD_SID/OLD_THUMB`
(L101-107, L147-148); Step 3 sets `NEW_SID NEW_VER NEW_THUMB` (L170-172). Downstream probes consume them:
Step 4 `[ "$EXPECT" = "$NEW_THUMB" ]` (L194); Step 5 `--version "$NEW_VER"` and `[ "$LATEST" = "$NEW_THUMB" ]`
(L208, L216); Step 6 `--key-vault-secret-id "$NEW_SID"` … `"$VLESS"` (L229-230); Step 7 compares served fp
to `$NEW_THUMB` (L256, L261); Step 8 `--ip-address "${MYIP}/32"` (L274); Rollback `"$OLD_SID"` / `"$NEW_VER"`
(L296, L300).

**Drift / self-deception mechanism (Lens E — inhabiting the agent):** *"Step 5 says enable `--version
"$NEW_VER"`. I am a fresh shell. `$NEW_VER` is unset, so it expands to empty. `az keyvault certificate
set-attributes --version ''` — az treats an empty `--version` as 'operate on the **current** version.' The
command returns 0. The probe `[ "$LATEST" = "$NEW_THUMB" ]` compares two **empty** strings → `'' = ''` →
TRUE → prints `✅ versionless now resolves to NEW`. I advance, convinced the NEW version is live. In reality
I may have toggled the OLD version's attributes and never touched NEW at all."* This is **Law 7 (Existence
Assumption)** + the shell's empty-string affirmation: the agent assumes the variable exists because the spec
text shows it being set — but the spec's *paragraph framing* ("logs in … and defines the variables the later
steps reuse," L93) primes the agent to believe state carries across steps. It does not, under this model.

The danger is not uniform — classify each:
- **Fails SAFE (false-negative, acceptable):** Step 4 gate (L194) — `$EXPECT` recomputes non-empty from the
  PFX, so `non-empty = "" ` → MISMATCH → STOP. Annoying but safe.
- **Fails DANGEROUS (false-positive / wrong-target):** Step 5 (`'' = ''` → ✅; empty `--version` hits current
  version, L208/L216); Step 6 (`--key-vault-secret-id ""` may error OR set an unintended binding, L229);
  Step 7 (served fp vs empty `$NEW_THUMB`, the normalize-compare can read as "matches nothing" yet the agent
  may still narrate success from the expiry line alone, L256); Step 8 (`--ip-address "/32"` — empty `$MYIP`
  → removes nothing, or errors, while the agent believes the firewall is closed, L274); Rollback (empty
  `$OLD_SID`/`$NEW_VER` → repoints AGW at a malformed/empty URI → **listener auto-disable → outage**, L299).

**Severity: CRITICAL.** This single structural mismatch between the spec's authoring model (one long shell)
and the execution model (fresh shell per step) poisons the gate logic of Steps 5, 7, 8 and Rollback.

**Per-step guardrail (BLOCKING — add before manual/agent run is authorized):**

> **G1 — State re-hydration preamble at the TOP of every step.** Before the step's command, the agent MUST
> emit and the human MUST confirm the carried values, then the agent MUST `printf '%s\n' "$VAR"` each
> variable the step consumes and **observe a non-empty, shape-correct value** before running the command.
> Concretely:
> - Before advancing past **Session re-entry** of ANY step: `: "${NEW_VER:?STOP-empty}" ; : "${NEW_THUMB:?STOP-empty}"` etc. for that step's inputs. A `parameter null or not set` abort is the
>   guardrail firing correctly — the agent MUST treat it as STOP, not retry-blind.
> - **Step 5 specifically:** the agent MUST NOT run `set-attributes` until it observes `NEW_VER` is a
>   40-hex-ish version GUID (`[ -n "$NEW_VER" ]` AND length>0 printed). An empty `--version` is FORBIDDEN
>   because az silently retargets the current version.
> - **Step 8 specifically:** the agent MUST observe `MYIP` re-resolves to the SAME value used in Step 1
>   (`curl -4 -s ifconfig.me`) AND that value is non-empty, BEFORE the remove. If `MYIP` changed or is empty,
>   the agent MUST switch to the enumerate-and-remove path (`--query "networkAcls.ipRules[].value"`, L286)
>   and remove every operator-added rule, then re-probe to `0`.
>
> **Mechanism-level fix (preferred, symmetric to Law 5/entropy):** the spec should externalize state to disk,
> not shell vars — write `NEW_VER`, `NEW_SID`, `NEW_THUMB`, `OLD_SID`, `MYIP` to a `state.env` file in Step 1-3
> and `source` it at the top of every later step. This is exactly what `rotate_tls.go` already does in-process;
> the Manual mode must mirror it or carry the explicit `:?` guards. **Recommendation: in agent mode, prefer the
> scripted orchestrator (`./rotate_tls -step <name> -execute`), which holds state in one process and cannot
> evaporate it between steps.** Manual mode is the cognitively fragile path.

---

## F2 — Control-plane success read as user-observable effect ("Succeeded" ≠ "served")  [BLOCKING gate already present; must be hardened against agent shortcut]

**Evidence:** the spec is explicit — "Success = EFFECT … not `az` exit 0" (L41); Step 6 probe expects
`provisioningState=Succeeded` (L236); Step 7 is "the **only** proof the rotation actually took effect" and
warns `az` exit 0 "does **not** prove the gateway is serving the new leaf" (L248). The companion doc's whole
"dangerous shortcut" section (L203-220) and durable principle (L289) hammer this.

**Drift / self-deception mechanism (Lens E):** *"Step 6 returned `provisioningState=Succeeded` and the
ssl-cert shows the versionless URI. That's two green probes. The hard part (the toggle) is done. Step 7 needs
AVD, which is friction. The control-plane proxies in the Step-7 note (L266) say they're 'strong for a
like-for-like renewal.' I'll record success and let the human do the handshake later."* This is **Law 4
(Training Prior Supremacy)** — "command succeeded → task done" is the overwhelming prior — colliding with
**Law 2 (Recency)**: the Step-7 escape hatch sentence ("As an interim … you still have the control-plane
proxies … strong for a like-for-like renewal," L266) is the LAST thing the agent reads in Step 7 and gives it
a permission structure to skip the wire handshake. The spec author intended that sentence as a fallback for an
unreachable-AVD case; an agent under completion-pressure will read it as license.

**Where the agent MUST refuse to say "done":** after Step 6 (`Succeeded`), after Step 5 (`✅ versionless
resolves to NEW`), and even after the Step-7 control-plane proxies. NONE of these is "served."

**Severity: HIGH (the gate exists; the failure is an agent shortcut around it).**

**Per-step guardrail (BLOCKING):**

> **G2 — "Done" is a locked token.** Before advancing past **Step 7**, the agent MUST observe a real TLS
> handshake from AVD/internal (`openssl s_client`) returning BOTH `notAfter=Dec 30 ... 2026 GMT` AND a served
> fingerprint that, after normalization (L259-261), equals the new thumbprint — **on all four hosts** (see F4).
> The agent is FORBIDDEN to emit the word "done"/"complete"/"rotated" on the basis of `provisioningState`,
> `enabled=true`, `latest==new`, or Resource-Health alone. Reword the Step-7 fallback (L266) so the agent
> cannot mistake it for completion: prepend **"INTERIM SIGNAL ONLY — NOT a completion criterion; the run
> stays `status: partial / unverified` until a wire handshake is observed."** If AVD is unreachable, the
> correct agent action is HALT-and-handoff with `status: partial`, never "done."

---

## F3 — Object-name vs ssl-cert-resource-name confusion (wrong target, still returns 0)  [HIGH]

**Evidence:** the two-name trap is called out (L21-23, L102, L175): KV **object** `wildcard-vpp-eneco-com`
(`$OBJ`) vs AGW **ssl-cert resource** `wildcard-vpp-frontend-https` (`$SSL`). Step 6 uses `-n "$SSL"` on the
AGW (L229-230); all KV steps use `--name "$OBJ"`.

**Drift / self-deception mechanism (Lens E):** two failure shapes. (a) **Semantic priming (Law 3):** both
names start `wildcard-vpp-…`; the agent, re-typing or re-deriving a name in a fresh shell, can swap them. A
`az keyvault certificate show --name wildcard-vpp-frontend-https` returns **NotFound** (loud, safe). But (b)
the dangerous direction: `az network application-gateway ssl-cert update -n wildcard-vpp-eneco-com` — if an
ssl-cert by that name does NOT exist, az errors (safe); but under fresh-shell evaporation `$SSL` could be
empty and az may operate on a default/only ssl-cert and return 0 (wrong-target-success). The spec never makes
the agent ECHO which name it is about to act on against which resource type.

**Severity: HIGH** (mostly fails loud, but the empty-`$SSL` path crosses into F1's dangerous zone).

**Per-step guardrail:**

> **G3 — Name-binding assertion before any mutate.** Before Step 6 the agent MUST observe both: the AGW
> ssl-cert exists under `$SSL` (`az network application-gateway ssl-cert show -g "$RG" --gateway-name "$AGW"
> -n "$SSL" --query name -o tsv` == `wildcard-vpp-frontend-https`) AND `$SSL` is non-empty. Before any KV
> step the agent MUST observe `$OBJ` == `wildcard-vpp-eneco-com`. Add a one-line literal cross-check the agent
> reads aloud: "KV object = wildcard-vpp-eneco-com (versions); AGW ssl-cert = wildcard-vpp-frontend-https
> (reference). Never pass one where the other belongs." A command targeting the wrong type returns NotFound —
> treat NotFound as STOP-and-recheck-name, never as "already done."

---

## F4 — Premature completion: single host, or pre-AVD-handshake, declared as done  [HIGH]

**Evidence:** Step 7 loops all four hosts (L251-253) and the probe says "expect on ALL four" (L256). The
companion notes the four listeners share ONE ssl-cert so "a check on any one of them is evidence for all four"
(L173).

**Drift / self-deception mechanism (Lens E):** the spec's own L173 ("a check on any one … is evidence for all
four") is a **double bind (Law 6)** against Step 7's "expect on ALL four." The agent, having handshaked
`agg.` successfully (the single normalized example at L260-261 only does `agg.`), will cite L173 to justify
**not** checking `gurobi/apollo/flex-trade-optimizer`. That reasoning is *architecturally* true (shared
ssl-cert) but operationally fragile: a per-listener disable (a documented failure mode, L254, L320) can leave
one host broken while `agg.` serves fine. The agent resolves the contradiction toward the cheaper action.

**Severity: HIGH** (single-host success masking a per-listener failure on a PROD wildcard).

**Per-step guardrail:**

> **G4 — All-four observation, explicitly enumerated.** Before advancing past Step 7 the agent MUST print one
> result line per host for `agg / gurobi / apollo / flex-trade-optimizer` and observe `notAfter=Dec 30 2026`
> on **each**. Resolve the L173 vs L256 contradiction in the spec's favor of L256: add "the shared-ssl-cert
> argument explains WHY one rotation covers four, but does NOT excuse skipping the four-host verify — a
> per-listener disable can break one host while another serves; you MUST observe all four." The single-host
> normalized example (L260-261) should be turned into the four-host loop with the normalize pipe inside it, so
> the agent's default action verifies all four, not one.

---

## F5 — The `finally` (Step 8 firewall removal) abandoned on an error/abort path  [BLOCKING]

**Evidence:** "Whitelist-off is a `finally` — the scripted mode guarantees it; in manual mode *you* must run
Step 8 even on failure" (L40); "You are the `finally`: if anything fails after Step 1, still run Step 8"
(L89); Step 4 MISMATCH path explicitly says "then go to **Step 8** to clean up the firewall" (L199); per-step
note: a single `-execute` step does NOT auto-remove the firewall (L85).

**Drift / self-deception mechanism (Lens E):** under step-by-step execution with a STOP instruction, the
agent's failure script is **"STOP" = halt the run = stop taking actions.** When Step 4 prints `❌ MISMATCH —
STOP` or Step 5 prints `❌ STOP`, the agent's training prior for "STOP" (**Law 4**) is *cease activity and
report* — the diametric opposite of "execute one MORE action (Step 8)." The `finally` discipline lives in
distant prose (L40, L89) — **lost middle (Law 2)** relative to the loud, recent `STOP` token in the probe
output. A human operator holds "but I left the firewall open" in working memory across the panic; a fresh-shell
agent that just read `STOP` does not — its context for "I opened a firewall in Step 1" is many tokens back and
may be in a prior, discarded turn entirely. **Highest-consequence cognitive trap: a PROD Key Vault left
internet-firewall-open because the abort instruction and the cleanup obligation are in tension.**

**Severity: CRITICAL** (security exposure + terraform drift on a PROD KV, indefinitely, with no further probe
to catch it because the run is "stopped").

**Per-step guardrail (BLOCKING):**

> **G5 — STOP is redefined as "STOP-FORWARD-THROUGH-STEP-8".** Every `STOP` / `❌` branch in Steps 1-7 and
> Rollback MUST be rewritten to read: **"STOP the rotation, then IMMEDIATELY run Step 8 (whitelist-off) and
> observe its probe == `0` before ending the run. The run is not abandoned until the firewall is confirmed
> closed."** Add a standing invariant the agent re-asserts at the top of EVERY step after Step 1: "INVARIANT:
> I opened the KV firewall in Step 1. I may not end this session — success OR failure — until
> `length(networkAcls.ipRules[?value=='${MYIP}/32'])` == 0." The agent MUST treat reaching a terminal state
> with that probe != 0 (or unverified) as a FAILED run requiring escalation, not a completed one. The
> idempotent self-probing `./rotate_tls -step whitelist-off -execute` (L89) is the recommended cleanup because
> it "tells you loudly if the firewall is still open" — the agent should prefer it over the raw `az remove`
> precisely because it carries its own verification.

---

## F6 — Probe-interpretation errors: empty/whitespace read as a value; failure output == expected  [MEDIUM-HIGH]

**Evidence:** multiple `-o tsv` probes whose entire signal is the printed value: Step 1 expects `1` (L132),
Step 2 `OK enabled=true` (L155), Step 3 `false` (L179), Step 5 `true` (L214), Step 8 `0` (L280). Step 4 and
Step 5 use shell `[ ... ]` with echoed ✅/❌ (L194, L216).

**Drift / self-deception mechanism (Lens E):**
- **Empty/whitespace as value:** an `-o tsv` query that matches nothing prints an **empty line**. The agent,
  expecting `0` at Step 8 (firewall closed) or `false` at Step 3, can read an *empty* result as "not the bad
  value, therefore fine." Empty `!=` `0` and empty `!=` `false` — but the agent's prior maps "no error, blank
  output" to success. Worst at Step 8: blank (query failed / wrong IP) read as "0 → closed."
- **Failure output == expected output structurally:** Step 2's `case` prints `OK enabled=$E` — if `$OLD_SID`
  is empty (fresh shell, F1) the `case` pattern `*/secrets/"$OBJ"/*` does NOT match → prints
  `BAD OLD_SID — STOP` (safe). But Step 3's expected `false` is ALSO what a *read of the wrong/old version*
  prints, and Step 5's expected `true` is what the OLD version prints too — so the boolean alone doesn't
  distinguish "I enabled NEW" from "I read something already-true." The thumbprint compare (L215-216) is what
  disambiguates — and that compare is exactly the one F1 breaks when `$NEW_THUMB` is empty.

**Severity: MEDIUM-HIGH** (compounds F1; in isolation several fail safe, but the empty-as-success reading at
Step 8 is a real exposure).

**Per-step guardrail:**

> **G6 — Exact-match assertion, empty is always FAIL.** For every `-o tsv` probe the agent MUST assert the
> output **equals** the expected literal, and MUST treat **empty/whitespace as FAIL**, never as "absence of the
> bad value." Concretely wrap value probes: `v=$(az … -o tsv); [ "$v" = "1" ] && echo PASS || echo "FAIL got=[$v]"`
> (the bracketed echo makes empty visible). At Step 8 the agent MUST observe a literal `0` (not blank); a blank
> result means the query itself failed and the firewall state is UNKNOWN → re-probe via full-list
> (`--query "networkAcls.ipRules[].value"`) before believing it is closed. Booleans (`true`/`false`) are
> necessary but NOT sufficient at Steps 3/5 — the agent must also observe the thumbprint equality (which
> requires G1's non-empty `$NEW_THUMB`).

---

## F7 — Rollback trigger criterion is not mechanically unambiguous for step-by-step decision  [MEDIUM]

**Evidence:** "Regression → escalate — if a listener serves a broken/old cert, roll back (before Jul 1); do
not blind-retry" (L42). Step 7 failure says "Still the **old** expiry → … Re-run Step 6, wait a minute,
re-check" (L265) — i.e. *retry*. Rollback's own guard R-4 requires the OLD version still enabled (L294-297).

**Drift / self-deception mechanism (Lens E):** the agent faces a genuine **double bind (Law 6)** at a Step-7
failure: L42 says "do not blind-retry, roll back"; L265 says "re-run Step 6, wait, re-check" (which IS a
retry). With no explicit retry-count boundary, the agent will default to the **cheaper, less-scary** branch
(retry) and can loop — burning the scheduling margin (HARD gate L34: rollback only safe before ~Jun 29). The
criterion "broken/old cert" vs "not-yet-propagated" is not given a mechanical discriminator the agent can
evaluate from a single probe.

**Severity: MEDIUM** (recoverable while margin lasts, but the ambiguity can consume the margin and the agent
won't notice the clock).

**Per-step guardrail:**

> **G7 — Bounded retry with an explicit clock + discriminator.** Make the Step-7 decision a finite machine:
> "If served expiry is OLD: re-run Step 6 and re-handshake. Allow at most **2** such cycles with ~1 min waits.
> If after the 2nd cycle ANY host still serves the OLD expiry → STOP, do NOT retry further, and decide by the
> clock: if today < 2026-06-29 → execute Rollback (after observing R-4: OLD version `enabled=true`, L297);
> if today >= 2026-06-29 → fix-forward only (rollback would restore a soon/already-expired cert, L312). A
> `provisioningState=Failed` or an auto-disabled listener (Resource Health) at any point is an IMMEDIATE STOP
> (not a retry) → Rollback-or-fix-forward by the same clock." This converts a vague "regression → escalate"
> into a step the agent can execute deterministically, and forces it to read the calendar before choosing
> rollback vs fix-forward.

---

## Cross-cutting: the authoring-model vs execution-model mismatch is the generator

**Pattern (not a local patch):** F1, F3, F6 and parts of F5 all descend from ONE generator — **the spec was
authored as a single continuous shell session (variables defined once, "reused" by later steps, L93) but the
agent execution model is one fresh shell per step.** Every shell-variable dependency is a latent false-belief
site under that model. The recurrence class is "any later step that consumes `$VAR` set in an earlier step."
The pattern-level falsifier: *run the Manual mode as literally separate shells with no carried env and observe
which probes still produce success-shaped output on empty vars* — Steps 5, 7, 8, Rollback do. The clean fix is
to (a) externalize state to a sourced `state.env`, or (b) strongly prefer the in-process orchestrator
`rotate_tls.go` for agent execution, where state cannot evaporate between steps. Patching each probe
individually (the `:?` guards in G1) is the safe minimum; the orchestrator is the symmetric fix.

---

## Severity roll-up

| Finding | Surface | Severity | Guardrail | Fails safe by default? |
|---|---|---|---|---|
| F1 | cross-shell var evaporation → empty compares | CRITICAL | G1 (`:?` guards + state.env / prefer orchestrator) | NO (Steps 5/7/8/Rollback dangerous) |
| F2 | control-plane success read as served | HIGH | G2 (locked "done" token; reword L266) | partial (gate exists, agent can skip) |
| F3 | object vs ssl-cert name swap | HIGH | G3 (name-binding assertion) | mostly (NotFound) |
| F4 | single-host / pre-AVD completion | HIGH | G4 (all-four enumerated) | NO (L173 invites skip) |
| F5 | `finally` Step 8 skipped on STOP | CRITICAL | G5 (STOP = stop-forward-through-8 + standing invariant) | NO (PROD KV left open) |
| F6 | empty tsv read as value | MEDIUM-HIGH | G6 (exact-match, empty=FAIL) | partial |
| F7 | rollback trigger ambiguous | MEDIUM | G7 (bounded retry + clock + discriminator) | partial |

## Meta-cognitive audit (self-check, Lens E recursion guard)

- **Projection check:** every finding is grounded in a cited spec line (the probe text and the variable it
  consumes), not in imagined agent feeling. The empathic reconstructions are a communication device; the
  load-bearing claim in each is the *mechanical* one (empty var → success-shaped compare), which is
  observable by running the probe with the var unset. PASS.
- **Confirmation check:** the falsifier for the dominant finding (F1) is concrete — run the steps as separate
  shells and observe which probes pass on empty vars. If they all fail-safe, F1 downgrades. I did not run live
  Azure (no creds / read-only review), so F1's *Azure-side* behaviors (empty `--version` → current version;
  empty `--ip-address` → no-op-or-error) are INFER from az semantics, not RUNTIME-VERIFIED — flagged as the
  one authority-binding gap below.
- **Authority gap (honest):** the claim "az treats empty `--version` as the current version" is TRAINING-DERIVED
  (Rule 8). It should be VERIFY'd against `az keyvault certificate set-attributes --help` / a dev-KV probe
  before relying on it. The guardrail G1 does NOT depend on that claim being true — `:?` guards make an empty
  var abort regardless of how az would interpret it, so the guardrail is safe even if my az-semantics inference
  is wrong.

---

## VERDICT

**CONDITIONAL-GO for manual/agent step-by-step execution — BLOCKING on G1, G2, G5 (and strongly prefer the in-process `rotate_tls.go` orchestrator over Manual mode for agent execution, since it makes F1/F3/F6 structurally impossible).**
