---
task_id: 2026-04-21-001
agent: apollo-assurance-marshal
timestamp: 2026-04-21T18:55:00+02:00
status: complete
verdict: conditional
summary: Pre-deployment grade of Erik Lumbela ArgoCD sandbox access diagnostic. Three of four acceptance criteria MET; AC3 PARTIAL. One material methodology flaw (success-path verification asymmetry). Two required Slack-reply edits plus two recommended pre-send probes. Final verdict DEPLOY WITH EDITS.
total_claims: 4
verified: 2
partial: 1
open_risk: 0
contradicted: 0
absent: 0
top_risk: success-path verification asymmetry (MEDIUM) fixable by Edit 1
---

# Evaluator Grade — Erik Lumbela ArgoCD Sandbox Access Diagnostic

**Scope**: Pre-deployment grade of the diagnostic artifact (enrichment-report.md
and plan.md) against the acceptance criteria in `01-task-requirements-final.md`
section "Verification Strategy > Acceptance criteria". I am NOT the coordinator;
I do NOT accept Alex's 18:03 CEST Slack reply as evidence for itself. It is the
claim under test.

**Independence posture**: I cannot execute kubectl, argocd, or az against the
sandbox cluster from this position. All probe outputs quoted in the enrichment
report are CLAIMED-via-coordinator. From my position they are INFER; from the
coordinator's position they are FACT. The plan's V3/V4 re-probes before Slack
send mitigate this for final delivery, but at grading time I can only evaluate
internal consistency and methodology, not cluster ground truth.

---

## Acceptance Criterion Grades

### AC1 — ONE verified statement, (a) access works and re-login OR (b) broken with cause and fix, with evidence

**Grade: MET**

Evidence citation:
- `enrichment-report.md:5` summary frontmatter states variant (a).
- `enrichment-report.md:82-93` adversarial pass, candidate commit is declared
  and survives six adversarial questions.
- `enrichment-report.md:135-141` concrete Slack reply draft stating variant (a).

The artifact picks variant (a) and carries six probes as evidence. Probes are
structurally well-formed: each has a claim-under-test, reasoning, command,
output, interpretation. Probes 1 through 6 collectively discharge the four
falsifiers in `01-task-requirements-final.md` falsifier list against H2, H3,
and H4.

Residual: The re-login action is INFER, not FACT. The artifact declares this
explicitly at `enrichment-report.md:30`.

### AC2 — Explicitly falsify or confirm Alex's 18:03 claim, with surface identification

**Grade: MET**

Evidence citation:
- `enrichment-report.md:22-30` Load-bearing claims ledger decomposes Alex's
  18:03 Slack claim into four testable parts. Three are promoted to FACT with
  cluster-state evidence. The fourth, token refresh, is held as INFER with a
  named falsifier.
- `enrichment-report.md:42-48` Probe 2 resolves the GUID
  `036bd5f7-78b6-4f5f-8db9-943e7254646d` in the AppProject role binding to the
  same group name Alex claimed. This is the "exactly which surface" proof.
- `enrichment-report.md:42` explicit statement "Claim C3 structurally
  confirmed".

The 18:03 claim was INFER at posting time per
`01-task-requirements-final.md:25`. The enrichment promotes it to FACT with two
independent probes (AppProject manifest plus AAD group name resolution). This
is the correct transformation. Criterion met.

### AC3 — Fix steps with repo, file, line, apply and propagation time, verification command

**Grade: PARTIAL**

Evidence citation:
- `enrichment-report.md:135-141` Recommended Slack reply cites repo
  (Eneco.Infrastructure) and PR (173958).
- `enrichment-report.md:269` appendix names the file
  (`terraform/platform/aad/groups-flex-trade-optimizer-teams.tf`) but the Slack
  reply itself does not cite the file.
- Line: NOT NAMED. Arguably unneeded since the change is a single-line
  group-member addition.
- Apply and propagation time: `enrichment-report.md:267` records
  `closedDate 2026-04-21T15:58:15Z` which is 17:58 CEST. This is in the
  appendix but NOT in the Slack reply body. Erik cannot independently judge
  how recent his token is relative to the deploy.
- Verification command: the reply asks Erik to paste
  `argocd account can-i get applications flex-trade-optimizer/*` ONLY IF access
  does not work. No verification command exists for the SUCCESS branch.

Why PARTIAL and not MET: AC3 requires the verification command as a first-class
deliverable. The artifact provides it but scopes it to the failure branch. A
skeptical auditor reading the reply cannot distinguish between (i) re-login
works and PR was the cause, and (ii) re-login appears to work for trivial
reasons and PR may not be the cause. AC3 is met for the failure branch and NOT
MET for the success branch.

### AC4 — Falsifier list plus evidence

**Grade: MET**

Evidence citation:
- `enrichment-report.md:127-132` three explicit refutation paths: re-login
  refutation, overage refutation, sandbox URL drift refutation.
- `plan.md:93-99` Verification Strategy table with four post-delivery
  falsifiers V1 through V4.
- `01-task-requirements-final.md:49-57` the original six falsifiers F1 through
  F6. Evidence discharge:
  - F1 AppProject existence, probe 1 at `enrichment-report.md:36-41`.
    DISCHARGED.
  - F2 argocd-rbac-cm, probe 3 at `enrichment-report.md:52-57`. DISCHARGED.
  - F3 argocd-cm OIDC, probe 4 at `enrichment-report.md:59-65`. DISCHARGED.
  - F4 PR scope, probe 5 at `enrichment-report.md:67-72`. DISCHARGED.
  - F5 Dev+Acc vs Sandbox RBAC diff, NOT RUN. Listed as residual unknown at
    `enrichment-report.md:157` with stated rationale (low ROI because sandbox
    story is complete). Acceptable.
  - F6 Erik's group memberships, probe 6 at `enrichment-report.md:74-80`.
    Partially discharged. F6 asked for "every plausible AAD group"; only one
    group was checked. Adequate because probes 1 and 3 narrowed the
    AuthZ-relevant set to exactly two groups, and probe 2 identified those.

Criterion met. Discharge logic is transparent; undischarged falsifiers are
named with rationale.

---

## Traceability Matrix

```
AC  | Claim                                | Evidence chain                                                                          | Type             | Status
----|--------------------------------------|-----------------------------------------------------------------------------------------|------------------|----------
AC1 | ONE verified statement (a)           | enrichment-report.md:5 then :82-93 then :135-141                                        | DETERMINISTIC*   | MET
AC2 | 18:03 claim confirmed with surface   | final.md:25 then enrichment:36-48 then :62-65                                           | DETERMINISTIC*   | MET
AC3 | Fix steps repo+file+line+time+verify | enrichment:135-141 plus :267-270 plus :139                                              | PARTIAL-CHAIN    | PARTIAL
AC4 | Falsifier list plus evidence         | final.md:49-57 then enrichment:127-132 plus probes 1-6 plus :157                        | DETERMINISTIC*   | MET
```

\* DETERMINISTIC from the coordinator's position (commands run, outputs
observed). From Apollo's independent position: CLAIMED-via-coordinator.
Environmental match: coordinator's local kubectl+argocd+az session. Sufficiency
gate per DNA-3: TYPE DETERMINISTIC plus DEPTH FULL plus ENV LOCAL. Downgraded
one level to VERIFIED with environmental assumption. Assumption: coordinator
faithfully transcribed output and session pointed at the cluster and tenant
the artifact names. V3 and V4 re-probes before Slack send in plan.md mitigate
staleness. Acceptable.

---

## UNVERIFIED Claims Assessment

The artifact carries three load-bearing INFER or UNVERIFIED claims. Each
assessed:

### U1 — Erik needs to re-login to pick up the groups claim

- Location: `enrichment-report.md:30` explicit INFER in ledger;
  `enrichment-report.md:88` adversarial Q3 acknowledges not directly confirmed.
- Evidence ceiling: Without capturing Erik's actual ID token before and after
  re-login, this cannot be promoted to FACT. Canonical AAD plus OIDC mechanism
  supports the claim, but canonical mechanism does not equal observed behavior
  for this user on this tenant at this time.
- Evidence ceiling verdict: ACCEPTABLE. The artifact declares it as INFER and
  supplies V1 and V2 falsifiers that would trigger escalation if wrong.
  Re-probing from the coordinator's side requires Erik's cooperation, which the
  artifact routes as contingent.
- Recommendation: Do NOT block. DO require that the Slack reply edits include a
  success-path verification command (see Required Edits).

### U2 — argocd-server session token, not just Azure token, must be refreshed

- Location: `enrichment-report.md:89` adversarial Q4.
- Evidence ceiling: Named from ArgoCD canonical behavior. argocd-server session
  TTL of 24h is documented; the artifact reasons correctly that browser
  re-auth alone does not guarantee session replacement.
- Evidence ceiling verdict: ACCEPTABLE. Mechanism-reasoning about a canonical
  system; no fresh probe required.
- Recommendation: OK as-is. The Slack reply wording "sign out of ArgoCD
  sandbox and sign back in" is correct; it deliberately avoids "re-login to
  Azure".

### U3 — No overage claim, Erik has under 150 AAD groups

- Location: `enrichment-report.md:87` Q2 plus `enrichment-report.md:156`
  residuals.
- Evidence ceiling: Probe available (`az ad user get-member-groups` piped to
  `wc -l`) but not run. Labeled "risk LOW, VPP developer accounts typically
  have under 50 groups".
- Evidence ceiling verdict: ACCEPTABLE to DEPLOY but worth pre-probing. One
  command probe that discriminates between "re-login fixes" and "requires
  separate ticket for overage handling". ROI exceeds cost. RECOMMEND (not
  require) running before Slack send.

### Claims that should NOT have been promoted to FACT but look like they were

NONE found in the load-bearing ledger. A-label discipline is clean: probes 1
through 6 produce FACT; the re-login step is explicitly held as INFER.

Verdict on UNVERIFIED claims: Epistemic hygiene is sound. Evidence ceilings are
explicit. No claim requires re-probing before send EXCEPT the
recommended-not-required U3 overage check.

---

## Methodology Flaw Analysis

Per my remit: identify methodology flaws that would make a passing verification
produce a wrong answer. I found one material flaw and two near-misses.

### Material flaw — Success-path verification asymmetry

Flaw: The plan's V1 falsifier is "Erik confirms FTO apps are visible after
sign-out plus in". The Slack reply at `enrichment-report.md:139` instruments
the FAILURE branch only. The SUCCESS branch has NO independent verification.
Erik saying "I can see it now" is consistent with:

  (a) PR plus re-login fixed the root cause (RCA correct), AND
  (b) Erik was already seeing FTO apps but misread the UI earlier (RCA wrong
      but outcome correct), AND
  (c) An unrelated auto-sync between 15:42 and 18:05 updated something else
      (coincident cause).

Under (b) and (c), the recorded diagnostic enters institutional memory as
"PR 173958 plus re-login solves sandbox ArgoCD access for a new developer" when
the actual causal chain may be different. Next on-call handling a similar
ticket pattern-matches to this "solved" case, applies the same playbook, and
fails silently.

Severity: Marginal (bad doctrine is recoverable; no user-facing incident).
Probability: Occasional (pattern-matching is the main reuse path for on-call
diagnostics).
Risk level: MEDIUM.

Remediation: The Slack reply MUST ask Erik to paste one affirmative success
signal. Minimal edit: change "If you don't, paste the output of" to "Please
paste the output of `argocd account can-i get applications flex-trade-optimizer/*`
so we confirm the grant is live."

### Near-miss 1 — Slack pre-PR snapshot provenance

The pre-PR `az ad group member list` snapshot lives in Alex's 18:03 Slack
message. The enrichment report cites that message as evidence that Erik was NOT
in the group before the PR. Apollo cannot fetch Slack; from my position this is
a CLAIMED artifact. If the pre-PR snapshot was never posted, or was posted but
is imprecise, the coincident-cause counter-hypothesis is alive.

Verdict: Acceptable residual. The PR Terraform diff is independently reviewable
via ADO; if the diff adds Erik, he was not there before. Not blocking.

### Near-miss 2 — Cluster identity proof on the probed kubectl context

All kubectl probes use context `vpp-aks01-d` (appendix line 278), but the
artifact does not prove `vpp-aks01-d` IS the cluster Erik hits when he visits
`argocd.dev.vpp.eneco.com`. `az account show` confirms the subscription and RG
are sandbox-shaped but the DNS-to-cluster mapping is asserted, not probed.

Verdict: Acceptable residual. If wrong, the whole diagnosis would be
irrelevant. But Erik has been using the URL and his symptom shape constrains
the identity. Adding a one-line probe (`dig +short argocd.dev.vpp.eneco.com`
against sandbox ingress IP `50.85.91.121`) would promote this to FACT. Plan Q4
names the probe but routes it contingent; moving it to Step 1 pre-send has
positive ROI.

### Methodology check for missed silent-failure modes

Applying the silent-failure design check from a fresh frame:

- Token cache across browser tabs: Erik signs out of one tab; another tab with
  FTO-less session is still live; he tests there; reports failure. Would look
  like V1 fails, wasting Step 4 time. Mitigation: reply should say "sign out of
  all ArgoCD tabs" or "close browser, reopen". Minor edit value.
- Ingress sticky session: unlikely for ArgoCD but not impossible. Low
  probability.
- AppProject cache in argocd-application-controller: Q1 in plan names
  argocd-server caching but not controller. Controller does not authorize UI
  requests; not applicable.

No missed silent-failure beyond the material flaw above.

---

## Required Edits for DEPLOY WITH EDITS

The following edits to the Slack reply are NECESSARY before send.

### Edit 1 REQUIRED — Add affirmative success verification

Current reply ending at `enrichment-report.md:139`:

> After re-login, you should see the FTO apps and have get+create+update+sync+
> override+delete on them. If you don't, paste the output of
> `argocd account can-i get applications flex-trade-optimizer/*` here.

Change to:

> After re-login, you should see the FTO apps and have get+create+update+sync+
> override+delete on them. Please paste the output of
> `argocd account can-i get applications flex-trade-optimizer/*` so we confirm
> the grant is live end-to-end. If it returns `yes` we are done; if it returns
> `no` or errors, post the full output and we will debug.

Rationale: closes the success-path verification asymmetry. Adds under 30
seconds of Erik's time. Converts V2 from a contingent probe to a primary probe,
matching the artifact's own risk ranking.

### Edit 2 REQUIRED — Include deploy timestamp

Current reply: "is merged and deployed".

Change to: "is merged and deployed (closed 17:58 CEST today)".

Rationale: addresses AC3 apply and propagation time requirement in Erik's view,
not only in the appendix. Erik can reason "my last ArgoCD login was before
17:58, so I need a fresh token".

### Edit 3 RECOMMENDED — Pre-probe AAD groups count

Before send, run:

```
az ad user get-member-groups --id Erik.Lumbela@eneco.com \
    --security-enabled-only false --query 'length([])' -o tsv
```

If over 120, HALT send and add an overage-handling note. If under 120, no
change to reply. Probe cost: one az call. ROI: removes U3 from residual list.

### Edit 4 RECOMMENDED — Confirm cluster-URL identity

Before send, run:

```
dig +short argocd.dev.vpp.eneco.com
```

If resolves to sandbox ingress IP `50.85.91.121` per `plan.md:78` Q4, add a
one-line appendix note. If resolves elsewhere, HALT send and re-probe against
the correct instance.

---

## Residual Risk Register

| ID | Risk | Severity | Probability | Level | Mitigation |
|----|------|----------|-------------|-------|-----------|
| R1 | Success-path verification asymmetry leads to wrong doctrine promoted | Marginal | Occasional | MEDIUM | Edit 1 REQUIRED |
| R2 | Deploy-timestamp omission leaves Erik unable to judge token staleness | Negligible | Probable | LOW | Edit 2 REQUIRED |
| R3 | AAD groups overage over 150, groups claim replaced by src1 | Marginal | Improbable | LOW | Edit 3 pre-probe |
| R4 | DNS or cluster identity drift, wrong instance diagnosed | Critical | Remote | MEDIUM | Edit 4 pre-probe |
| R5 | Coincident cause, pre-PR snapshot not in artifact from my view | Marginal | Remote | LOW | Acceptable, PR diff content addresses indirectly |
| R6 | Coordinator transcription fidelity of probe outputs | Marginal | Remote | LOW | V3 and V4 re-probes before send |
| R7 | Staleness of V3 and V4 re-probes if send delayed over 30 min | Marginal | Occasional | LOW | Plan Step 1 acceptance bounds to last 30 minutes |

No UNACCEPTABLE risks. No HIGH risks. Two MEDIUM risks both addressable with
required edits that cost under two minutes total.

---

## Environmental Assumptions Registry

| ID | Assumption | Verified By | Status |
|----|-----------|-------------|--------|
| A1 | Coordinator kubectl session pointed at correct sandbox cluster | kubectl current-context equals vpp-aks01-d plus az account show tenant and sub IDs at enrichment:277-282 | VERIFIED |
| A2 | Coordinator az session has permissions to read group membership | Probe 6 returned value true, no auth error | VERIFIED |
| A3 | Sandbox ArgoCD URL argocd.dev.vpp.eneco.com resolves to probed cluster | Asserted in plan.md:78 Q4, not probed | UNVERIFIED, Edit 4 target |
| A4 | Azure AD tenant eca36054 is Eneco tenant carrying Erik's claims | argocd-cm oidc issuer matches az account show tenantId at enrichment:28 | VERIFIED |
| A5 | No Azure AD group overage affecting Erik | Canonical "usually fine" reasoning, not probed | UNVERIFIED, Edit 3 target |
| A6 | Probe outputs in artifact faithfully represent live state at probe time | No mechanism to independently confirm from evaluator position | ENVIRONMENTAL, accept |
| A7 | Sandbox argocd-server not restarted or misconfigured after AppProject update | Plan Q1 names probe, not yet run | UNVERIFIED, plan routes to Step 1 |

Two UNVERIFIED environmental assumptions (A3, A5) are the two
REQUIRED-or-RECOMMENDED pre-send edits. One (A7) is already in plan Step 1.
Others VERIFIED.

---

## Assurance Verdict

**CONDITIONALLY_ASSURED, DEPLOY WITH EDITS**

Conditions that must be satisfied before Slack send:

1. REQUIRED. Apply Edit 1, affirmative success verification command.
2. REQUIRED. Apply Edit 2, deploy timestamp in reply body.
3. REQUIRED. Execute plan.md Step 1 pre-send re-probes within 30 min of send
   (V3 and V4, AppProject manifest and AAD group membership unchanged).
4. RECOMMENDED. Apply Edit 3, AAD groups count pre-probe.
5. RECOMMENDED. Apply Edit 4, DNS resolution of ArgoCD URL.

If conditions 1 through 3 are satisfied, the diagnostic qualifies as ASSURED
for Slack send. Conditions 4 and 5 reduce residual risk from LOW to
NEGLIGIBLE.

Risk acceptance required from human (Alex) if proceeding without 4 and 5:

> I accept LOW residual risk R3 (AAD overage edge case) and LOW residual risk
> R4 (DNS identity assumption) by choosing not to run Edit 3 and Edit 4
> pre-probes.

---

## Falsification Protocol Passes

### Pass 1 — Environmental Challenge

Seven environmental assumptions identified and cataloged. A3, A5, A7
UNVERIFIED. A3 and A5 drive the RECOMMENDED edits. A7 routed by plan Step 1.
No others discovered.

### Pass 2 — Adversarial Path Challenge

- Path P1. Erik re-logs in, sees NO FTO apps, replies "still broken". Handled
  by plan Step 4. No new risk.
- Path P2. Erik re-logs in, sees FTO apps, replies "works". Without Edit 1,
  doctrine locks in without affirmative verification. This is the material
  methodology flaw. Addressed.
- Path P3. Erik delays re-login; argocd-server session expires naturally at
  24h boundary; access appears to "fix itself" at unpredictable time. Reply
  timing affects this. The reply says "sign out and back in" so Erik's action
  disambiguates. No edit needed.
- Path P4. Reply sent during ArgoCD server restart window, session briefly
  works by accident. Not probed. Low probability, acceptable residual.

Pass 2 introduced no new items beyond Pass 1 materials. Ledger stable. No
Pass 3.

---

## Final Verdict

**DEPLOY WITH EDITS**

The diagnostic is structurally sound, epistemic hygiene is unusually high
(A-labels maintained, INFER explicitly held, adversarial pass documented with
consequences). All four acceptance criteria are met or partial with named
closure paths. The single material methodology flaw (success-path verification
asymmetry) is fixable with a one-sentence edit. After Edits 1 and 2 and plan
Step 1 re-probes, this artifact may be sent to Erik.

If the coordinator disagrees with Edit 1 REQUIRED status and sends the reply
as currently drafted, residual risk is MEDIUM (R1) and must be explicitly
accepted as doctrine-contamination risk. I recommend against accepting; the
edit cost is trivial.

---

## Scope Boundaries of This Grade

- I did NOT execute kubectl, argocd, az, or curl. All probe outputs are read
  from the artifact.
- I did NOT fetch Slack messages. Alex's 18:03 reply content is taken from the
  artifact's own citations, not re-fetched.
- I did NOT grade the Slack-reply register (banned phrases, AI-tells). That is
  a separate quality gate routed elsewhere.
- I did NOT evaluate whether the recommendation should be posted at all
  (organizational and timing considerations out of scope).
- I graded against the acceptance criteria in
  `01-task-requirements-final.md:41-46`, not against any later-introduced
  criteria.
