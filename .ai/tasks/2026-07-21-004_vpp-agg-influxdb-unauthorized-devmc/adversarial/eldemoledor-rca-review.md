---
title: "El Demoledor — adversarial demolition of RCA + fix shape (Rec0BJKDCC4CT)"
type: review
status: complete
timestamp: 2026-07-21T15:55:00Z
task_id: 2026-07-21-004
agent: el-demoledor
reviewer_frame: adversarial (break the diagnosis + the fix)
target: rca.md + explanation.md (Part 4 fix shape)
verdict: conditional
verdict_label: PROCEED-WITH-CHANGES
summary: Diagnosis is sound and unusually well-hedged. The FIX PACKAGE breaks — the operational runbook it defers to does not exist, and the verification method is variant-blind (false-close). 3 must-fix before any engineer executes.
---

# El Demoledor — RCA + fix demolition

**Target:** holistic RCA (`rca.md`) and its fix shape (`explanation.md` Part 4 / RCA L8+L11+L12).
**Win condition:** find a path where following this package yields a WRONG diagnosis, a BROKEN system, or a FALSE "fixed." Found several. The diagnosis survives hard; the **fix package does not**.

## Destruction summary

| Metric | Count |
|--------|-------|
| Findings | 11 |
| — BLOCKING | 1 |
| — HIGH | 2 |
| — MEDIUM | 5 |
| — LOW | 3 |
| Genuinely-safe steps confirmed | 8 |

The RCA authors already absorbed 4 prior adversarial reviews and hedged well (multi-hypothesis, HALT gates, create-before-revoke, verify-by-effect). So the cheap breaks are gone. The breaks that remain are **structural** (a runbook that isn't there) and **method-level** (a verification signal that cannot see what it claims to check).

---

## Findings table

| # | Sev | Location | Failure scenario (concrete) | Consequence | Correction |
|---|-----|----------|------------------------------|-------------|------------|
| F1 | **BLOCKING** | RCA L8 line 164, L12 line 244; explanation Part 4 line 216; receipts #2/#3/#15/#16 all DEFER to `how-to-fix.md` | The whole package points the next-shift engineer to `how-to-fix.md` for the actual `oc` commands, the full credential byte-check procedure, the AVD entry, the full verification gate, and the "first-10-min handover." **That file does not exist in the incident directory** (`ls` shows: antecedents, context, explanation.md, output, proofs, rca.md, requirements.md, reviews, slack-intake.md — no `how-to-fix.md`, no `fix.md`). | 3am engineer clicks the runbook link → missing file → is left with only the "shape" and must **improvise** the dangerous in-AVD steps (mint token, roll b2b/b2c, revoke old token) with no safety-gated procedure. This is exactly where early-revoke / wrong-roll / data-loss happens. The findings the prior reviewers marked BLOCKING (#2 byte-check, #3 prove-sync-before-restart, #16 verification gate) were "RESOLVED" only by DEFERRING them into this non-existent file — so those blocking mitigations effectively do not exist in a runnable form. | Write `how-to-fix.md` (or fold the deferred procedures back into the RCA) BEFORE this package is handed to a shift. Until then the fix is non-actionable. |
| F2 | **HIGH** | RCA L9 line 185; explanation Part 4 step 5 line 232 ("group App Insights by role/variant — check b2b AND b2c") vs E1 (`cloud_RoleName = strikepricefn`, single) + §3.6 line 194/198 ("role telemetry not split") | The primary verification signal is "a scheduled run with **no new UnauthorizedException**, grouped by variant." But the evidence itself establishes **both b2b and b2c emit the same `cloud_RoleName = strikepricefn`** and App Insights telemetry is **not split by variant**. So you literally cannot ask "did b2c recover?" from this signal. | Fix b2b, restart it, see "no `strikepricefn` 401 in the last window" → close the ticket → **b2c is still 401ing** (or simply hasn't fired its 15-min timer yet) and silently keeps dropping points. False-close. | Find a variant discriminator before verifying: `cloud_RoleInstance` / pod name / `appId` / image tag / a distinct env label per variant. If none exists in telemetry, the runbook MUST verify each variant by a **direct per-pod** check (App Insights filtered by `cloud_RoleInstance`, or pod-side log), not by "no `strikepricefn` 401." |
| F3 | **HIGH** | explanation Part 4 step 1 line 223 (authenticate with `influxdb-admin-token` to inspect/mint); RCA L8 step 1 line 169 | The LEADING hypothesis is "org/user/**instance re-initialised**" (H1/H3). If the instance/org was re-initialised, the **admin token** (`influxdb-admin-token`, updated 2025-03-11 — same vintage as the write token) is **also orphaned** and `influx auth list` authenticated with it **also returns 401**. The decision tree has **no branch** for "cannot even authenticate to inspect." | Engineer runs the inspect step, gets 401 on the admin token too, and either (a) loops / stalls, or (b) misroutes to "network/DNS" (H6) and wastes the shift, or (c) wrongly concludes the fix failed. In reality **admin-token-also-401 is the strongest possible confirmation of instance re-init** and should route straight to admin-**password** UI login + the H3 HALT/escalate path. | Add explicit branch: "If the admin **token** also 401s → the instance/org was re-initialised → authenticate via `influxdb-admin-password` (UI/basic) instead; if that also fails or org/bucket are gone → H3 HALT + escalate." |
| F4 | MEDIUM | RCA L3 line 103/105 + §3.5 H6 line 189 ("we received a 401 → the service answered") | The RCA equates "client threw `UnauthorizedException` (HTTP 401)" with "**InfluxDB** issued the 401." The write target is a plain-HTTP in-cluster service; if an OpenShift **oauth-proxy / service-mesh (Istio/OSSM) authz sidecar / ingress** fronts it, a **mesh authz-policy change ~1 month ago** produces an identical client-side 401 that **InfluxDB never saw**. The C# client throws `UnauthorizedException` on any 401 regardless of origin. | Engineer rotates the InfluxDB token (F1/F3 path), the mesh still rejects, writes still 401 — "fix" appears to fail for no reason, or worse, a valid token is minted and the real cause (mesh/proxy) is never found. Misdiagnosis. | Add a discriminator probe: confirm the 401 originates from InfluxDB (response body/`WWW-Authenticate`/server header, or curl the pod → service directly in-AVD) BEFORE touching the token. If a proxy/mesh sits in front, the whole token hypothesis is off-path. |
| F5 | MEDIUM | RCA L9 signal 2 line 185; explanation Part 4 step 5 bullet 2 line 232 | "At least one scheduled 15-min invocation runs with **no new UnauthorizedException**" false-passes when that invocation had **no strike-price points to publish** (empty Kafka window / no data) — `WritePointsAsync` is called with nothing (or skipped), so there is **no write and no 401**, and it reads as recovered. | Ticket closed on a window where the pod never actually wrote to InfluxDB with the new token. Next real write could still fail (e.g. scope/mesh). False-pass. | Require an **observed successful WRITE by the scheduled pod** (fresh point attributable to the pod appearing in the bucket), not merely absence of an exception. Signal 1 (manual mint-token write) proves the token, not the pod's delivery path. |
| F6 | MEDIUM | explanation Part 4 step 1 line 223 / L12 line 243 (`influx auth list`) | `influx auth list` prints the **token strings** to the AVD terminal/scrollback by default. This is the recommended inspection command, and it is deferred to the (missing) runbook. | Live write/admin tokens land in the AVD session scrollback / any screen-share / terminal history — credential exposure, contradicting the package's own "never print the token" rule. | Instruct `influx auth list --hide-headers` is NOT enough; use ID-only listing / compare by token **ID** and one-way hash, never display the token column; or pipe to a hash. Call this out explicitly in the runbook. |
| F7 | MEDIUM | RCA L11 line 222 + E5 line 48 (add IP to `vpp-agg-appsec-d` firewall, "added + removed") | The reproduction path bakes a **security-control mutation** into the steps: add your workstation IP to the firewalled vault's allowlist, then remember to remove it. Cleanup is asserted per this run but the runbook makes it a manual, easily-skipped step. | Stray allowlist entries accumulate on a Deny-by-default app-secret vault across shifts → widening the exposure surface of the KV holding admin + write + Grafana tokens. Silent security drift. | Make firewall-removal a **verified** step (re-query `networkAcls.ipRules` after, assert your IP absent) or route KV access through the sanctioned MC connect flow / a jump host that is already allowlisted, rather than per-engineer IP adds. |
| F8 | MEDIUM | evidence E8 line 78 ("b2b + b2c" labelled A1) vs shown probe reading only `strikepricefn/dev/values.yaml` | The roll-list is hardcoded to exactly **b2b + b2c**, but the probe cited reads a single `dev/values.yaml`; the actual deployment set and **which writers share `influxdb-api-token`** is A3 (§3.6 admits "other writers A3"). | A third writer (telemetry/data-ingestion fn) sharing the secret is left un-rolled → keeps 401ing after the "fix," or (if you revoke the old token per step 5) a **still-running third writer using the old token now breaks** that was previously fine — a fix-induced regression. | Before revoke: enumerate ALL k8s workloads whose env resolves from `influxdb-api-token` (in-AVD) and roll every one. Do not hardcode "b2b+b2c." The revoke step is the data-loss trigger for any un-enumerated writer. |
| F9 | LOW | RCA E8/E10; explanation ledger #10 line 259 ("A1 product behaviour") | "InfluxDB 2.x tokens don't expire by default" is labelled **A1** but for THIS instance it is a product-default INFER — the instance was never probed for an explicitly-set optional expiry. Hedged elsewhere, but the A1 label overstates it. | If someone HAD set an optional expiry on this token (Cloud/newer builds), the "reject expired" reasoning is locally wrong. Low, because self-managed OSS + KV has no expiry. | Downgrade to A2 for this-instance; the in-AVD `influx auth list` confirms real token state anyway. |
| F10 | LOW | RCA L11 line 207 query vs E1 line 20 query | The repro's App Insights filter (`innermostMessage has 'unauthorized' or outerMessage has 'InfluxDb'`) is narrower/different from the E1 query that actually captured the 12 exceptions. Field-name drift (`innermostMessage` vs the wrapped `RpcException`) could return **zero rows**. | Engineer runs the repro, gets zero rows, reads it as "recovered / not happening" when it is a query mismatch, not a recovery. | Use the exact E1 query shape (match on the `UnauthorizedException` type across `outerMessage`/`innermostMessage`) and state the expected non-zero baseline. |
| F11 | LOW | RCA L1 line 72; explanation §2.1 line 98 ("monitoring only, severity low") | "Monitoring-only, low severity" assumes **no automated consumer** (alerting, SLA/regulatory reporting, billing reconciliation) reads the InfluxDB/Grafana `aggregation` data. Asserted from ADR AL010, not probed. | A month of missing data feeding a downstream automated report/alert would make the true severity higher than "annoying." | One-line check: does anything besides human dashboards read the `aggregation` bucket / Grafana panel? If yes, re-rank. |

---

## Inherited claims passed through without in-session probe

- **"Reviewed by 4 independent adversarial reviewers"** (explanation.md line 6): the receipts show those 4 (omp/GPT-5.6) audited **`explanation.md` only**, not `rca.md`, and their BLOCKING fixes (#2 byte-check, #3 prove-sync, #15 handover, #16 verification gate) were dispositioned by **DEFERRING to `how-to-fix.md`** — the file that does not exist (F1). So the "reviewed / blocking-resolved" status **overstates coverage**: the fix runbook was never written, therefore never reviewed. Treat the fix package as **un-reviewed** until F1 is closed.
- **b2b/b2c as A1** (F8) — asserted, not fully probed.
- **KV→k8s sync mechanism** — correctly kept A3; not laundered. Good.

---

## Genuinely-safe steps (confirmed, briefly)

1. **Reject "expired token"** — solidly grounded (E6 no-expiry + enabled, startup-validation would fail on empty, 401≠403 semantics). Survives attack.
2. **Create-before-revoke**, revoke old token by confirmed ID only after all gates — correct, avoids self-inflicted outage.
3. **HALT if org/bucket absent; never recreate org/bucket/collection** — correct data-loss guard; keeps the `Rec0BGG7SPERE` stateful action out of scope.
4. **Byte-check credential chain (length+hash, no value) before minting** — correct ordering (shape is right; the *procedure* is the F1 gap).
5. **Order: update KV → prove k8s Secret re-synced → restart** — correctly defeats the "restart reloads old token" trap.
6. **Do not reuse admin token as the writer; least-privilege write-only token** — correct.
7. **Verify by effect, not exit code** — correct principle (but see F2/F5 for the holes in the *specific* signals).
8. **No token values printed in the Azure-plane L11 commands** (metadata-only KV query) — correct (the exposure risk F6 is in the in-AVD `influx` step only).

---

## Top 3 must-fix

1. **F1 (BLOCKING) — the `how-to-fix.md` runbook does not exist.** Every dangerous in-AVD step and every "resolved-by-defer" blocking mitigation lives in a missing file. Write it (or inline the deferred procedures) before any engineer touches the fix. As linked today, executing the fix = improvising the data-loss-adjacent steps.
2. **F2 (HIGH) — variant-blind verification false-closes the ticket.** L9/step-5 say "check b2b and b2c" but telemetry cannot distinguish them (`cloud_RoleName=strikepricefn` for both). Add a real per-variant discriminator or verify per-pod; otherwise a half-fix reads green.
3. **F3 (HIGH) — no branch for "admin token is also orphaned."** The leading hypothesis (instance re-init) orphans the admin token too, so the very first inspect/mint step can 401 with no defined next move. Add the admin-password fallback + treat admin-401 as confirmation of re-init → H3 HALT path.

(Close seconds worth doing in the same pass: F4 proxy/mesh-as-401-source, F8 enumerate-all-writers-before-revoke.)

---

## Verdict

**PROCEED-WITH-CHANGES.**

- The **diagnosis** (`rca.md` + explanation §0–3) is sound, well-evidenced, and honestly hedged — it does not overclaim the root cause, correctly demotes "expired," and keeps the AVD-blocked state as `A3`. It survives adversarial attack.
- The **fix package** does **not** pass as-is: it depends on a runbook that isn't there (F1), and its verification method cannot see the second variant it claims to check (F2), with a missing failure branch on the first action (F3).

If someone tries to **execute the fix today** by following the links, the honest grade is **REJECT** — because the linked procedure is absent and the close-criteria false-pass. Fix F1–F3 (min) and this becomes a safe PROCEED.

---
*El Demoledor: proving resilience through destruction.*
