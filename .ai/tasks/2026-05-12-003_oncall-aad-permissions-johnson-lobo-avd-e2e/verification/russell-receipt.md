---
task_id: 2026-05-12-003
agent: bertrand-russell
timestamp: 2026-05-12T00:00:00Z
status: complete
verdict: conditional

summary: |
  C is WEAKENED-but-survives (NEEDS_REPAIR per Russell taxonomy; frontmatter
  verdict=conditional). The conclusion "Azure CLI not in preAuthorizedApplications
  is the root cause" has TWO defects: (i) it conflates a SUFFICIENT condition with a
  NECESSARY-and-sufficient root cause — at least one rival mechanism (missing
  delegated user-consent oauth2PermissionGrant for the Azure CLI ↔ resource SP pair)
  produces the SAME 650057 error string with empty "valid resources" tail and is
  NOT falsified by P1-P7; (ii) the recommended-fix disjunction (Bruno OR E2E SP) is
  not proven exhaustive. P3 (appRoleAssignmentRequired=false) does NOT eliminate the
  consent-record rival because user-consent is a separate AAD plane from app-role
  assignment. Repair: re-label C as "diagnosis-consistent hypothesis, not
  uniquely-discriminated root cause," add one probe (oauth2PermissionGrants for
  client 04b07795 ↔ resource 0abb4cf9 on johnson.lobo's principal vs a working
  teammate's principal), and qualify the recommendation as "two known working
  paths" not "the two valid clients."

weapons_fired:
  - Theory of Descriptions: definite description "the root cause" — uniqueness conjunct fails (multiple rivals survive)
  - Vagueness taxonomy: "root cause" is many-dimensional (proximate vs enabling vs configurational) — not sharpened
  - Logical Atomism: C decomposed into C1 (cause) ∧ C2 (Bruno works) ∧ C3 (E2E SP works) ∧ C4 (exhaustive)
  - Acquaintance audit: P8 chain not verified — "teammates run tests" is description, not observed witness
  - Type-Theory: P2 is type-n current snapshot; error at 10:30:43Z is type-n past event — temporal stratification
---

# Russell Receipt — AADSTS650057 Root-Cause Chain Audit

## Key Findings

- A1 defect: necessary-vs-sufficient — empty preAuthorizedApplications is sufficient for 650057 but NOT the only sufficient configuration; missing oauth2PermissionGrant (user-consent) also produces 650057
- A2 defect: equivocation — preAuthorizedApplications (admin-consent shortcut) is conflated with oauth2PermissionGrants (per-user delegated consent record); these are distinct AAD entities
- A3 defect: universal-vs-existential — P2 is a current snapshot; no probe at 10:30:43Z; gap is real but cheap to bound
- A4 defect: hidden premise — "teammates use Bruno or E2E SP not az CLI" has no cited witness; if any teammate uses az CLI successfully, the entire C1 collapses
- A5 defect: quantifier — recommendation not exhaustive (MSAL test runners, AzureAD-PowerShell, az CLI w/ explicit --scope, device-code flow all unconsidered)
- A6 defect: definition — trailing dot in "valid resources from app registration: ." is plausibly AAD error punctuation, NOT proof of literal empty list; over-interpretation risk

## Verdict Mapping

- Russell-taxonomy verdict: **NEEDS_REPAIR**
- Frontmatter-validator verdict: **conditional** (closest allowed mapping in `{accept|reject|conditional|partial|inconclusive|escalate}`)

## Weapons Activation Checklist (§5.4)

| Weapon | Trigger row (§5.1) | Fired: Y/N | Condition observed (or rationale for N) |
|---|---|---|---|
| Theory of Descriptions | definite description in input | Y | "the root cause of johnson.lobo's AADSTS650057" — surface noun phrase pre-commits to existence + uniqueness + predication |
| Vicious-Circle detection | self-referential verification claim | N | C is not defined in terms of itself; no oracle self-reference; AAD is external authority outside the claim |
| Type-Theory check | category-ambiguous term | Y | P2 (current app config snapshot, type-n) vs error event at 10:30:43Z (past type-n event) — different time-indices treated as interchangeable; feeds A3 |
| Acquaintance audit | inference chain without direct observation | Y | P8 "teammates can run E2E tests" — no cited probe, no named teammate, no observed run; description-knowledge floating without acquaintance terminal |
| Vagueness taxonomy | many-dimensional / sorites-vague predicate | Y | "root cause" is many-dimensional (proximate config / enabling design / contributing process / triggering action) and sorites-vague (at what causal depth does "the" cause begin?) |
| Logical Atomism decomposition | compound claim not evaluable as-is | Y | C = C1(missing-preAuth=cause) ∧ C2(Bruno=working) ∧ C3(E2E-SP=working) ∧ C4(exhaustive) — atomization mandatory before evaluation |
| Dissolution over refutation | subject-term existence/uniqueness/predication all failed | N | Existence OK (error did occur), uniqueness UNDER-ATTACK but not failed, predication WEAKENED but not failed — proceed to predicate evaluation with repairs |

## Form-level audit outcome

FORM-REPAIRED → proceeds to evaluation. Subject term "the root cause" survives existence; uniqueness and predication require repair (see Defects below).

## Atomized conclusion under audit

- **C1**: `cause(error_650057, missing_preAuth(04b07795 ∉ app(0abb4cf9).preAuthorizedApplications))`
- **C2**: `works(client = Bruno, path = publicClient.redirectUris[localhost/bruno/callback])`
- **C3**: `works(client = E2E SP appId 8c81ac05, path = client-credentials, role = isOnboardingAdministrator)`
- **C4**: `valid_clients_for_resource(0abb4cf9) = {Bruno, E2E SP}` — quantifier closure

## Defects — A1 through A6

### A1 — Necessary vs Sufficient

- **Defect**: "Client not in preAuthorizedApplications" is SUFFICIENT for 650057, not NECESSARY. The argument uses (P1 ∧ P2) ⊢ "this is the cause" but the same error string is produced by AT LEAST these rivals: (R1) missing `oauth2PermissionGrant` for the (user, client, resource) triple on a delegated flow, (R2) requested `--scope` references a resource the client never had any consent path to (admin or user), (R3) client requested a `scope` value (e.g. `api://0abb4cf9/.default`) that does not match any exposed scope on the resource even though preAuth would have allowed it, (R4) cross-tenant guest-user path where home-tenant consent state differs from resource-tenant state. P3 (`appRoleAssignmentRequired: false`) eliminates ONE rival (application-permission enforcement) but NOT R1-R4.
- **Class**: necessary-vs-sufficient
- **Implication for C**: WEAKENED-but-survives — C1 is one of ≥2 surviving sufficient explanations; P1-P7 do not discriminate
- **Remediating probe or wording change**: Re-label C1 as "diagnosis-consistent hypothesis with at least one unfalsified rival (missing oauth2PermissionGrant)." Add probe:
  ```bash
  az ad user show --id johnson.lobo@<tenant>
  # then on a working teammate's user principal:
  az rest --method GET --uri "https://graph.microsoft.com/v1.0/users/{userId}/oauth2PermissionGrants"
  # Filter where clientId = SP-of-04b07795 AND resourceId = SP-of-0abb4cf9
  # Compare johnson.lobo vs working teammate.
  ```
  If johnson.lobo has the grant and still fails → C1 strengthens. If she lacks it AND the teammate has it → C1 is REJECTED in favor of the consent-record rival.

### A2 — Equivocation

- **Defect**: The chain treats `preAuthorizedApplications` as the operative gate, but AAD has FOUR distinct entities that can block a client→resource request: (a) `app.api.preAuthorizedApplications` — admin-consent shortcut declared on the resource app registration, (b) `app.api.knownClientApplications` — multi-app consent bundling, (c) `oauth2PermissionGrants` — per-user delegated consent records (tenant-wide if admin-granted, per-user otherwise), (d) `appRoleAssignments` — application-permission grants. P2 covers (a) and (b); P3 indirectly addresses (d); (c) is NOT PROBED. Azure CLI as a public client requesting a delegated scope on `api://0abb4cf9` will fail with 650057 if (c) is missing even when (a) is also empty — these are NOT the same gate.
- **Class**: equivocation
- **Implication for C**: WEAKENED-but-survives → REQUIRES-PROBE — without an oauth2PermissionGrants probe, the diagnosis cannot distinguish "admin-consent missing" from "user-consent missing"
- **Remediating probe or wording change**: Same probe as A1. Additionally, replace "Azure CLI's client ID is not pre-authorized" with "Azure CLI's client ID has no consent path (neither admin-preauth nor user-consent grant) to resource api://0abb4cf9" — this widens C1 to the truthful disjunction.

### A3 — Universal vs Existential (temporal)

- **Defect**: P2-P3 are CURRENT-state observations (today). The error fired at 2026-05-12 10:30:43Z. The chain assumes `state(today) = state(10:30:43Z)`. AAD config can change in minutes (admin edits, group sync, conditional-access policy rollout). The gap is real but cheap to bound. The chain treats a universal-over-time claim as if proven by one snapshot.
- **Class**: universal-vs-existential
- **Implication for C**: WEAKENED-but-survives — the gap is real; usually bounded by the absence of an audit-log change event between 10:30:43Z and probe time
- **Remediating probe or wording change**:
  ```bash
  az monitor activity-log list --resource-id <objectId-of-app-0abb4cf9> \
    --start-time 2026-05-12T10:00:00Z --end-time 2026-05-12T14:00:00Z
  # Also AAD audit:
  az rest --method GET --uri "https://graph.microsoft.com/v1.0/auditLogs/directoryAudits?\$filter=targetResources/any(t:t/id eq '<app-objectId>') and activityDateTime ge 2026-05-12T10:00:00Z"
  ```
  If zero modifications between error time and probe time → temporal universal is bounded → C1 holds at error time too. If modifications exist → C1's predicate may have changed; re-probe.

### A4 — Hidden premise (acquaintance failure)

- **Defect**: P8 "teammates can run the same E2E tests" has no acquaintance terminal. No named teammate, no observed test run, no cited evidence of WHICH client they used. C2 and C3 are derived partly from P8 (via I3) plus P5 (Bruno has localhost redirect) and P6 (E2E SP has the role). But the inference "therefore they use Bruno or E2E SP, not direct az CLI" is a SILENT EXCLUSION of az CLI from teammate workflows. If even one teammate runs az CLI successfully against this resource — for instance, because they had `az login` with a delegated user-consent grant that johnson.lobo lacks — then C1 collapses (the difference is not "client ineligible" but "user-consent record missing for THIS user").
- **Class**: hidden-premise
- **Implication for C**: REQUIRES-PROBE — if a working az CLI teammate exists, C1 is REJECTED
- **Remediating probe or wording change**:
  ```bash
  # Ask in #vpp-btm: "Does anyone successfully call api://0abb4cf9 via direct
  # `az account get-access-token --resource api://0abb4cf9/.default` (no Bruno,
  # no E2E SP)? If yes, run on your machine:
  # az rest --method GET --uri 'https://graph.microsoft.com/v1.0/me/oauth2PermissionGrants'
  # and share the entry where clientId points to Azure CLI's SP."
  ```
  Add to write-up: "C1 holds only under the implicit premise that NO teammate uses direct az CLI to reach this resource. This premise is uncited; if falsified, the diagnosis becomes 'johnson.lobo lacks a user-consent grant that working teammates have'."

### A5 — Quantifier (exhaustiveness of fix)

- **Defect**: "Use Bruno OR use E2E SP" claims the disjunction is exhaustive for working paths but only enumerates two. Other public clients with their own preauth/consent state are not considered: bundled MSAL test runners, AzureAD-PowerShell (different client ID, may have its own consent), Postman with OAuth2 PKCE flow, device-code flow via `az login --use-device-code` (same Azure CLI client ID but different consent prompt path that can succeed where token-cache flow fails), or even `az account get-access-token --resource api://0abb4cf9 --scope api://0abb4cf9/.default` with an explicit scope value that may resolve differently.
- **Class**: quantifier (non-exhaustive)
- **Implication for C**: WEAKENED-but-survives — Bruno and E2E SP are two known-working paths, not the universe of valid clients
- **Remediating probe or wording change**: Replace "she must use a different client — either Bruno or E2E SP" with "two known-working paths are Bruno (P5) and E2E SP client-credentials (P6); other clients with their own consent state may also work but were not enumerated for this incident." Avoid "must" + closed disjunction.

### A6 — Definition (over-interpretation of error string)

- **Defect**: "List of valid resources from app registration: ." — the trailing `.` is taken as evidence of literal empty list. But this string is AAD's templated error format; `"List of valid resources from app registration: <list>."` where `<list>` is empty would yield `"List of valid resources from app registration: ."` with the period being sentence punctuation. The string is CONSISTENT with empty preAuth, but is also CONSISTENT with "the formatter rendered nothing because the user-consent path was missing and the resource-side preAuth was orthogonal to the request type." The dot does not uniquely prove the empty-preAuth interpretation. P2's empty array is independent direct evidence; the error-string interpretation is redundant at best, misleading at worst.
- **Class**: definition (over-interpretation)
- **Implication for C**: WEAKENED-but-survives — defect is in the rhetoric, not the conclusion; P2 carries the load, P1's tail does not
- **Remediating probe or wording change**: Stop citing the trailing dot as evidence. Cite ONLY P2 (`api.preAuthorizedApplications: []` directly from `az ad app show`) for the empty-list claim. Note in the write-up: "the error string is consistent with empty preAuth but does not uniquely identify it as cause."

## Countermodel candidates and survival

### Strongest countermodel (R1: missing oauth2PermissionGrant)

**Construction**: johnson.lobo's tenant has `api://0abb4cf9` with `preAuthorizedApplications=[]` (P2 holds), `appRoleAssignmentRequired=false` (P3 holds), and an exposed delegated scope (e.g., `user_impersonation`). Working teammates have a tenant-wide admin-granted `oauth2PermissionGrant` for (Azure CLI SP → resource SP, consentType=AllPrincipals) OR per-user grants on their own principals. johnson.lobo lacks the per-user grant AND the tenant grant does not apply (perhaps her principal is in a group excluded from the admin grant, or the grant was per-user only). Azure CLI request to `api://0abb4cf9` then fails with EXACTLY 650057 because the consent-record check fails before any preAuth check.

**Does it survive premises?** Yes — P1-P8 do not falsify it. P3 only rules out app-role-assignment enforcement, not consent records.

**Does C survive?** No: under R1, C1's stated cause ("client not in preAuthorizedApplications") is technically TRUE but is NOT what's blocking the request — the consent record is. The fix "use Bruno" would work for a different reason (Bruno is a different client with its own consent state and the localhost redirect makes user-consent prompt-recoverable), masking the real difference.

### Blocked countermodel (R-CA: conditional-access policy)

A CA policy blocking johnson.lobo's principal on the Azure CLI client app would NOT produce 650057 — it would produce AADSTS53003 or similar. So this rival is correctly excluded by the error code itself, not by the chain's premises. Blocked by error-code semantics.

## Verdict

- **C1 (cause = missing preAuth)**: WEAKENED-but-survives → REQUIRES-PROBE. At least one rival (R1) is not falsified.
- **C2 (Bruno works)**: SOUND. P5 carries the load; the localhost redirect makes Bruno a different consent-prompt-eligible client.
- **C3 (E2E SP works)**: SOUND. P6 is direct evidence of the role assignment.
- **C4 (exhaustive disjunction)**: REJECTED. Quantifier failure (A5).

## Falsifier (single discriminating probe)

```bash
# 1. List johnson.lobo's delegated consent grants for Azure CLI → resource SP:
az rest --method GET --uri "https://graph.microsoft.com/v1.0/users/<johnson-lobo-objectId>/oauth2PermissionGrants"

# 2. List tenant-wide grants from Azure CLI SP to resource SP:
az rest --method GET --uri "https://graph.microsoft.com/v1.0/oauth2PermissionGrants?\$filter=clientId eq '<Azure-CLI-SP-objectId>' and resourceId eq '<resource-0abb4cf9-SP-objectId>'"

# 3. Same probe on a working teammate's principal.
```

**Outcome interpretation**:
- Both users have NO consent grant AND teammates are confirmed to use only Bruno/E2E SP → C1 holds at full strength. Recommend wording fix anyway (A5, A6).
- johnson.lobo lacks a grant that working teammate has → C1 REJECTED. New diagnosis: missing per-user delegated consent on the Azure CLI ↔ resource SP edge. New fix: admin-grant tenant-wide consent OR have user complete the consent prompt OR add resource to `preAuthorizedApplications` (admin-consent shortcut that would also resolve it).
- Both users have grants and johnson.lobo still fails → look at token claims (groups overage, missing app role on resource role-assigned identity), not at consent.

## Handoff

Logic audit complete. Next owner is investigation (Sherlock) — the single oauth2PermissionGrants probe discriminates between C1 (current diagnosis) and R1 (missing user-consent), and the answer flips the recommended fix. The chain is not invalid — it is under-discriminated.

RUSSELL_VERDICT: NEEDS_REPAIR
