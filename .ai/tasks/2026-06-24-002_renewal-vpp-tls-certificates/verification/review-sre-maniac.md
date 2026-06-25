---
title: Adversarial reliability review — PROD *.vpp.eneco.com wildcard TLS rotation
task_id: 2026-06-24-002
agent: sre-maniac
status: complete
timestamp: 2026-06-24T00:00:00Z
summary: |
  Reliability & blast-radius adversarial review of the wildcard-vpp-eneco-com prod rotation spec.
  VERDICT: FIX FIRST — the spec is broadly sound (versionless KV ref, force-refresh model, surgical
  whitelist finally are all correct against Azure-documented behavior), but it carries THREE high-severity
  reliability gaps that can produce an unrecoverable state or an unverifiable success:
  (1) the AGW ssl_certificate binding IS terraform-managed (versionless URI in prd.tfvars) — drift is
  benign on the data plane but a future prd apply re-asserts the versionless ref, and a careless rollback
  that disables the only-enabled version can trip Azure's auto-listener-disable behavior = hard outage;
  (2) rollback timing trap is real and tight — old cert expires Jul 1 2026, rollback is only useful if a
  bad-cert verdict lands BEFORE Jul 1; (3) prod listeners are private so H-EFFECT-1 is unverifiable
  without an AVD/internal path — success cannot be asserted from the operator's machine.
---

# Adversarial Reliability Review — PROD `*.vpp.eneco.com` Wildcard Rotation

## Key Findings

- **drift**: AGW ssl binding is TF-managed via versionless KV URI; data-plane import does NOT drift, but rollback-by-disable can trip listener auto-disable
- **rollback_window**: old cert dies Jul 1 2026 (~7d); rollback is dead after that — schedule with margin
- **verify_reach**: private listeners → H-EFFECT-1 needs AVD/internal; otherwise success is unverifiable
- **agw_refresh**: no documented listener flap; hot in-place swap — OR-3 is LOW, not HIGH
- **whitelist**: finally + residual-0 is sufficient but masks failure of the remove call itself
- **monitoring**: AGW Resource Health + KV poll-error is the catch signal; must be watched during window

> Lane: RELIABILITY & BLAST RADIUS. Win condition = find the path to a prod outage, an
> unrecoverable state, or an unverifiable "success." READ-ONLY review; no Azure mutated.
> Evidence labels: A1 FACT (file:line / cmd output / doc URL) · A2 INFER · A3 UNVERIFIED[blocked].
> All conclusions here are INFER until the coordinator source-verifies the cited surfaces.

## Verdict

**FIX FIRST.** The mechanism (versionless ref + force-refresh) is correct. But the rollback
path has a latent hard-outage mode, the rollback window is dangerously close to cert expiry,
and the success criterion is unverifiable from the operator's machine. Three plan changes are
mandatory before GO. Two are recommended.

---

## 1. Terraform drift — VERIFIED (decisive, changes the spec)

### What I found (A1)

- The cert object `wildcard-vpp-eneco-com` is **NOT** a managed `azurerm_key_vault_certificate`.
  `grep -rn azurerm_key_vault_certificate terraform/` → **zero hits**. So a data-plane
  `az keyvault certificate import` does NOT collide with a TF-managed cert resource. OR-1's
  worst case (TF owns the cert and recreates/reverts it) is **FALSE**. Good.
- BUT the **App Gateway SSL binding IS terraform-managed**:
  `configuration/prd.tfvars:1518` —
  `key_vault_secret_id = "https://vpp-appsec-p.vault.azure.net/secrets/wildcard-vpp-eneco-com"`
  consumed by `terraform/application-gateway.tf` module `application_gateway`
  (`ssl_certificates = var.application_gateway.ssl_certificates`).
- The URI is **VERSIONLESS** (no `/<version-guid>` suffix). This is exactly what Azure
  recommends for auto-rotation (A1: learn.microsoft.com/azure/application-gateway/key-vault-certs
  — "use a secret identifier that doesn't specify a version… Application Gateway automatically
  rotates the certificate if a newer version is available").

### Failure mechanism

Because the TF binding is versionless and points at the object (not a version), **importing a
new version does NOT cause TF plan drift on the `ssl_certificates` attribute** — the stored
value in state is the versionless URI, which is unchanged. A2 INFER: a subsequent `terraform
plan` for prd will show **no diff** on the cert binding. This is the safe outcome.

The residual drift risk is narrower and real: the import changes the *KV object's enabled
version set* (data plane), which TF does not track at all. So TF will never "revert" the import.
The only way TF touches this is if someone edits `prd.tfvars` to pin a versioned URI — not in
this plan's scope.

### CI re-apply schedule — VERIFIED: no scheduled auto-apply

- `.azuredevops/pipelines/terraform-cd-prd.pipeline.yaml:1` → **`trigger: none`**. No CI trigger
  on push to the working branch.
- Apply is gated: `applyCondition: eq(variables['Build.SourceBranch'], 'refs/heads/main')` AND
  runs through ADO Environment `vpp-core-infrastructure-prd` (manual-approval gate per CCoE
  template `azure-oidc-validate-and-apply.yaml`).
- `grep -rln "schedules:|cron:" *.yml` over the pipelines → **no cron schedule** on prd CD.

So: **CI will not auto-revert or auto-reapply on a timer.** Drift cannot silently undo the
import. The next prd apply happens only when a human merges to `main` and approves.

### The actual drift hazard (the one to write into the plan)

Hidden coupling, not revert: if **between the import and the next prd apply** someone runs a
prd `terraform apply` for an unrelated change, the AGW module does a PUT that — per Azure docs
(A1: "Any change to Application Gateway forces a check against Key Vault… the new certificate is
immediately presented") — **re-pulls the latest enabled KV version**. If the new cert is healthy,
fine. If the new cert was imported but later found bad and you rolled back by *disabling* it,
that unrelated apply re-checks KV and serves whatever is now latest-enabled. Net: the data-plane
state is governed by KV's enabled-version set, and any AGW PUT (yours OR a teammate's apply)
re-reads it. The plan must treat "what is the latest *enabled* KV version" as the single source
of truth and never leave it ambiguous.

### Conditional change

> **Plan MUST add:** a pre-flight check that **no prd terraform apply is in-flight / pending merge
> to `main`** during the change window (ask the team / check open prd PRs), because any prd AGW
> apply re-pulls latest-enabled KV and will race your rollback. And a post-change note that the
> import does NOT drift TF (versionless ref) — so no TF state import/refresh is needed.

---

## 2. AGW force-refresh blast — VERIFIED: OR-3 is LOW, not HIGH

### Mechanism (A1: Azure docs)

`az network application-gateway update` with no body is a no-op PUT. Azure: "Any change to
Application Gateway forces a check against Key Vault… If an updated certificate is found, the new
certificate is **immediately presented**." The doc describes a **hot, in-place certificate swap**
on the data plane. There is **no documented listener flap, connection drain, or TLS interruption**
for a cert refresh — the gateway presents the new leaf on the next handshake; existing TLS
sessions are not described as being torn down.

### Residual risk (the honest caveat)

A2 INFER: a full-config PUT on a v2 AGW is generally non-disruptive, but the operation can take
minutes to converge across instances, and during convergence different instances may briefly serve
old vs new leaf. For a like-for-like renewal (same CN/SAN/CA — confirmed A1 in
`context/02-scope-confirmed.md:14-22`) this is **invisible to clients** (both leaves validate to
the same names and chain). The blast is therefore negligible *for this specific rotation*.

A3 UNVERIFIED[blocked: needs live test, out of READ-ONLY scope]: exact per-instance convergence
time on `vpp-ag-p`. Not load-bearing because like-for-like makes mid-convergence skew benign.

### Safer refresh

The force-update is already the safe path (vs waiting up to 4h for the auto-poll). No change needed.
Do NOT instead delete/re-add the ssl_certificate or the listener — that WOULD flap. The no-op PUT
is correct.

### Conditional change

> **Plan SHOULD add:** "expected refresh is a hot in-place swap; do NOT delete/recreate the
> listener or ssl_certificate as an alternative refresh — that flaps live traffic." Documents why
> the chosen method is the safe one (prevents a future operator 'improving' it into an outage).

---

## 3. Rollback timing trap — VERIFIED (highest-stakes finding)

### Mechanism

- Old cert (`wildcard-vpp-eneco-com` current version) **expires Jul 1 2026** (A1:
  `context/02-scope-confirmed.md:19`). Today = **2026-06-24**. Window = **~7 days**.
- The spec's rollback (step 8) = disable the new version → AGW re-pulls → **old version restored**.
- **The rollback is only useful while the old cert is still valid.** If a bad-cert verdict lands
  **on or after Jul 1 2026**, rolling back to the old version serves an **expired cert** to all
  four prod hosts = browser/API TLS failure = outage with NO safe fallback. You'd be forced to
  fix-forward under fire.

### Quantified window

```
2026-06-24 (today) ──────── 7 days ──────── 2026-07-01 (old cert dead)
        ▲ rollback fully useful            ▲ rollback becomes a SECOND outage
```

Effective safe rollback window after the change = `Jul 1 2026 00:00Z minus (change start)`.
If you rotate on Jun 30, you have <1 day of rollback safety. If you rotate Jun 24-25, you have
~6 days. **Earlier is strictly safer.**

### Detection

A bad new cert is detected by H-EFFECT-1 (served-cert thumbprint/expiry check) — see §4. The
trap is that the detection-to-decision latency must fit inside the remaining window.

### Conditional change

> **Plan MUST add a scheduling constraint:** execute the rotation **no later than 2026-06-27**
> (≥4 calendar days before Jul 1) so a same-day or next-day bad-cert finding still has a *valid*
> old cert to roll back to. State explicitly: "if the change slips past ~Jun 29, rollback safety
> is effectively gone; treat any post-Jun-29 attempt as fix-forward-only and have the replacement
> PFX re-issue path ready." Recommend executing **today/tomorrow**.

---

## 4. Verification reachability — VERIFIED: success is unverifiable from operator's machine

### Mechanism

All four listeners are `private = true` for the served paths (A1: `prd.tfvars:1207,1216,1222,1228`
— `agg`, `apollo`, `flex-trade-optimizer` are `private: true`; `gurobi` is `private:true,public:true`).
The spec itself flags this (step 7: "listeners are PRIVATE, so this MUST run from AVD / internal
network (cannot be done from this machine)"). The H-EFFECT-1 openssl `s_client` check is the ONLY
defined success signal, and it is **not runnable from the operator's laptop**.

### The trap

If the operator cannot reach the private listeners, then after `az network application-gateway
update` returns exit 0, **there is no witnessable proof the new cert is actually served.** `az`
exit 0 only proves the control-plane PUT succeeded, NOT that the data plane serves the right leaf.
This is exactly the "looks successful while wrong" failure: KV holds the new cert, AGW PUT
succeeds, but a propagation fault or wrong-version-enabled state could leave a stale/broken leaf
served and the operator would declare success blind.

### Concrete witnessable signals (propose, in priority order)

1. **AVD / internal jumpbox openssl** (the spec's H-EFFECT-1) — the gold signal. PASS = all four
   hosts serve notAfter Dec 30 2026 + thumbprint == new leaf SHA1. **This MUST be available before
   GO.** If no AVD path → do not start.
2. **`gurobi.vpp.eneco.com` is `public:true`** (A1: `prd.tfvars:1198`) — if its public listener
   resolves externally, the operator CAN run the served-cert check against `gurobi` from the
   laptop as a partial witness for the shared `wildcard-vpp-frontend-https` cert (all four hosts
   bind the SAME ssl_certificate_name `wildcard-vpp-frontend-https`, A1: prd.tfvars:1197/1214/
   1219/1227). Since they share one cert object, a correct served cert on `gurobi` is strong
   evidence for all four. A3 UNVERIFIED[blocked]: whether gurobi's public frontend is actually
   internet-reachable / not WAF-blocked for a TLS handshake — confirm before relying on it.
3. **AGW resource-level cert state via control plane** (no data path needed):
   `az network application-gateway ssl-cert show -g <rg> --gateway-name vpp-ag-p -n
   wildcard-vpp-frontend-https` and the AGW's effective cert — confirms the gateway *accepted* the
   KV pull (publicCertData / state). Weaker than a handshake but witnessable from the laptop.
4. **AGW Resource Health = Available** (no KV-error event) during/after — see §6.

### Conditional change

> **Plan MUST change H-EFFECT-1 from "must run from AVD" to a tiered witness:** (a) primary =
> AVD openssl on all four; (b) if no AVD, fallback = openssl handshake on **public `gurobi`** (same
> shared cert) + `az ... ssl-cert show` control-plane confirmation + AGW Resource Health. **GO is
> blocked unless at least one handshake-level witness (AVD or gurobi-public) is achievable** — the
> control-plane checks alone cannot prove the served leaf. Make "no witnessable served-cert path →
> NO-GO" an explicit precondition.

---

## 5. Whitelist lifecycle — VERIFIED sufficient, one masked failure mode

### What's correct (A1: spec §4/§9)

- Surgical KV-only `network-rule add` / `remove` (not the broad `enecoazwhitelist*` alias).
- Removal in a `finally` (runs on failure).
- Residual check: `length(networkAcls.ipRules[?contains(value,'$MYIP')])` expect 0.
- `context/02-scope-confirmed.md:54` confirms residual-0 already verified on prd in the scope probe.

### Residual failure mode (the gap)

The `finally` runs `network-rule remove` then checks residual. **But if the `remove` call itself
fails** (transient 429/throttle, expired SP token mid-run, `$MYIP` changed because the egress IP
rotated between add and remove), the residual check will report **non-zero** — and the spec does
not define what happens then. A non-zero residual = **the KV firewall is left open to an IP**, a
standing security exposure. Also: `--ip-address "${MYIP}/32"` on remove must match the EXACT value
used on add; if `curl ifconfig.me` returns a different IP on the second call (NAT/proxy rotation),
the remove targets the wrong rule and the original rule persists.

### Detection

The residual `-o tsv` value != 0. The spec prints it but does not gate/alarm on it.

### Conditional change

> **Plan MUST add:** (a) capture `$MYIP` ONCE at the top and reuse the same variable for add AND
> remove (never re-`curl` for the remove) — already implied but make it explicit and assert
> `$MYIP` is non-empty before the add. (b) If residual != 0 after remove, **escalate loudly**
> (non-zero exit, explicit "KV FIREWALL STILL OPEN FOR $MYIP — REMOVE MANUALLY" message) rather
> than passing silently. (c) Optionally list ALL ipRules at the end, not just the count for $MYIP,
> to catch a leftover rule under a rotated IP.

---

## 6. Monitoring — VERIFIED signal exists; MUST be watched during the window

### Catch signal for a botched rotation (A1: Azure docs)

- **AGW Resource Health**: if the gateway "is unable to access the associated key vault or locate
  the certificate object in it, the application gateway automatically sets the listener to a
  **disabled state**." A disabled listener = the host stops serving TLS = **outage**. This is the
  single most important signal and it is the same mechanism that makes a careless rollback
  dangerous (see below).
- **KV 4-hour poll error** surfaced via Azure Advisor recommendation "Resolve Azure Key Vault
  issue for your Application Gateway" + Resource Health alert.
- Repo-side: the IaC ships AGW metric alerts (`terraform/metric-alert-app-gateway.tf`, A1: file
  exists in repo listing) — check whether it alarms on backend/listener health or failed requests;
  those would catch a TLS-serving failure indirectly.

### CRITICAL cross-finding: rollback-by-disable can TRIP the auto-disable outage

A1 (Azure docs): the gateway disables the listener if it **cannot locate the certificate object /
access KV**. The spec's rollback (step 8) disables the *new* version assuming AGW falls back to the
previous enabled version. This is true **only if a previous version is still enabled and resolvable**.
A2 INFER risk: if the import somehow left only one enabled version, or if the disable + force-update
races such that AGW momentarily sees no enabled version, the gateway could set the listener
**disabled** = the exact outage the rollback was meant to prevent. The rollback must verify the OLD
version is `enabled:true` in KV *before* disabling the new one.

### Conditional change

> **Plan MUST add:** (a) **Watch AGW Resource Health for `vpp-ag-p` live during the change window**
> (control-plane, no data path needed) — a flip to Degraded/Unavailable or a "disabled listener"
> event is the abort signal. (b) Rollback step 8 MUST first assert the OLD KV version is
> `enabled:true` (it's recorded in `rollback-baseline.json`, step 4) BEFORE disabling the new
> version, so AGW always has a resolvable enabled version and never trips auto-disable. (c) Add a
> post-change watch of `metric-alert-app-gateway` / Rootly for ~1 poll cycle.

### Apex `p-vpp-eneco-com` (exp Jul 20) — same window?

A2 INFER recommendation: **No, do not bundle.** Reasons: (1) it's a different object
(`p-vpp-eneco-com`, A1: prd.tfvars:1514) serving a different listener (`vpp.eneco.com` apex,
`private:true` only) — separate blast surface; (2) bundling doubles the change's blast radius and
the number of things that can go wrong in one window; (3) apex has 26 days of runway vs the
wildcard's 7 — no shared urgency. Rotate the wildcard now (tight deadline), prove the procedure
end-to-end, THEN rotate apex in a separate window using the now-validated runbook. Bundling would
trade a proven-once procedure for a 2x-blast first attempt under deadline = anti-pattern.

> **Plan SHOULD state:** apex is explicitly OUT of this window; schedule separately after this
> rotation validates the runbook, before Jul 20.

---

## Devil's Advocate (Q1-Q6)

- **Q1 (3 AM pre-mortem):** Most likely failure = operator runs the rotation but has no AVD path,
  declares success on `az` exit 0, and a stale leaf is served undetected until a client reports a
  TLS error. Mitigated by §4 (block GO without a handshake witness).
- **Q2 (10x scale):** N/A — this is a single cert swap, not load-bearing throughput. No saturation
  dimension.
- **Q3 (dev↔prod drift):** The one environmental difference that bites = egress IP rotation between
  the `network-rule add` and `remove` (§5), leaving the KV firewall open. Mitigated by capture-once.
- **Q4 (cascade / blast radius):** Worst cascade = rollback disables the only enabled version → AGW
  auto-disables listeners → all 4 hosts down (§6). Blast = 100% of agg/gurobi/apollo/flex-trade
  traffic. Mitigated by asserting OLD version enabled before disabling new.
- **Q5 (debug from dashboards):** AGW Resource Health + Advisor KV recommendation are the dashboards;
  must be open during the window (§6).
- **Q6 (auto-recover?):** No auto-recovery. A disabled listener stays disabled until KV access/cert
  is fixed. A post-Jul-1 bad rotation has NO valid rollback. Both require manual fix-forward — hence
  the scheduling and pre-rollback-assertion mandates.

---

## Required changes (gate to GO)

| # | Severity | Change | Source finding |
|---|----------|--------|----------------|
| R1 | HIGH | Schedule the rotation **≥4 days before Jul 1 (no later than 2026-06-27; today/tomorrow preferred)**; declare post-~Jun-29 attempts fix-forward-only | §3 |
| R2 | HIGH | Rollback step 8 MUST assert OLD KV version `enabled:true` BEFORE disabling the new version (prevents AGW auto-disable outage) | §6, §1 |
| R3 | HIGH | Block GO unless a **handshake-level served-cert witness** is achievable (AVD openssl OR public `gurobi` handshake); control-plane checks alone are insufficient | §4 |
| R4 | MED | Pre-flight: confirm no prd `terraform apply` is pending/in-flight during the window (avoids AGW PUT racing the rollback) | §1 |
| R5 | MED | Whitelist: capture `$MYIP` once, reuse for add+remove, escalate loudly (non-zero exit) if residual != 0 | §5 |
| R6 | MED | Watch AGW Resource Health for `vpp-ag-p` live during the window; treat disabled-listener / KV-error as abort | §6 |
| R7 | LOW | Note: do NOT delete/recreate listener or ssl_cert as a refresh alternative (would flap); no-op PUT is correct | §2 |
| R8 | LOW | Apex `p-vpp-eneco-com` explicitly OUT of this window; separate post-validation window before Jul 20 | §6 |

## Confidence & evidence status

- VERIFIED (A1, cited): no managed cert resource; versionless TF-managed AGW binding; `trigger:none`
  + no cron on prd CD; Azure versionless auto-rotate + force-refresh hot-swap + listener auto-disable
  on KV/cert-not-found; private listeners; gurobi public; old cert expiry Jul 1.
- INFER (A2): AGW convergence is benign because like-for-like; rollback-disable can trip auto-disable
  if no enabled fallback; gurobi-public usable as shared-cert witness.
- BLOCKED (A3, out of READ-ONLY scope): exact AGW per-instance convergence time; whether gurobi
  public frontend is actually internet-reachable for a handshake; live import-format acceptance (OR-2,
  el-demoledor's lane).
- All findings are INFER until the coordinator source-verifies the cited file:line and doc surfaces.
