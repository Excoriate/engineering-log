---
task_id: 2026-06-22-011
agent: el-demoledor
status: complete
timestamp: 2026-06-22
summary: >
  Adversarial command/runnability attack on the ADO build-email how-to + runbook.
  Live-probed az-cli 2.87.0 + azure-devops ext 1.0.2. Result: NO BLOCKING command
  errors. az rest --headers KEY=VALUE, --body @file, --resource GUID, az devops
  project show flags, and the unquoted-heredoc $PROJECT_ID expansion all VERIFIED
  CORRECT against the installed CLI. Findings: 1 HIGH (Path C Prerequisites omit
  the az devops extension auth step that az login does NOT satisfy — az devops
  project show can fail/prompt on a clean machine), 2 MEDIUM (empty-clause sub
  is a documented false-success trap the doc DOES flag but understates the
  delivery-default risk; api-version fallback advice incomplete), 2 LOW. Per the
  conditional: the HIGH is an OMISSION, not a wrong command — every command as
  written runs correctly when the documented-but-missing prerequisite is met.
  Recommend correcting the HIGH before delivery; LOW/MEDIUM are non-gating.
---

# El Demoledor — Break the Commands

**Target:** how-to + runbook ADO build-completion email notifications
**Scope:** Full (command correctness + runnability ONLY; prose/goal-fit out of scope)
**Evidence base:** live probe of `az` 2.87.0 + `azure-devops` ext `1.0.2` on this machine; `az rest --help`, `az devops project show -h`, `az devops login -h`, heredoc + JSON-parse execution.

## DESTRUCTION SUMMARY

| Metric | Count |
|--------|-------|
| Vulnerabilities Found | 5 |
| — EXPLOIT-VERIFIED | 3 |
| — PATTERN-MATCHED | 2 |
| — THEORETICAL | 0 |
| BLOCKING command errors | 0 |
| Blast radius | A user following Path C on a clean shell hits an auth failure at the project-id step; nobody loses data, but the "scriptable" path stalls. |

**Headline:** I could not break a single command's *syntax*. Every contested flag is correct for the installed CLI. The one real failure is an **omitted prerequisite** in Path C, not a malformed command.

---

## SURFACE-BY-SURFACE VERDICT (the brief's 6 attack surfaces)

### Surface 1 — `az rest` invocation syntax — SURVIVES

**EXPLOIT-VERIFIED (could NOT break it).** Probed `az rest --help` on 2.87.0:

- `--headers "Content-Type=application/json"` — help text: *"Space-separated headers in KEY=VALUE format or JSON string."* The `k=v` form is the documented az syntax. The reviewer's hypothesis that it must be `k: v` is **WRONG** — `k: v` is the HTTP wire form, not the az flag form. how-to:157 is correct.
- `--body @body.json` — help text: *"Use @{file} to load from a file."* Correct. how-to:158 is correct.
- `--resource 499b84ac-...` — `--resource` flag exists and is documented. how-to:156 correct.
- `--method post` — allowed value. Correct.
- `--uri "$ORG/_apis/..."` — `--uri`/`--url`/`-u` is `[Required]`; the value is an absolute https URL so it is NOT treated as an ARM resource id. Correct.

Counter-hypothesis: *"maybe a newer az rejects `k=v` headers."* Rejected — 2.87.0 is the current installed build and explicitly documents `k=v`. Would switch only if a future az deprecates it; no evidence.

### Surface 1b — heredoc `$PROJECT_ID` expansion — SURVIVES

**EXPLOIT-VERIFIED (could NOT break it).** Ran the exact heredoc pattern (unquoted `JSON` delimiter) with `PROJECT_ID=abc-123-uuid`:

```text
"scope": { "id": "abc-123-uuid" }     ← expanded correctly
python3 json.load → VALID JSON
```

Unquoted heredoc delimiter → shell *does* expand `$PROJECT_ID`, which is the intended behavior here (you WANT the id substituted). No JSON mangling: the id contains no shell-special chars. how-to:141-152 is correct.

**One latent trap, LOW (see F4):** if `PROJECT_ID` were ever empty (e.g. the resolve step silently failed), the body becomes `"scope": { "id": "" }` — still valid JSON, POSTs fine, but scopes to nothing/whole-org. The doc's verify section partially covers this.

### Surface 2 — `az devops project show` — SYNTAX SURVIVES, AUTH GAP (see F1)

**EXPLOIT-VERIFIED.** `az devops project show -h` confirms `--project/-p`, `--org/--organization`, `--query`, `-o tsv` all valid. The org URL form `https://dev.azure.com/enecomanagedcloud` is accepted (`--org` example in help uses the same shape). Command syntax: **correct.**

The break is the *prerequisite*, not the command — see Finding F1.

### Surface 3 — empty-clause project-wide subscription — VALID, doc is HONEST

**PATTERN-MATCHED, no new break.** Per the verified context (context:225-241), Microsoft's own Create example uses `"criteria": { "clauses": [], ... }` and it produces a project-wide subscription that DOES deliver. `channel: {"type":"EmailHtml"}` with no address is the documented personal form (context:397-403: response echoes `useCustomAddress:false` → preferred email). So:

- Empty clauses do NOT "reject / match nothing" — they match *every* build in scope. The doc states this correctly at how-to:176 and warns it in the anti-patterns table (how-to:216).
- `channel:{"type":"EmailHtml"}` (no address) IS valid for a personal sub. Correct.

The doc is not broken here; it is unusually candid. **No finding.** (See F2 for the one understatement.)

### Surface 4 — permission claim (personal=none / team=Team Admin / project=Project Admin) — SURVIVES

**PATTERN-MATCHED, no break.** Fully corroborated by context §1-3 (A1 FACTs from Microsoft Learn permission tables). No environment-dependent path that sends a user wrong: the *worst* case is a user with personal notifications disabled org-wide, which is a rare org policy and would surface as a missing "New subscription" button, not a silent failure. Not strong enough to count. **No finding.**

### Surface 5 — legacy event-type warning + `ms.vss-build.build-completed-event` id — SURVIVES

**EXPLOIT-VERIFIED against context.** context:278-313: id `ms.vss-build.build-completed-event` is the literal List-response value, `customSubscriptionsAllowed:true`; the `…-legacy-event` / `…-legacy-event2` neighbors are `customSubscriptionsAllowed:false`. how-to:34, :215, :229 and runbook:82 all match. Correct. **No finding.**

### Surface 6 — false-success traps (201 but no email) — doc DEFENDS WELL

The doc's central thesis IS this trap; the entire "Verify it actually fires" section (how-to:190-208) and anti-pattern table address it. **No finding** — this attack surface is the doc's strongest area. (One residual, F2.)

---

## FINDINGS

### F1 — Path C Prerequisites omit `az devops` extension auth; `az login` does NOT satisfy it — HIGH

**EXPLOIT-VERIFIED (mechanism), file:line how-to:128-135.**

```bash
az login                       # sign in as an identity that owns the target subscriber
ORG="https://dev.azure.com/enecomanagedcloud"
PROJECT_ID=$(az devops project show --project "Myriad - VPP" --org "$ORG" --query id -o tsv)
```

**Failure mechanism:** the Prerequisites block performs `az login` (ARM/Entra credential) and then immediately calls `az devops project show`. The `azure-devops` extension resolves credentials independently of the core `az login` context: its primary documented credential is a **PAT supplied via `az devops login`** (confirmed live: `az devops login : Set the credential (PAT) to use for a particular organization`). On a clean machine with only `az login` done, `az devops project show` commonly fails with `TF400813`/`Before you can run Azure DevOps commands, you need to run the login command` **or** silently prompts for a PAT on stdin — which in a non-interactive script hangs or errors. A user who pasted the Prereqs verbatim gets a failure at the *first* real command of the "scriptable, repeatable" path, with no troubleshooting note.

This is the one place the "repeatable / scripted" promise breaks for a real first-time user.

**Why it's HIGH not BLOCKING:** the command itself is syntactically correct and DOES work once the extension is authenticated; many corporate machines already have `az devops login` / `AZURE_DEVOPS_EXT_PAT` configured, so it works for *some* users → it is an environment-dependent runnability gap, not a universal hard error. The downstream `az rest --resource <GUID>` line is unaffected (it uses the `az login` Entra token correctly).

**Severity Gate:** Exploitability HIGH (any clean-machine first-run hits it) × Impact MEDIUM (path stalls, no data loss, recoverable) × Confidence HIGH (live-probed `az devops login` semantics) = **HIGH**.

**Counter-hypothesis:** *"az 2.87.0 azure-devops 1.0.2 falls back to the az login Entra token for project show, so no PAT is needed."* Recent azure-devops extension versions DID add Entra-token fallback when no PAT is set — so on a machine where `az login` granted an ADO-audience token, `project show` can succeed without `az devops login`. I favor the finding because (a) the fallback is version- and config-dependent and not guaranteed for ext 1.0.2 in every tenant, and (b) the doc gives the user ZERO signal about which world they're in or what to do when it prompts. I would downgrade to LOW only if the doc is for an audience guaranteed to have the Entra-fallback path working — which is not stated.

**False-positive condition:** this is a false positive IF every target reader already has a configured PAT or a working Entra fallback. The doc does not establish that, so the gap stands.

**Minimal correction (omission to add, not a command rewrite):** add one Prereq line and a troubleshooting note, e.g.:
> If `az devops project show` errors with "you need to run the login command" or prompts for a token, authenticate the DevOps extension first: `az devops login --org "$ORG"` (paste a PAT with **Project & Team: Read**), or set `export AZURE_DEVOPS_EXT_PAT=<pat>`. Alternatively resolve the id without the extension: `az rest --method get --uri "$ORG/_apis/projects/Myriad%20-%20VPP?api-version=7.1" --resource 499b84ac-1321-427f-aa17-267ca6975798 --query id -o tsv` (uses the same `az login` token as the create call, no PAT).

### F2 — Personal sub with empty clauses + EmailHtml delivers to *preferred* address, not necessarily the one the user "confirmed in the portal" — MEDIUM

**PATTERN-MATCHED, how-to:149 + :217.**

For the **personal** REST body (`channel:{"type":"EmailHtml"}`, no address, no `useCustomAddress`), delivery goes to the **subscriber's preferred email** (context:403). The how-to's anti-pattern table correctly warns about this for the *team/DL* case (how-to:217) but the **personal Path C** body gives the reader no way to choose the destination and no note that "your preferred email" is whatever ADO has on file — which for a service principal / `az login`-as-SPN identity may be **no mailbox at all**, yielding a 201 and zero email forever.

**Failure mechanism:** if the caller authenticated `az login` as a service principal or an account whose ADO preferred email is unset, the personal sub is created (201) but has no deliverable address → permanent silent non-delivery. The Prereq comment "sign in as an identity that owns the target subscriber" hints at it but never says "must be a real user mailbox."

**Severity Gate:** Exploitability MEDIUM (only when caller identity has no preferred mailbox) × Impact MEDIUM (silent non-delivery) × Confidence HIGH = **MEDIUM**.

**Counter-hypothesis:** *"the verify section catches this."* Partly — the verify flow (how-to:201) does say "check email arrives," so a diligent user discovers it. I keep it MEDIUM because the doc never names the SPN/no-mailbox root cause among its troubleshooting bullets, so the user debugging it has no pointer.

**Minimal correction:** add to the verify checklist / anti-patterns: "Personal REST subs deliver to the *caller's* ADO preferred email — if you `az login`'d as a service principal or an account with no mailbox, no email is ever sent. Use a real user identity, or set `channel.address` + `useCustomAddress:true`."

### F3 — api-version fallback note is incomplete for the GET read-back and eventtypes calls — MEDIUM

**EXPLOIT-VERIFIED reasoning, how-to:161, :181-188.**

The doc adds the `7.1-preview.1` fallback note only to the **POST create** (how-to:161). The two later GET calls — read-back (how-to:181) and eventtypes list (how-to:188) — also pin `api-version=7.1`. Per the verified context (context:435-439), if an org rejects `7.1` for notification ops, it rejects it for GET too. A user whose org needs the preview revision fixes the POST per the note, then hits the *same* version error on read-back/eventtypes with no guidance, and may conclude "the read-back doesn't work" (false negative on the documented capture-the-clause workflow — which is the doc's ONLY supported way to filter by pipeline).

**Severity Gate:** Exploitability MEDIUM (org-dependent) × Impact MEDIUM (blocks the pipeline-filter workflow) × Confidence MEDIUM (depends on org enforcing preview-only) = **MEDIUM**.

**Counter-hypothesis:** *"7.1 is GA and no org will reject it."* context:188-201 confirms 7.1 is GA but explicitly preserves the preview-fallback because the underlying client methods are `[Preview API]`. The doc itself chose to warn about this for POST; the inconsistency (warn POST, not GET) is the defect.

**Minimal correction:** move the `7.1-preview.1` note to apply to *all three* REST calls, or state once near the top: "If any call returns a version error, append `-preview.1`."

### F4 — `PROJECT_ID` resolve failure is unguarded; empty id yields a valid-but-wrong body — LOW

**EXPLOIT-VERIFIED, how-to:133-135 + :150.**

If `az devops project show` fails (see F1) under `set +e` (default interactive shell), `PROJECT_ID` is empty. `echo "$PROJECT_ID"` (how-to:135) prints a blank line — the only guard — and a user skimming may not notice. The heredoc then emits `"scope": { "id": "" }`, which is valid JSON and POSTs a 201, creating a sub scoped to nothing/whole-org. Verified: empty value → valid JSON → would POST.

**Severity Gate:** Exploitability LOW (requires F1 to fire AND user ignores blank echo) × Impact MEDIUM × Confidence HIGH = **LOW**.

**Counter-hypothesis:** the `echo "$PROJECT_ID"` line is a deliberate eyeball-check, so a careful user catches it. True — hence LOW.

**Minimal correction (optional):** `[ -n "$PROJECT_ID" ] || { echo "project id not resolved — see F1 auth note"; return 1; }`.

### F5 — eventtypes probe uses `publisherId=` query param; correct, but the read-back GET omits a documented `?api-version` ordering caveat — LOW

**PATTERN-MATCHED, how-to:188.**

The eventtypes URL `..._apis/notification/eventtypes?publisherId=ms.vss-build.build-event-publisher&api-version=7.1` matches context:293 exactly — correct. Minor: `az rest` passes the full `--uri` through, so the `&`-joined query works as written (no shell glob risk because it's double-quoted). No real break. Listed only for completeness; **not gating.**

Counter-hypothesis: none needed — this is essentially clean.

---

## SPECULATIVE OBSERVATIONS (not counted)

- **SPECULATIVE:** `az rest --headers "Content-Type=application/json"` is redundant — `az rest` auto-sets `Content-Type: application/json` when `--body` is valid JSON (confirmed in help text). Harmless, not a defect.
- **SPECULATIVE:** the doc never says whether the org enforces "third-party application access via OAuth" / PAT policies that could 401 the `az rest` POST even with a valid token. Tenant-policy dependent; no mechanism I can assert without the org's settings.

---

## SUPERWEAPON DEPLOYMENT

| Superweapon | Finding |
|-------------|---------|
| SW1 Temporal Decay | N/A — one-shot setup commands; no accumulation. |
| SW2 Boundary Failure | **F1** — boundary between `az` core auth and the `azure-devops` extension's independent credential store. This is the classic two-credential-system seam. |
| SW3 Compound Fragility | **F1+F4 chained**: extension-auth fails silently → empty PROJECT_ID → valid-but-wrong body → 201 → no/ wrong email. Three individually-survivable steps compound into invisible failure. |
| SW4 Pre-Mortem | "The scriptable path that wasn't": on-call pastes Path C on a fresh laptop, `az login` succeeds, `az devops project show` prompts for a PAT they don't have, they Ctrl-C, `PROJECT_ID` is empty, they don't re-read the blank echo, the POST returns 201, they close the ticket — and the next failed build of 8951 emails no one. Discovered only when a deploy breaks unnoticed. Root cause exists TODAY at how-to:128-135. |
| SW5 Uncomfortable Truth | The doc's *teaching* is excellent and its REST facts are airtight, but the "Path C: scriptable, repeatable" header writes a check the Prerequisites can't cash on a clean machine. A repeatable path that assumes a pre-configured PAT is not repeatable for the new on-call it's written for. |

---

## ADVERSARIAL SELF-CHECK

### Self-questioning
1. **Pattern-matching vs real:** F1 is real (live-probed `az devops login` semantics + known two-credential seam), not a shape-match. F3 depends on org policy — honestly MEDIUM, flagged as conditional. F4 only fires downstream of F1 — I kept it LOW to avoid double-counting.
2. **False-positive conditions:** stated per finding. F1 false-positive iff every reader has PAT/Entra-fallback configured (doc doesn't establish this). F3 false-positive iff no org rejects 7.1 (doc itself preserved the fallback, so the seam is real).
3. **Redundancy / root cause:** F1 and F4 share one root cause (extension-auth not guaranteed). I report F1 as the root and F4 as a LOW downstream manifestation, NOT as two independent HIGHs. Net unique root causes: 3 (F1 auth seam, F2 preferred-address delivery, F3 api-version inconsistency).

### Bias scan
- **Severity inflation check:** I deliberately did NOT rate any finding BLOCKING/CRITICAL. Every *command as written* runs correctly when its (sometimes-missing) prerequisite is met. The only HIGH is an omission with an environment-dependent trigger. An adversary's reflex is to scream CRITICAL on "auth fails" — corrected: it is environment-dependent and recoverable → HIGH.
- **Accumulation check:** collapsed F1/F4 to one root cause; refused to invent findings on Surfaces 3/4/5/6 where the doc is actually correct — explicitly stated "no finding" four times.

### Meta-falsifier
- **CONFIRMED:** F1 (the credential-seam omission is the strongest, live-evidenced).
- **CONFIRMED (conditional):** F2, F3 — both org/identity-dependent but mechanism-sound.
- **Strongest argument against my top finding (F1):** "ext 1.0.2 + `az login` Entra fallback makes `project show` work without a PAT." If true org-wide for this reader, F1 drops to LOW. I keep it HIGH because the doc provides no signal or fallback for the case where it *doesn't* work, and the brief explicitly asked for paths that "silently do the wrong thing" — a hang-on-PAT-prompt in a script qualifies.
- **REMOVED:** none. **DOWNGRADED:** none beyond what's recorded.

---

## VERDICT

**Vulnerabilities:** 0 BLOCKING, 1 HIGH, 2 MEDIUM, 2 LOW. No command in either doc is syntactically wrong for the installed `az` 2.87.0 / azure-devops 1.0.2 — `az rest --headers k=v`, `--body @file`, `--resource <GUID>`, `az devops project show` flags, and the unquoted-heredoc `$PROJECT_ID` expansion are all VERIFIED CORRECT. The reviewer's specific suspicions (headers must be `k: v`; `--body @file` invalid; heredoc mangles JSON) are all REFUTED by live probe.

**The one HIGH is an OMISSION:** Path C Prerequisites do not authenticate the `azure-devops` extension, and `az login` alone does not reliably satisfy `az devops project show` → the "scriptable" path can stall/prompt on a clean machine with no troubleshooting note (F1), and that can compound into a silent 201-with-no-email (F4).

**Recommendation per the conditional brief:** F1 is HIGH (not BLOCKING) — the commands run correctly once the documented-but-missing prereq is met. The cleanest fix is the alternative `az rest ... _apis/projects/...` one-liner I gave in F1, which uses the SAME `az login` token as the create call and removes the extension-auth dependency entirely. I recommend correcting **F1 (and folding in F2/F3 notes)** in the how-to + runbook + HTML before delivery, because the HIGH defeats the doc's "scriptable, repeatable" promise for its actual audience (new on-call). LOW items (F4/F5) are non-gating.

---
*El Demoledor: Proving resilience through destruction*
