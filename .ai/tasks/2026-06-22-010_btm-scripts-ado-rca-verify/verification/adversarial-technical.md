---
task_id: 2026-06-22-010
agent: el-demoledor
status: complete
timestamp: 2026-06-22T00:00:00Z
summary: |
  Adversarial demolition of the SP-identity diagnosis. WIN CONDITION: destroy the
  claims. RESULT: I could NOT falsify the load-bearing claims; every attack vector the
  team-lead handed me was tested with a live probe and FAILED to break the diagnosis.
  V2/V3 (az-login precedence -> SP runs az boards): SURVIVES (live log#19 shows
  ServicePrincipalCredential client_credentials flow on the agent's ext 1.0.4, not the
  Build Service PAT). V4 ([] proves SP can't see board): SURVIVES + the malformed-project
  counter-interpretation is FALSIFIED (HTTP 200, not 404; workItems:[] is a real empty
  result). V6 (dta-sp cannot read Team BtM): SURVIVES via the authoritative
  effectiveAllow bitmask (dta-sp's only group = Pool Creator, which has no ViewWI;
  Contributors has it, dta-sp is NOT a Contributor). V14 (Build Service CAN read area
  6393 -> fix works): SURVIVES and is now UPGRADED from A2/A3 to A1 (project Build
  Service has an explicit ACE effAllow=241 ViewWI=True at the project root area node).
  CRITICAL METHODOLOGY FINDING: `az devops security permission show` effectivePermission
  field is UNRELIABLE for service/group descriptors (reports "Not set" where the
  authoritative ACL extendedInfo.effectiveAllow says Allow); and the
  permissionEvaluationBatch API ignores subjectDescriptor entirely (returns the CALLER's
  access — a bogus descriptor returns True). The ONLY trustworthy read-only resolver is
  accesscontrollists?includeExtendedInfo=true reading extendedInfo.effectiveAllow.
---

# Adversarial Technical Review — Demolition Attempt on the SP-Identity Diagnosis

**Reviewer**: el-demoledor (INFER until source-verified; every A1 below is my own command + captured output)
**Mode**: live, read-only, authenticated as `Alex.Torres@eneco.com` (azure-cli 2.87.0, azure-devops ext 1.0.2)
**Win condition**: prove the diagnosis WRONG or prove the fix would NOT work. I attacked all four claims with live probes. **I failed to break any of them.** Non-contradiction is not confirmation — but several attacks produced *positive disconfirmation of the team-lead's counter-hypotheses*, which strengthens (not just fails to weaken) the diagnosis.

---

## ⚠️ METHODOLOGY LANDMINE (must read before trusting ANY ACL claim in this RCA)

I found two read-only ADO permission tools that **silently lie** about subject permissions. The prior synthesis V6 used one of them (`permission show` -> "Not set"). That happens to land on the right answer for the dta-sp, but for the WRONG reason — and the SAME tool gives a FALSE "Not set" for the Build Service, which would have falsified V14 if taken at face value.

| Tool | Behavior | Verdict |
|------|----------|---------|
| `az devops security permission show` -> `resolvedPermissions[].effectivePermission` | Resolves inherited group grants for **user** descriptors (Alex = "Allow (inherited)") but returns **"Not set"** for **service-identity and group** descriptors even when they DO have the permission via inheritance (project Build Service showed "Not set" at the BtM child node despite having effAllow=241 ViewWI=True at the parent). | **UNRELIABLE for svc/group** |
| `POST _apis/security/permissionevaluationbatch` (subjectDescriptor in body OR query) | **Ignores subjectDescriptor entirely.** A garbage descriptor `aadsp.ZZZZ…` returns `value:true`. It evaluates the **caller** (me, an admin), not the subject. | **USELESS for subject eval as a privileged caller** |
| `GET _apis/accesscontrollists/{ns}?token=…&includeExtendedInfo=true` -> `acesDictionary[desc].extendedInfo.effectiveAllow` (bitmask) | Server-computed per-subject effective allow. Discriminates correctly: David.deJonge effAllow=3 (ViewWI=False) vs Build Service effAllow=241 (ViewWI=True). | **AUTHORITATIVE — the only one I trust** |

All V6/V14 conclusions below are re-grounded on the **third** tool (the bitmask), with the first tool relegated to a corroborating-but-not-load-bearing role.

CSS bit map (namespace 83e28ad4-2d72-4ceb-97b0-c7726d5502c3): 1=ViewPerm, 2=EditNode, 4=CreateChild, 8=DeleteNode, **16=View work items in this node**, 32=Edit work items in this node.

---

## CLAIM V2/V3 — `az login` SP session takes precedence over `AZURE_DEVOPS_EXT_PAT`; the live tag step authenticates as the deployment SP

### VERDICT: **SURVIVES** (and the team-lead's specific attack is disconfirmed)

**The attack I was told to run**: "the precedence test used an INVALID PAT — maybe the extension TRIED the PAT, failed, and fell back to az login; with a VALID PAT the Build Service would win. Also: the agent's az/ext version vs local 1.0.2."

**Probe (A1)** — I read build 1668639 log#19 (the inline `az boards query --debug` step, fix/tagging, 2026-06-04) directly:

```bash
az devops invoke --area build --resource logs \
  --route-parameters project="Myriad - VPP" buildId=1668639 logId=19 \
  --org https://dev.azure.com/enecomanagedcloud --api-version 7.1
```

Captured (verbatim, timestamps trimmed):

```text
INFO: az_command_data_logger: extension version: 1.0.4
DEBUG: cli.azext_devops.dev.common._credentials: Getting credential: azdevops-cli:https://dev.azure.com/enecomanagedcloud
DEBUG: cli.azext_devops.dev.common._credentials: Getting credential: azdevops-cli: default
DEBUG: cli.azext_devops.dev.common.services: trying to get token (temp) for tenant *** and user ***
DEBUG: cli.azure.cli.core.auth.persistence: build_persistence: location='/home/vsts/.azure/service_principal_entries.json', encrypt=False
DEBUG: cli.azure.cli.core.auth.msal_credentials: ServicePrincipalCredential.acquire_token: scopes=['499b84ac-1321-427f-aa17-267ca6975798/.default'], kwargs={}
DEBUG: urllib3.connectionpool: https://login.microsoftonline.com:443 "POST /***/oauth2/v2.0/token HTTP/1.1" 200 1741
... "grant_type": "client_credentials" ...
```

**Why the attack fails**:
- The live agent used **`ServicePrincipalCredential.acquire_token` with `grant_type: client_credentials`** — the AAD service-principal client-credentials flow. This is the `az login --service-principal` session being consumed. It loaded `/home/vsts/.azure/service_principal_entries.json` (the SP login store).
- It did **NOT** use Basic/PAT auth. A Build-Service-PAT path would show the `azdevops-cli` credential resolving to the PAT and a `Basic` Authorization header — instead the credential resolver fell through `azdevops-cli` to the **SP token** path. The extension did not "try the PAT and fall back"; it went straight to the SP MSAL flow.
- **Version-skew angle killed**: the agent ran extension **1.0.4** (not the local 1.0.2). Precedence held the SAME way on 1.0.4. So "different version would flip precedence" is disconfirmed by the actual production version.
- The team-lead's "invalid PAT caused a false fallback" hypothesis is irrelevant to the live pipeline: in the live pipeline there is no PAT-failure event in the trace at all — the SP token is acquired directly and used. (The local PROBE 6/7 used an invalid PAT, but log#19 is the real thing and needs no such crutch.)

**Counter-hypothesis I could not sustain**: "the Build Service PAT actually authenticated and the SP debug line is residual from the earlier login step (log#18)." Disconfirmed: the `ServicePrincipalCredential.acquire_token` line is emitted *inside* the `az boards query --debug` invocation at 14:00:18 (the CmdLine task started 14:00:17), with its own fresh `POST .../oauth2/v2.0/token` — it is this command's auth, not transferred state.

**Consequence for the fix**: confirmed — the tag step in the deployment job runs as the SP, so the prior RCA's `--detect false` alone is insufficient; identity must change. The fix's premise stands.

---

## CLAIM V4 — the SP's `az boards query` on AreaId 6393 returns `workItems:[]` in the live pipeline

### VERDICT: **SURVIVES** — and the team-lead's "malformed --project 6393 / project-not-found" counter-interpretation is **FALSIFIED**

**The attack I was told to run**: "maybe `[]` is caused by the malformed `--project 6393` (project-not-found), not a permission gap."

**Probe (A1)** — full WIQL request+response from log#19:

```text
+ az boards query --debug --wiql 'SELECT [System.Id],[System.Title] FROM workitems WHERE [System.AreaId] = 6393' \
    --organization https://dev.azure.com/enecomanagedcloud/ --project 6393
...
DEBUG: azext_devops.devops_sdk.client: POST https://dev.azure.com/enecomanagedcloud/_apis/wit/wiql
DEBUG: urllib3.connectionpool: https://dev.azure.com:443 "POST /enecomanagedcloud/_apis/wit/wiql HTTP/1.1" 200 313
DEBUG: azext_devops.devops_sdk.client: Response content:
  b'{"queryType":"flat","queryResultType":"workItem","asOf":"2026-06-04T14:00:18.907Z",
     "columns":[{"referenceName":"System.Id",...},{"referenceName":"System.Title",...}],
     "workItems":[]}'
```

**Why the counter-interpretation fails**:
- The WIQL call returned **HTTP 200**, not 404. A project-not-found would be a 404 / `TF200016`-class error. The query **executed successfully**.
- The request went to the **org-level** route `POST /_apis/wit/wiql` (no project segment in the URL). The `--project 6393` did not resolve to a project path and was simply **not applied** to the URL — harmless, NOT fatal. The query still ran org-wide.
- The 200 body literally ends `"workItems":[]` — a genuine empty result set: the SP authenticated, the WIQL ran across the org, and **zero** AreaId-6393 work items were visible to it. (Alex's identical area-6393 query returns 913 — V5.)
- So `[]` is "executed-but-saw-nothing," which is the permission-gap signature, NOT a project-resolution failure. The malformed-project red herring is dead.

**Counter-hypothesis I could not sustain**: "the org-level WIQL genuinely matched nothing for a benign reason (e.g., area 6393 empty for everyone)." Disconfirmed by V5/V10: the SAME `WHERE System.AreaId=6393` returns 913 items for Alex. The only variable between `[]` and `913` is the calling identity.

**Consequence for the fix**: confirmed — the silent `[]` is real pipeline behavior produced by the SP, exactly the symptom Anton reported ("error gone but no output"). The fix must restore an identity that can see area 6393.

---

## CLAIM V6 — `dta-sp` has NO effective Boards read on Team BtM (AreaId 6393)

### VERDICT: **SURVIVES** — re-proven on the authoritative bitmask (the synthesis's "Not set" evidence was right by luck, wrong by method; I re-grounded it)

**The attack I was told to run**: "does 'Not set' actually mean denied, or could the SP read via some other group/inheritance? Re-run the ACL probe and check group memberships."

This is a GOOD attack and it exposed the methodology landmine above. The synthesis's V6 used `permission show` -> "Not set", which I proved is unreliable for svc descriptors. So I re-derived V6 from scratch on the authoritative path.

**Probe 1 (A1)** — dta-sp subject descriptor:
```bash
az devops user list --org … --top 5000   # filtered:
# dn=mcc-btm-deployment-dta-sp pn/oid=7edd1af1-7718-4130-b798-a9b19e32d080
# descriptor=aadsp.ZGMxZTg4NDUtNGI0YS03MTU5LWFjOGMtMWE5OGNhZjFhMzE4  (decodes -> dc1e8845-4b4a-7159-ac8c-1a98caf1a318)
```

**Probe 2 (A1)** — dta-sp transitive group memberships (the inheritance question):
```bash
az devops invoke --area Graph --resource Memberships \
  --route-parameters subjectDescriptor="aadsp.ZGMx…" --query-parameters direction=up
# RESULT: exactly ONE membership -> [Myriad - VPP]\Pool Creator
```

**Probe 3 (A1)** — every ACE that grants View work items (bit 16) at the project ROOT area node (the node Team BtM inherits from), read via the AUTHORITATIVE `extendedInfo.effectiveAllow`:
```bash
az rest --method GET --resource 499b84ac-1321-427f-aa17-267ca6975798 \
  --url ".../_apis/accesscontrollists/83e28ad4-…?token=vstfs:///Classification/Node/53090030-5179-48c8-904c-7cb607fee55c&includeExtendedInfo=true&api-version=7.1"
```
Root area ACEs (effectiveAllow bitmask, ViewWI = bit 16):

| Subject (root area node 53090030) | effAllow | ViewWI? |
|---|---|---|
| David.deJonge@eneco.com (user) | 3 | **False** (discriminator proves the field works) |
| TF Identity …4-1 | 17 | True |
| **Contributors** (S-1-9-…614133671-1008815180-2247410186-2109082691-1-1356316359…) | **241** | **True** |
| TF Identity …305955972 | 17 | True |
| Project Collection Boards SP (…Boards:ed05a211…) | 49 | True |
| **Myriad-VPP project Build Service** (…Build:a7ef9a24-213c-4c4c-85f4-c20a7db60c43) | **241** | **True** |

**Probe 4 (A1)** — is the dta-sp's only group (Pool Creator) among those ACEs?
- Pool Creator SID (base64-decoded from its descriptor) = `S-1-9-1551374245-1957096382-2250970437-2838335899-3618081858-1-944303842-238669129-2718744057-143335450`.
- It is **NOT** present in the root ACE set (the 6 subjects above). Therefore Pool Creator carries **no** area-path ACE -> grants the dta-sp **zero** ViewWI.
- Cross-check: `permission show` for Pool Creator at root = bit16 "Not set", bit32 "Not set" (corroborating; consistent here because Pool Creator genuinely has nothing).
- The dta-sp has **no explicit ACE** of its own anywhere on the area tree.

**Conclusion**: the dta-sp is a member of exactly one group (Pool Creator) that confers no work-item read; it has no direct ACE; Team BtM inherits from root where the dta-sp's effective ViewWI is therefore nil. **V6 SURVIVES** — the SP cannot read Team BtM. This is now grounded on the authoritative bitmask, not the unreliable "Not set" string.

**Counter-hypothesis I could not sustain**: "the SP reads via some other group/inheritance." Disconfirmed — direction=up membership enumeration returned ONLY Pool Creator, and Pool Creator has no ACE. There is no other path.

**Honesty note (non-contradiction ≠ confirmation)**: I could not enumerate *nested* group expansion server-side beyond direct `direction=up`; if Pool Creator were itself nested inside Contributors, the SP would inherit ViewWI. I checked: Pool Creator's SID ≠ Contributors' SID and Pool Creator is a peer top-level group (its membership list did not surface Contributors as a parent in the direct query). Residual: a PCA could confirm Pool Creator has no parent group in one click. This residual does NOT flip the route because the live pipeline already produced `workItems:[]` for this exact SP (V4) — the empirical behavior matches "cannot see," independent of the ACL theory.

---

## CLAIM V14 (THE FIX'S KEYSTONE) — the Build Service identity HAS board read on area 6393, so moving tagging off the SP-login job fixes it

### VERDICT: **SURVIVES — and is UPGRADED from A2/A3 to A1.** This was the synthesis's weakest link; it is now its strongest.

**The attack I was told to run**: "this is A2/A3, NOT directly proven. If the Build Service ALSO lacks area-6393 read, the recommended fix FAILS."

This was the most dangerous attack and I pursued it hardest. It nearly succeeded via the methodology landmine — `permission show` reported the project Build Service as "Not set" for ViewWI at the BtM child node, which (if trusted) would have FALSIFIED V14 and the entire fix. But that field is unreliable for svc descriptors (proven by the David/Alex discriminator). On the authoritative path:

**Probe (A1)** — resolve the project Build Service identity:
```bash
az devops invoke --area ims --resource identities \
  --query-parameters "searchFilter=General" "filterValue=Myriad - VPP Build Service (enecomanagedcloud)"
# descriptor: Microsoft.TeamFoundation.ServiceIdentity;51889d38-…:Build:a7ef9a24-213c-4c4c-85f4-c20a7db60c43
# subjectDescriptor: svc.NTE4ODlkMzgt…OmE3ZWY5YTI0… ; internal id 4493ce4f-29a9-45f9-bfaa-dfee84ec4717
```

**Probe (A1)** — its authoritative effective at the project ROOT area node (from Probe 3 table above):
- `…Build:a7ef9a24…` has an **explicit ACE** with **effAllow=241** → bit 16 (View work items) = **True**, bit 32 (Edit work items) = **True**.
- This is an **explicit** grant on the Build Service identity itself (not merely inherited via Contributors) — effAllow=241 = ViewPerm+ViewWI+EditWI+… It is robust to group-membership changes.
- Team BtM (dfb04683) is a direct child of root with `inheritPermissions: True` and **no overriding deny ACE** for the Build Service on the child token (the BtM-token ACL is essentially empty). So the root grant flows to Team BtM.

**Corroboration**: the project Build Service is a direct member of `[Myriad - VPP]\Contributors` (effAllow=241, ViewWI=True) AND `[Myriad - VPP]\Project Administrators`. Two independent grant paths (own explicit ACE + Contributors membership) both confer ViewWI on area 6393.

**Conclusion**: the project Build Service **CAN read AND write** Team BtM work items. **V14 SURVIVES, upgraded to A1.** Moving the tag step to a job WITHOUT `azure-login.yml` (so `az boards` uses `AZURE_DEVOPS_EXT_PAT=$(System.AccessToken)` = this Build Service identity) will be able to see and tag the board. The fix achieves the effect.

**Alternative reading of PR 178802 I was told to test** ("could it have worked purely via the warm-cache pool / Thread A, while B2B's Build Service happens to have area-4928 read but BTM's lacks area-6393"): the area-4928 vs area-6393 asymmetry is now moot for the *fix* — the SAME project Build Service identity (BTM and B2B are both in project "Myriad - VPP", so both pipelines' `System.AccessToken` resolve to the SAME `Build:a7ef9a24` identity) has effAllow=241 at the project root, which covers ALL child areas including both 6393 and 4928. So B2B's success and BTM's projected success share one cause: the project Build Service can read the whole area tree. The pool switch (`sre-managed-linux`) is indeed incidental — the identity change (no `azure-login.yml` → Build Service PAT instead of SP) is the operative one. **The pool-only counter-explanation cannot account for a board-read result and is not needed.**

**Counter-hypothesis I could not sustain**: "the project Build Service lacks area-6393 read (fix fails, only a permission grant works)." Hard-disconfirmed by the explicit effAllow=241 ACE.

---

## Summary table

| Claim | Verdict | Decisive probe | Consequence for the fix |
|---|---|---|---|
| V2/V3 — SP-login precedence; tag step auths as SP | **SURVIVES** | log#19: `ServicePrincipalCredential.acquire_token` client_credentials on ext **1.0.4** | `--detect false` alone insufficient; identity MUST change — premise holds |
| V4 — SP query returns `workItems:[]` | **SURVIVES**; counter-interp FALSIFIED | log#19 WIQL: `POST /_apis/wit/wiql` → **HTTP 200**, body `"workItems":[]` (not 404) | Silent empty is real SP behavior, not a `--project` bug |
| V6 — dta-sp cannot read Team BtM | **SURVIVES** (re-grounded on authoritative bitmask) | dta-sp groups = {Pool Creator only}; Pool Creator has NO area ACE; no direct ACE | SP must be replaced; do NOT rely on `permission show` "Not set" as proof |
| V14 — Build Service CAN read area 6393 (fix works) | **SURVIVES, upgraded A2/A3 → A1** | project Build Service `Build:a7ef9a24` explicit ACE effAllow=**241** (ViewWI+EditWI=True) at root, inherited by Team BtM | The recommended fix (tag job without `azure-login.yml`, same identity) WILL read+tag the board |

**Overall**: I attacked every claim the team-lead pointed me at, with live read-only probes, trying to break the diagnosis. **I could not falsify it.** Two attacks (V4 malformed-project, V14 fix-fails) produced *positive disconfirmation of the alternative*, strengthening the diagnosis. V14 — the one the synthesis honestly flagged as A2/A3 — is now A1: the project Build Service has an explicit ViewWI grant on the area tree.

## What I am NOT claiming (residual honesty)

1. **Not a runtime end-to-end proof of the fix.** I proved the Build Service *can* read area 6393 (effAllow=241). I did NOT run the modified pipeline. The synthesis's H-EFFECT-1 (realized-tag check after the change) remains the right final gate. My ACL proof makes that gate very likely to pass, but "can read per ACL" → "tag realized" still depends on the script's `--detect false`/`--org`/`--project`/empty-IN-guard hardening also landing (TF401019 and the empty-IN error are separate failure modes the fix must also handle — Sherlock's A1-10 stands).
2. **Pool Creator nesting.** I confirmed dta-sp's only DIRECT group is Pool Creator and Pool Creator has no area ACE. I did not exhaustively prove Pool Creator has no parent group server-side. A one-click PCA check would close this; the live `workItems:[]` (V4) already corroborates "SP cannot see" empirically, so this residual does not flip the route.
3. **The two unreliable permission tools** (`permission show` for svc/group; `permissionEvaluationBatch` as a privileged caller) should be flagged in the RCA's methodology/L9 so the next on-call does not repeat the false "Not set"/false "True" readings. The authoritative read-only resolver is `accesscontrollists?includeExtendedInfo=true` → `extendedInfo.effectiveAllow` bitmask.
