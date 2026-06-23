---
title: "El Demoledor break receipt — RCA + how-to-fix as on-call artifacts"
type: research
status: complete
task_id: 2026-06-22-006
agent: el-demoledor
summary: >-
  Adversarial break of rca.md + how-to-fix.md as artifacts a pressured on-call would follow. 9 findings:
  1 BLOCKING decision-tree/command hole (Branch B discriminator probe cannot reproduce the access-key
  HMAC failure it routes on), 1 BLOCKING cross-section incoherence (the "set FFs from AVD" symptom maps
  to the Entra write path but Branch B fires on the access-key read path — same complaint, two arrows,
  no rule disambiguates them at the point of action), 1 HIGH inherited-claim/decision-tree hole (a 401
  on the FF-apply pipeline SP lands in NO branch — every 401 branch is keyed to an interactive user or
  the FBE pods), plus 6 MEDIUM/LOW command, coherence, and unguarded-step findings. The destructive
  steps (key refresh, role grant) ARE gated; one secret-leak vector and one "read" that needs a write
  role are the residual command hazards.
timestamp: 2026-06-22T16:05:00+02:00
---

# El Demoledor — breaking the two documents as on-call artifacts

WIN CONDITION (mine alone): find where an on-call who *follows these documents under pressure* is led
into harm, confusion, or a dead end. Not hypothesis re-ranking (Socrates). Not goal-fidelity.

All findings are INFER until the coordinator source-verifies. Live `az` CLI verification was
**blocked** (`mc-avd-execution-boundary` + MCP doc tools unavailable in this dispatch); command-shape
findings are graded PATTERN-MATCHED or THEORETICAL accordingly and the blocked verification is named.

Evidence base read in full: `rca.md`, `how-to-fix.md`, and all five context sidecars
(`fbe-ff-mechanism.md`, `msdocs-appconfig-auth.md`, `slack-harvest.md`, `vault-appconfig-knowledge.md`,
`diagnosis-synthesis.md` header).

---

## SUMMARY

| Metric | Count |
|--------|-------|
| Findings | 9 |
| — BLOCKING | 2 (V1, V2) |
| — HIGH | 1 (V3) |
| — MEDIUM | 4 (V4, V5, V6, V7) |
| — LOW | 2 (V8, V9) |
| Evidence: EXPLOIT-VERIFIED (traced in-doc) | 5 |
| Evidence: PATTERN-MATCHED | 3 |
| Evidence: THEORETICAL | 1 |
| Destructive steps WITHOUT a HALT gate | 0 (the dangerous ones are gated — see V7 for the residual) |

The decision tree's *safety gating* is genuinely good — the one-way doors (disable keys, open public
access, grant Data Owner) all carry HALT gates. The breaks are NOT in the gates. They are in the
**routing**: the discriminator probe the whole tree hangs on cannot, in two cases, produce the verdict
the tree expects, and one real failing-call shape (pipeline SP 401) falls through every branch.

---

## V1 — BLOCKING — The Branch-B discriminator probe CANNOT reproduce the failure it routes on

**Evidence grade: EXPLOIT-VERIFIED (traced across rca.md L11 Step 2, how-to-fix Branch A verify, Branch B trigger).**

**What I saw.** The master discriminator (rca.md L11 Step 2, line 487; and the *only* concrete
reproduce-the-call command, how-to-fix Branch A verify, line 233) is:

```bash
az appconfig kv list --name vpp-applicationconfig-d --auth-mode login --top 1 ...
```

`--auth-mode login` forces **Microsoft Entra (token) authentication** (fbe-ff-mechanism Q1; msdocs Q1
"the other data-plane auth mode"). But **Branch B** (how-to-fix lines 242-283) is defined as the
**access-key / HMAC** read path failing — "the failing caller is a *service* reading flags (the FBE
pods, via a connection string)" with body `HMAC "Invalid Credential"`.

**How it breaks.** The on-call is told (decision ladder Step 1, lines 183-190; L12 row 1) to "capture
the EXACT failing call" and route on its status+body. The single command the docs hand them to *do*
that capture is `--auth-mode login`. An Entra-mode call **cannot emit an HMAC `Invalid Credential`
body** — that body only exists on the connection-string code path the FBE pods use (msdocs Q1/Q2 HMAC
error table). So an on-call who runs the provided command and sees a clean 200 (their AVD token is
fine) will conclude "auth works, not Branch B" — while the *actual* failing caller (the FBE pod's
access key) is never exercised by that command at all. The probe and the branch test **different
credentials on different code paths**. Following the doc literally produces a false "it's fine."

This is the central artifact failure: the document's TL;DR ("read the status before you act") presumes
one reproducible call, but the two 401 branches (A = your Entra token, B = the pod's access key) are
reachable only by **two different calls**, and only one is given a command.

**If accepted → which exact step/line changes.** L11 Step 2 (lines 484-489) and how-to-fix Branch B
(lines 254-260) must add a distinct access-key probe (e.g. a connection-string-mode call or reading the
FBE pod's own startup error / SDK HTTP response) and the ladder must state explicitly that
`--auth-mode login` tests the Entra arm only — it does not and cannot reproduce a Branch-B HMAC failure.

**Counter-hypothesis.** *Maybe the doc intends the on-call to capture the FBE pod's error separately
(L11 Step 6 mentions "for a service fetch, capture the SDK's HTTP response").* I favor the break
because (a) Step 6 is buried five steps after the "master discriminator," (b) the ladder's Step 1 and
the TL;DR present the single status-capture as THE deciding move with the `--auth-mode login` command
as its instrument, and (c) Branch A's verify command is literally the same `--auth-mode login` call —
so a reader treats it as the canonical "the failing call." The disambiguation is not at the point of
action. I would switch IF the ladder named the access-key probe at Step 1 next to the Entra one.

**Classification: RESOLVE** (requires an added probe + a one-line caveat; not rebuttable — the command
as written cannot emit the HMAC body the branch keys on).

---

## V2 — BLOCKING — "Set FFs from AVD" symptom is two different arrows; no rule disambiguates at action time

**Evidence grade: EXPLOIT-VERIFIED (traced across the intake text, fbe-ff-mechanism headline, rca L4, how-to-fix Branches A/B).**

**What I saw.** Duncan's verbatim symptom (slack-harvest §1a, line 48): *"the calls for app configuration
are failing. So the FFs **cannot be set** properly as I am getting 401's. I can see the FFs set properly
in the app config."* fbe-ff-mechanism is explicit that **"set FFs"** is the **WRITE path = ADO Terraform
pipeline using the SP's Entra token** (headline lines 27-43; Q5), NOT the FBE pod read path. Yet
how-to-fix routes the *interactive* 401 to **Branch A** (your `az login` token) and the *service*
401 to **Branch B** (FBE pod access key). **Neither branch is the pipeline SP write path** the word
"set" actually denotes — that lives only inside Branch C (403) and the anti-pattern table.

**How it breaks.** A returning, rusty engineer (the explicit persona, rca L1 line 192-193) reads "I am
getting 401's setting FFs," opens how-to-fix, and must self-classify into A (my token), B (pod key), C
(role), D/E/F. But "setting a feature flag" can mean: (i) the engineer running `az appconfig feature
set` interactively from AVD (→ Branch A territory, Entra), (ii) triggering the ADO pipeline whose SP
sets the flag (→ a 401 here is the SP's token, which has NO branch — see V3), or (iii) the FBE pod
failing to *read* the flag the engineer thinks they "set" (→ Branch B, access key). The document never
makes the on-call ask "which of these three 'set' operations are you doing?" before routing. Under
pressure they will pick the first branch whose words match ("401" + "AVD" → Branch A), re-`az login`,
see their own token is fine, and be stranded — the real failing arrow was never identified.

**If accepted → which exact step/line changes.** Decision ladder Step 0/1 (how-to-fix lines 178-190)
needs a pre-question: "WHICH operation is failing — your interactive `az`/portal action, the FF-apply
*pipeline*, or the running *FBE pod*?" — because that selects the credential (your token / SP token /
access key) and therefore the branch. Today the ladder routes on status code alone, which is necessary
but not sufficient when the same status from three callers means three different fixes.

**Counter-hypothesis.** *The status+body is claimed to be sufficient: 401-Bearer→A, 401-HMAC→B,
403→C.* I favor the break because the status code does NOT distinguish caller (i) from caller (ii):
both are Entra-token 401s with a `Bearer invalid_token` body, but (i)'s fix is re-`az login` (Branch A)
and (ii)'s fix is repairing the **pipeline SP's** credential — a completely different identity the
on-call cannot fix by re-authenticating themselves. The body alone cannot tell you *whose* token
failed. I would switch IF App Config's 401 body carried the principal identity — it does not (msdocs
Q2 error table shows no principal field).

**Classification: RESOLVE** (add the caller-identity pre-question; the status-only funnel is
incomplete for the "set" verb that the actual ticket uses).

---

## V3 — HIGH — A 401 on the FF-apply pipeline SP lands in NO branch (decision-tree hole)

**Evidence grade: EXPLOIT-VERIFIED (traced across rca L6 line 353, how-to-fix Branches A–F).**

**What I saw.** rca L6 (lines 350-354) states a real failing-call shape verbatim: *"If the SP's
token/secret is invalid or wrong-tenant, it fails authentication — a 401."* fbe-ff-mechanism Q5 (lines
237-241) confirms the pipeline SP `eneco-vpp-mc-dev` is the most-probable actual writer. Now walk the
how-to-fix ladder (lines 183-190) for **a 401 returned to the pipeline SP**:

- Branch A: "the failing call is **yours** (interactive, from AVD)" — NO, it is the pipeline agent's.
- Branch B: "the failing caller is a **service reading flags (the FBE pods, via a connection string)**"
  and HMAC body — NO, the pipeline uses an Entra token, not a connection string.
- Branch C/D: 403, not 401 — NO.
- Branch E: portal browser — NO. Branch F: no error — NO.

**How it breaks.** The single most evidence-supported actual cause (pipeline SP Entra 401, named in the
RCA's own L6) **falls through every branch of the companion fix guide**. An on-call who correctly
captures "401 Bearer invalid_token, but it's the pipeline run that failed, not me" has nowhere to land.
Branch A will tempt them (401 + Bearer) and instruct `az logout && az login` **as themselves** — which
does nothing for the pipeline SP's expired secret, and worse, the verify step (`az appconfig kv list
--auth-mode login`) will return 200 under *their* identity, falsely signaling "fixed." Dead end with a
false-positive confirmation.

**If accepted → which exact step/line changes.** how-to-fix needs a Branch A-pipeline (or a split of
Branch A into "your interactive token" vs "the pipeline SP token") whose fix is "rotate/refresh the
`eneco-vpp-mc-dev` service-connection secret in ADO; check SP tenant," NOT a personal `az login`. The
RCA L8 table (lines 390-397) has the same gap: its "401 invalid_token → re-az login" row silently
assumes the interactive identity.

**Counter-hypothesis.** *Branch A's heading could be read to cover any Entra 401.* I favor the break
because Branch A's body explicitly scopes itself to "the failing call is **yours** (interactive, from
AVD)" and its fix is a personal `az logout/az login` — a pipeline SP cannot be fixed that way, and the
RCA itself separates the two identities (L6). I would switch IF Branch A's fix step handled the SP case
— it does not mention the service connection at all.

**Classification: RESOLVE.**

---

## V4 — MEDIUM — Branch B "stale key" fix reads the Primary connection string, but C5/dev.tfvars says the write key is the provisioned one

**Evidence grade: PATTERN-MATCHED (cross-doc; live store not probed — AVD-gated).**

**What I saw.** how-to-fix Branch B stale-key fix (lines 270-272):

```bash
CS=$(az appconfig credential list ... --query "[?name=='Primary'].connectionString | [0]" -o tsv)
az keyvault secret set --vault-name <dev-mc-kv> --name connectionstrings-app-config --value "$CS" ...
```

But fbe-ff-mechanism Q1 (lines 88-91) says the KV secret is provisioned from
`module.appconfig.app_configuration_primary_**write**_key_connection_string` (`appconfig-mc-lz.tf:36-44`).
App Configuration credentials come in **read-only and read-write** pairs per Primary/Secondary; `az
appconfig credential list` returns entries whose `name` values are `Primary`, `Secondary`, `Primary
Read Only`, `Secondary Read Only`. The filter `name=='Primary'` selects the **read-write** Primary — by
luck consistent with the provisioned *write* key — but the doc never states which key kind it is
restoring, and if the consumer was provisioned from a read-only key the refreshed secret would silently
grant the pod *write* capability (over-permission) or, conversely, a name mismatch returns empty.

**How it breaks.** `--query "[?name=='Primary'].connectionString | [0]"` returns **empty string** if
the live store's credential entry is labelled differently (e.g. some CLI/API versions surface
`Primary` vs `Primary Read Only` only) — and `az keyvault secret set --value ""` would then write an
**empty connection string** into `connectionstrings-app-config`, breaking every reader. No guard
checks `$CS` is non-empty before the `secret set`.

**If accepted → which exact step/line changes.** Branch B (lines 269-274) must (a) name the exact key
kind to restore (match the IaC: the *write* key per C5), and (b) add a non-empty guard:
`[ -n "$CS" ] || { echo "no Primary connection string returned"; exit 1; }` before `az keyvault secret
set`.

**Counter-hypothesis.** *`name=='Primary'` is stable and always returns the read-write Primary.* I
favor the break at MEDIUM because the empty-result-then-overwrite path is a real footgun and the doc
provides no guard; live CLI output shape is AVD-gated so I cannot confirm the exact `name` strings this
session. I would switch to LOW if a live `az appconfig credential list` confirmed `Primary` is always
present and non-empty. **Blocked verification named.**

**Classification: DEFER** (risk: empty-overwrite of a shared KV secret; revisit when the live
`credential list` output is captured from AVD).

---

## V5 — MEDIUM — Branch C "read" probe and the role it implies are misaligned; the read can itself 403

**Evidence grade: PATTERN-MATCHED.**

**What I saw.** Branch C diagnose (how-to-fix lines 300-303) and rca L11 Step 5 (lines 526-528):

```bash
APPCFG_ID=$(az appconfig show ... --query id -o tsv)
az role assignment list --scope "$APPCFG_ID" --include-inherited --query "...App Configuration Data..."
```

`az role assignment list` is a **control-plane (ARM) read** — it needs `Microsoft.Authorization/
roleAssignments/read` (e.g. Reader/User Access Administrator), NOT an App Configuration Data role. The
doc nowhere tells the on-call this is a *different* permission from the data role they are diagnosing.

**How it breaks.** A returning engineer who lacks ARM Reader on the resource group (plausible — Duncan
has a *pending* dev-mc access gap, slack-harvest §2c / rca L8 line 401-403) runs Step 5, gets an
**authorization error on the role-assignment list itself**, and has no instruction for that case. They
may misread an empty/failed `role assignment list` as "no Data role assigned → Branch C confirmed" when
in fact the command just couldn't read assignments. False confirmation of H3.

**If accepted → which exact step/line changes.** rca L11 Step 5 (lines 517-528) and how-to-fix Branch C
diagnose (lines 298-303) need a note: this is a control-plane read requiring ARM Reader; an error here
is a *tooling-permission* problem, not evidence of H3; distinguish "empty result" (no Data role) from
"command errored" (cannot read assignments).

**Counter-hypothesis.** *On-call engineers always have ARM Reader on dev-mc.* I favor the break because
the evidence explicitly records Duncan's pending dev-mc access gap (slack-harvest §2c line 177-181), so
"the diagnoser lacks read on the scope" is a live, documented possibility for this very ticket. I would
switch IF the access model guaranteed ARM Reader for all who reach the ladder.

**Classification: DEFER** (revisit with live confirmation of the on-call's ARM permissions on dev-mc).

---

## V6 — MEDIUM — Branch E (portal-browser 401) is an A1 vault fact in the fix guide but is NOT in the RCA hypothesis set or L8 table

**Evidence grade: EXPLOIT-VERIFIED (cross-section incoherence, traced).**

**What I saw.** how-to-fix Branch E (lines 353-365) is a full branch: "the portal blade itself returns
401 in the browser … Edge mishandles the private-endpoint flow … use Chrome/Firefox." Its evidence is
vault-appconfig-knowledge §2a (line 410, A1). But the **RCA** hypothesis set is **H1/H2/H3 only**
(rca exec summary lines 80-87; L8 table lines 390-397 has rows for 401-token, 401-HMAC, 403-RBAC,
403-network, timeout, flag-absent — **no portal-browser row**). The L4 decision tree (lines 292-300)
also has no browser-401 leaf.

**How it breaks.** The two documents disagree on the hypothesis set. The RCA's L12 one-page playbook
(lines 559-567) — the "5-minute triage card for next shift," the thing an on-call actually grabs under
pressure — has **no browser-401 step**. An on-call working from L12 will never try the cheapest,
most-reversible exclusion (switch browser) that the companion guide flags as "a two-minute exclusion
worth running early." The single highest-ROI, zero-risk first move is present in one artifact and
absent from the triage card of the other. Worse: Duncan's symptom ("the calls for app configuration are
failing … I can see the FFs in the app config") is *consistent with a portal-blade interaction* — Branch
E may be the actual cause, and the RCA's ranked set omits it entirely.

**If accepted → which exact step/line changes.** rca L8 table (lines 390-397), the L4 decision tree
(lines 292-300), and the L12 card (lines 559-567) must add the portal-browser-401 case (Branch E) so
the two artifacts present the same hypothesis universe. As-is, whichever document the on-call opens
first determines whether they even consider it.

**Counter-hypothesis.** *The RCA scopes itself to programmatic 401s and the portal case is a fix-guide
extra.* I favor the break because the RCA's exec summary and L12 explicitly frame "I can see the flags
in the portal" as the *control-plane-vs-data-plane* lesson — yet a portal blade *throwing 401* is a
distinct fourth case that the RCA's own framing would mis-explain as "control plane works." The
documents must agree on the set. I would switch IF the RCA explicitly stated "portal-browser 401 is out
of scope, see how-to-fix Branch E" — it does not cross-reference it at all.

**Classification: RESOLVE** (cross-section coherence; add the case to the RCA's set + L12 card).

---

## V7 — MEDIUM — Branch B leaks a live App Configuration connection string into shell history / process args

**Evidence grade: PATTERN-MATCHED (security; the destructive key ops ARE gated, this is the residual).**

**What I saw.** Branch B (how-to-fix lines 270-272) assigns a **live read-write connection string**
(a secret) into a shell variable via command substitution and passes it as `--value "$CS"` on the
`az keyvault secret set` command line. The HALT box (lines 276-279) correctly warns "Never echo the
connection string into Slack/logs," but the command as written places the secret in:
(a) the shell's process argument list (visible to `ps`/other users on a shared AVD host), and
(b) shell history if history is on.

**How it breaks.** AVD session hosts are *shared, recreated* infrastructure (slack-harvest §2c line 193,
Fabrizio: "these AVD are recreated time to time"; multiple engineers use them). A connection string
left in `~/.bash_history` or visible in `ps -ef` on a shared AVD host is a credential disclosure to the
next user of that host. The HALT box addresses Slack/logs but not the local shell surface its own
command creates.

**If accepted → which exact step/line changes.** Branch B's command block (lines 270-272) should pipe
the secret via stdin / `--file` rather than `--value "$CS"` on argv, and the HALT note (line 279) should
extend "never echo … into Slack/logs" to "and do not leave it in shell history / `ps` on a shared AVD
host." This is reporting the residual hazard; I am NOT prescribing the exact safe rewrite.

**Counter-hypothesis.** *The HALT note already says "never echo the connection string."* I favor the
break because "echo into Slack/logs" does not cover argv/`ps`/history, which the command itself
introduces on a documented-shared host. I would switch to LOW if AVD sessions were single-user with
history disabled — slack-harvest §2c says they are shared and recreated, so they are not.

**Classification: DEFER** (security residual on shared AVD; revisit with the AVD host-isolation model).

---

## V8 — LOW — Branch F precedent says "FBE Kidu," RCA L6 says the same precedent, but the live ticket is "Jupiter" — slot-name carryover risk

**Evidence grade: EXPLOIT-VERIFIED (cross-reference).**

**What I saw.** how-to-fix Branch F (lines 374-379) cites the Sep-2025 unapproved-pipeline precedent as
"FBE **Kidu**" (slack-harvest §3 line 195 confirms: Kidu, A1). rca L6 (line 354) and L8 (line 397) cite
the same Sep-2025 precedent but do not name the slot. The live ticket is **Jupiter**. Branch F's fix
(line 379) correctly says "check the App Configuration pipeline's approval gate **for the Jupiter
prefix**."

**How it breaks (mild).** The wording is correct, but an on-call skimming under pressure could conflate
"Kidu" (the precedent slot) with the action target and check the wrong slot's pipeline. Low severity —
the action line does say "Jupiter prefix" — but the precedent noun and the action noun differ within
two lines, which is exactly the "similar to my earlier one" conflation trap the RCA exists to disarm
(rca L7 line 380-381), now reproduced at the slot level.

**If accepted → which line changes.** Branch F (line 379) is fine; optionally make the precedent line
(374-377) say "a *different* slot (Kidu) in Sep-2025" to pre-empt the carryover.

**Counter-hypothesis.** *The action line already pins "Jupiter."* I favor flagging it at LOW only
because the doc's own thesis is that same-word conflation is the dominant failure mode here. Not
blocking.

**Classification: DEFER** (cosmetic clarity; revisit only if the slot-conflation pattern recurs).

---

## V9 — LOW — L11 Step 2 `--debug 2>&1 | sed -n '1,40p'` may truncate the WWW-Authenticate body before it prints

**Evidence grade: THEORETICAL (command behavior; AVD-gated, not run).**

**What I saw.** rca L11 Step 2 (line 487):

```bash
az appconfig kv list --name vpp-applicationconfig-d --auth-mode login --top 1 --debug 2>&1 | sed -n '1,40p'
```

The probe's entire purpose (lines 474-482) is to capture the **HTTP status line + `WWW-Authenticate`
header + any `problem+json` `type`**. `az ... --debug` emits a large volume of CLI bootstrap/telemetry/
HTTP-pipeline logging; the response headers (where `WWW-Authenticate` lives) appear well into that
stream. Hard-capping at `sed -n '1,40p'` (first 40 lines) risks cutting off the response-header block
that is the only thing the step is trying to read.

**How it breaks (potential).** The on-call runs exactly the printed command, the 401 response headers
land at line ~60-120 of `--debug` output, `sed` drops them, and the engineer sees only request-side
debug noise — no status/body — defeating the "master discriminator." They then guess the branch, which
is precisely what the document forbids.

**If accepted → which line changes.** L11 Step 2 (line 487) should grep for the signal
(`grep -iE 'www-authenticate|HTTP/|problem\+json|status'`) rather than blind-truncating at 40 lines, or
raise/remove the line cap.

**Counter-hypothesis.** *40 lines is enough / the on-call will adapt.* I favor flagging at LOW/
THEORETICAL because `az --debug` output ordering and volume is version-dependent and I could not run it
this session (AVD-gated + no CLI). If the WWW-Authenticate header reliably prints within 40 lines this
is a non-issue. **Blocked verification named.**

**Classification: DEFER** (revisit with a captured `az --debug` sample from AVD).

---

## What I did NOT find (exhaustion honesty)

- **Inherited live-store claims passed as FACT:** CLEAN. I specifically hunted for any assertion about
  the *live* `disableLocalAuth`/RBAC/store state stated as fact. The RCA is disciplined: every live-state
  claim is A3-blocked (rca C16/C17, lines 594-595; L5 line 324 "whether the live store still matches it
  remains unverified"; how-to-fix ledger A3 lines 412-413). The IaC/Microsoft-contract facts (A1) are
  correctly separated from live state. No laundering detected. This axis is a genuine pass.
- **Unguarded destructive steps:** CLEAN on the big three. Disable/regenerate keys (Branch B HALT, lines
  276-279), open public access (Branch D HALT, lines 344-346), grant Data Owner (Branch C HALT, lines
  318-320) all carry explicit HALT-for-platform gates. The only destructive *residual* is the
  empty-overwrite footgun (V4) and the secret-on-argv leak (V7) — both reported above, neither is an
  ungated one-way door.
- **`az appconfig show --query disableLocalAuth/publicNetworkAccess` (Step 4, Branch B diagnose):**
  correct, read-only, right resource/RG. No break.
- **`nslookup` private-IP probes (Step 3, Branch D):** correct and read-only. No break.

---

## VERDICT

**2 BLOCKING, 1 HIGH, 4 MEDIUM, 2 LOW.** The documents are well-built as *teaching* artifacts and the
safety gating is real — but as an *operational decision tree followed under pressure* they have two
load-bearing routing failures:

- **V1/V2:** the discriminator probe the entire tree hangs on tests only the Entra arm, while two of the
  hypotheses (Branch B access key, and the "set via pipeline" reading of the verb) live on credentials
  that probe never touches — so a literal follower gets a false "it's fine."
- **V3:** the single most evidence-supported actual cause (pipeline SP 401, named in the RCA's own L6)
  falls through every branch of the fix guide.

These are not preference-shaped; following the docs as written routes the on-call to a dead end with a
false-positive confirmation. **BLOCK `status: complete`** until V1, V2, V3 are resolved. V6 (RCA↔fix
hypothesis-set divergence) should be resolved for coherence; V4/V5/V7 are deferrable with named revisit
conditions.

Source-verification still owed by coordinator: this receipt's command-shape claims (V4 credential `name`
strings, V5 ARM permission requirement, V9 `--debug` ordering) are AVD/CLI-gated and graded
PATTERN-MATCHED/THEORETICAL — confirm against a live AVD `az` session before treating as FACT.

---
*El Demoledor — proving resilience through destruction.*
