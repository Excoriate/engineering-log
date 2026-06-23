---
title: "SRE fix-safety adversarial review — how-to-fix.md (FBE Duncan App Config 401)"
type: research
status: complete
task_id: 2026-06-22-006
agent: sre-maniac
timestamp: 2026-06-22T16:20:00+02:00
summary: >-
  Adversarial repair-safety review of how-to-fix.md. WIN-LANE = operational correctness +
  one-way-door completeness ONLY (not hypothesis ranking, not goal fidelity). Three named
  gates (key disable/regen, public-access, Data-Owner over-grant) are correct. But TWO
  irreversible/shared-state mutations are UNGATED: (1) Branch B Step writes an IaC-managed
  KV secret (connectionstrings-app-config) directly with az, causing config drift that the
  next Terraform apply silently reverts — and the value pulled is the PRIMARY WRITE key, an
  over-privileged credential for a read path; (2) Branch C role-assignment via group
  sg-vpp-core-release-masters grants Data Owner store-wide to a shared group, blast radius
  unstated. Branch A `az logout` mutates the shared AVD session for any concurrent tooling.
  Verification is mostly EFFECT-based but Branch E/F close on portal view / pipeline-green,
  the exact anti-patterns the doc itself forbids. Receipt below: per finding the line,
  mechanism, blast radius, accept-consequence, classification.
---

# SRE Fix-Safety Receipt — how-to-fix.md

Win condition (this reviewer alone): which "safe" step can still cause an incident, and is
every one-way door actually gated. NOT hypothesis re-ranking, NOT goal fidelity.

All findings INFER until coordinator source-verifies the cited line against the file.
Citations are to `how-to-fix.md` unless prefixed `rca.md` or `ctx:`.

---

## F1 — Branch B KV-secret refresh is an UNGATED config-drift one-way door [CRITICAL]

**Step / quote** — Branch B, lines 268–274:
```
CS=$(az appconfig credential list ... --query "[?name=='Primary'].connectionString | [0]" -o tsv)
az keyvault secret set --vault-name <dev-mc-kv> --name connectionstrings-app-config --value "$CS" >/dev/null
```
The one-way-door HALT box at lines 276–279 gates ONLY `disableLocalAuth` toggling and key
regeneration. It does NOT gate the `az keyvault secret set` itself.

**Failure mechanism** — The secret `connectionstrings-app-config` is **IaC-managed**, not a
free-standing operational secret. `ctx: fbe-ff-mechanism.md:86-90` —
`module "primary_connectionstring_appconfig"` (in `appconfig-mc-lz.tf:36-44`) writes that
exact secret = `module.appconfig.app_configuration_primary_write_key_connection_string`. An
operator doing `az keyvault secret set` on a Terraform-owned secret creates **state drift**:
the next `terraform apply` (or a drift-detection pipeline) will compute a diff and **silently
revert** the secret to whatever value Terraform last recorded — re-breaking the consumer that
the operator just fixed, at an unrelated future time, with no operator present to correlate
cause. This is the classic "fix that un-applies itself on the next pipeline run" — strictly
worse than the original incident because the regression is now time-delayed and
non-obvious.

**Second mechanism (over-privilege, separate)** — The value harvested is the **Primary**
credential, which per `ctx: fbe-ff-mechanism.md:89-90` is the *primary WRITE* key
(`...primary_write_key_connection_string`). The read path needs only a **read** connection
string. Refreshing the KV secret from the write key hands every read-path pod a write-capable
credential — a standing privilege the doc's own Branch C HALT (lines 318–320) would otherwise
forbid. The doc enforces least-privilege for RBAC but silently over-privileges on the key
path.

**Blast radius** — Every connection-string consumer of `connectionstrings-app-config`. Per
`ctx: fbe-ff-mechanism.md:95-99` the read library is shared (FleetOptimizer + the FBE service
wire the same `Eneco.Vpp.Configuration.AzureAppConfiguration`). If multiple slots/services
read this one KV secret, a manual overwrite touches all of them; the IaC revert later breaks
all of them. The doc warns about the connection string being *a secret* (no Slack/logs, line
279) but says nothing about it being *IaC-owned shared state*.

**Retry/rollback** — Not stated. There is no "capture the prior secret value before
overwriting" step, so if the harvested `$CS` is itself wrong (e.g. operator on wrong
subscription, or store was the FBE-specific store per the unresolved C17 gap), the operator
has destroyed the prior secret value with no rollback. Partial-apply hazard: secret set
succeeds, pod roll (line 273 comment) fails → pods now on a half-changed state.

**If accepted → change** — Add a one-way-door HALT to Branch B covering the secret write:
"`connectionstrings-app-config` is Terraform-managed (`appconfig-mc-lz.tf:36-44`). A manual
`az keyvault secret set` will be reverted by the next App Config IaC apply. The durable fix is
to re-run the App Config IaC pipeline so Terraform rewrites the secret from the live key, OR
get platform-team sign-off to hand-set with a tracked follow-up to reconcile IaC. Capture the
existing secret value first (`az keyvault secret show ... -o tsv`) for rollback. Prefer a
*read* connection string, not Primary write, for the read path." Also fold the IaC-ownership
warning into the Anti-patterns table.

**Classification: RESOLVE** (gate addition + rollback step + read-key correction required).

---

## F2 — Branch C role assignment via shared group has unstated store-wide blast radius [HIGH]

**Step / quote** — Branch C, lines 308–315 and `rca.md:394`:
```
- prefer adding it to `sg-vpp-core-release-masters` over a one-off assignment, so IaC stays the source of truth.
```
The HALT box (lines 318–320) gates only "Data Owner to a frontend consumer." It does NOT
warn about what adding a principal to `sg-vpp-core-release-masters` actually grants.

**Failure mechanism** — `sg-vpp-core-release-masters` holds **App Configuration Data Owner on
the whole store** (`rca.md:294`, `ctx: fbe-ff-mechanism.md` C5, `dev.tfvars:1051-1055`). Adding
an identity to that group does NOT scope it to one flag or one slot — it grants
create/edit/delete/disable on **every feature flag in `vpp-applicationconfig-d`**, shared
across all FBE slots and consumers of that store. The doc frames "add to the group" as the
*safe, least-privilege, IaC-clean* choice; for a Data Reader need it is the **opposite** —
it is the same over-grant the adjacent HALT forbids, laundered through a group. The
least-privilege guidance (Data Reader for runtime reads, line 307) and the group guidance
(line 309) are in tension: the group only carries Data Owner.

**Blast radius** — Anyone added to `sg-vpp-core-release-masters` can delete/disable flags for
every slot reading the shared store, and the group is also the pipeline's release-master group
(membership has CI/CD authority implications beyond App Config). Group membership is itself
shared mutable state: it persists, is invisible at the App Config blade, and is rarely
reviewed. An on-call adding a member "to unblock" creates a standing privilege escalation that
outlives the incident.

**Retry/rollback** — `az role assignment create` (line 313-314) is retry-safe (idempotent-ish;
duplicate assignment is harmless). Group membership add is reversible but NOT mentioned as
something to remove after the incident. Propagation note (line 316, "up to 15 minutes") is
good and prevents a false-negative retry storm.

**If accepted → change** — Split the Branch C guidance: (a) for a **read** need, NEVER use the
group (it carries Data Owner) — use a direct `App Configuration Data Reader` assignment scoped
to the store or, better, to the specific identity; (b) the group is appropriate ONLY for the
apply-SP Data-Owner case, and even then note that membership = store-wide
create/delete/disable + release-master authority, is a tracked grant, and should be added in
IaC (`dev.tfvars`) not by hand so it does not drift. Add a blast-radius line to the HALT box.

**Classification: RESOLVE** (the "prefer the group" guidance is unsafe for the read case as
written).

---

## F3 — Branch A `az logout` mutates the shared AVD interactive session [MEDIUM]

**Step / quote** — Branch A, lines 222–227:
```
az logout
az login                                                            # pick the Eneco dev-mc tenant
```
Labelled "Fix (reversible, no gate)" (line 220) and "Rollback: none needed — re-authentication
changes no shared state" (line 238).

**Failure mechanism** — On a shared AVD session host, `az` credentials live in a per-user
profile (`~/.azure`) that is shared across **every shell, terminal, and background
tool/script** that user has running on that AVD. `az logout` clears the token cache for ALL of
them, not just the operator's current window. If another engineer is sharing the AVD identity,
or the operator has a concurrent long-running `az`/Terraform/`oc` operation in another pane,
`az logout` + `az login` into a *different* tenant (the operator may pick the wrong tenant
interactively) yanks the credential out from under the concurrent work mid-flight. The doc's
claim "changes no shared state" is **false for a shared AVD host** — the token cache is shared
state.

**Blast radius** — Concurrent `az`/SDK processes under the same AVD user; bounded to that AVD
session, not other environments. Low probability but real on a shared bastion.

**Retry/rollback** — Re-login is retry-safe. The residual risk is the *interactive tenant
pick* (line 225 comment "pick the Eneco dev-mc tenant"): a wrong pick re-creates the very
wrong-tenant 401 the branch is fixing, but now the operator believes they "fixed" it. The
`az account show` check (line 227) catches this — good — but only if the operator reads
tenant, not just exit code.

**If accepted → change** — Soften the "changes no shared state" claim to "changes your AVD
session token cache (shared across your shells on this AVD host) — ensure no concurrent
`az`/Terraform run is mid-flight before `az logout`." Prefer `az login` (refresh in place) over
`az logout` first when only a token refresh is needed; `az logout` is only required to switch
identity/tenant.

**Classification: DEFER** (real but low-probability; revisit if AVD identity is shared across
engineers — link to `feedback_oncall_argocd_three_plane` AVD-identity precedents and the
Fabrizio AVD-recreation identity-drift precedent `rca.md` C12).

---

## F4 — Verification quietly closes on portal/pipeline-green in Branches E and F [HIGH]

**Step / quote** — The doc's own law (line 91, line 394 anti-pattern, `rca.md:423` falsifier)
is "verify by the failing operation returning 200 from the failing context, NEVER the portal,
NEVER a green pipeline."

- **Branch E, line 365**: "Verify by EFFECT: the blade loads the feature-flags list in the
  alternate browser." This closes on the **portal blade rendering** — which is the
  control-plane view the doc spends L4/anti-patterns proving is NOT the data-plane test. If
  the real fault were a data-plane credential AND a browser quirk, "blade loads in Chrome"
  greenlights closure while the data-plane call still 401s. The verification contradicts the
  doc's own Defense rung (line 91).
- **Branch F, line 381**: "after the run, the flag appears in the store and the slot reads
  it." The first half ("flag appears in the store") is a portal/control-plane observation; the
  load-bearing half is "the slot reads it." As written, an operator can stop at "the pipeline
  went green and I see the flag in the portal" — exactly the line-394 anti-pattern.

**Failure mechanism** — Both branches let the operator close on a control-plane signal. Branch
E is the more dangerous because its *entire* effect-check is the portal. The doc is internally
inconsistent: it forbids portal-as-proof globally, then uses it as the Branch E proof.

**Blast radius** — Incident marked resolved while the data-plane fault persists; Duncan
re-files; trust in the runbook erodes. No infra blast radius.

**If accepted → change** — Branch E verify: "the blade loads AND re-run the data-plane call
(`az appconfig kv list --auth-mode login`) returns 200 — the browser swap only excludes the
portal-render fault, it does not prove the data plane." Branch F verify: drop "flag appears in
the store" as sufficient; require the **slot** read (frontend lights up / update events resume)
as the closing signal, consistent with Branch B's standard (line 281).

**Classification: RESOLVE** (verification must match the doc's own EFFECT-not-view law in
every branch).

---

## F5 — Branch B sub-case decision lacks a read-only confirmation of the live key before write [MEDIUM]

**Step / quote** — Branch B, lines 263-266 route `disableLocalAuth=false` → "the service has a
stale connection string. Refresh the KV secret from the current primary key."

**Failure mechanism** — `disableLocalAuth=false` proves keys are *enabled*; it does NOT prove
the KV secret is *stale*. The branch jumps from "keys enabled" to "therefore stale secret,
overwrite it" without a read-only comparison (does the KV secret's embedded key match a live
credential?). If the true fault is elsewhere (wrong store per the unresolved C17 FBE-specific
store gap, `rca.md` C17), the operator overwrites a healthy IaC-managed secret (see F1) for no
reason and introduces drift. AVD read-only-first discipline (line 201, "Run read-only probes
first") is stated globally but Branch B's write step is not preceded by a confirmation that the
secret is actually stale.

**Blast radius** — Same as F1 (IaC-managed shared secret).

**If accepted → change** — Insert a read-only confirmation before the write: compare the key
id in the KV secret to the live `az appconfig credential list` primary; only overwrite if they
differ. Otherwise the "stale" hypothesis is asserted, not verified — and the fix mutates shared
state on an unconfirmed premise.

**Classification: DEFER** (revisit once C17 — which store the FBE actually reads — is resolved;
if FBE uses its own store, the entire Branch B probe target in the doc is wrong).

---

## F6 — AVD-execution boundary and read-only-first: correctly scoped [REBUT / positive]

**Checked, found sound:**
- AVD-execution boundary box (lines 201–204) correctly scopes every live `az`/`oc`/SDK probe
  to the AVD session, names automation cannot reach the PE, and mandates read-only probes
  first and re-auth first. This is the right operator boundary.
- Step 0 / Branch D (lines 178-181, 341) correctly route timeout/network to "use AVD / link
  DNS" and HALT on public-access — the public-network one-way door (lines 344-346) is complete
  and correctly attributes ownership to the platform team.
- Diagnose steps in Branches B (258-260) and C (300-302) are read-only `--query` shows before
  any mutation. Good read-then-write discipline where present.
- Data-Owner over-grant HALT (lines 318-320) and key disable/regen HALT (276-279) are both
  mechanism-correct and name the cross-environment blast radius.

**Classification: REBUT** (no change — these are correctly gated; cited to confirm the review
covered them and they pass).

---

## Summary table

| # | Finding | Severity | Class | Gate/step that changes |
|---|---|---|---|---|
| F1 | Branch B KV `secret set` is IaC-managed + uses write key — ungated config-drift one-way door | CRITICAL | RESOLVE | Add HALT + rollback capture + read-key correction |
| F2 | Branch C "prefer the group" grants store-wide Data Owner for a read need | HIGH | RESOLVE | Split read (direct Data Reader) vs apply-SP (group) guidance |
| F4 | Branch E/F verify on portal/pipeline-green, violating the doc's own EFFECT law | HIGH | RESOLVE | Require data-plane 200 / slot read as closing signal |
| F3 | Branch A `az logout` mutates shared AVD token cache; "no shared state" is false | MEDIUM | DEFER | Soften claim; prefer in-place refresh |
| F5 | Branch B overwrites secret on unconfirmed "stale" premise, no read-only diff | MEDIUM | DEFER | Add key-id comparison before write |
| F6 | AVD boundary + public-access/Data-Owner/key HALTs | — | REBUT | None (sound) |

**Net verdict (this lane only): FIX FIRST.** The three named one-way doors are correct, but the
doc has TWO ungated shared-state mutations (F1 KV secret write, F2 group membership) that can
turn one developer's blocked flag into a delayed multi-consumer regression — the exact outcome
the doc's anti-patterns claim to prevent. F4 is a self-inconsistency that lets two branches
close on the portal the doc forbids. F1 and F2 must be gated before this ships as a runbook.

Highest-stakes load-bearing claim: **F1 — `connectionstrings-app-config` is Terraform-managed,
so a manual `az keyvault secret set` will be reverted by the next App Config IaC apply.**
Falsifier: if that KV secret is NOT written by `module "primary_connectionstring_appconfig"`
(`ctx: fbe-ff-mechanism.md:86-90` / `appconfig-mc-lz.tf:36-44`) but is instead operator-owned,
F1's drift mechanism collapses to a one-time over-privilege concern. Stakes-class: HIGH.
