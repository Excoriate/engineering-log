---
task_id: 2026-04-21-001
agent: socrates-contrarian
status: complete
summary: Adversarial review of the mFRR-Activation diagnosis — survives scrutiny, but with three named caveats that must be closed before ship (exact-name probe of App Config, CG+container byte-parity, and confirming old R145 pod is genuinely doing work not just idling).
---

# Adversarial Review — mFRR-Activation Crash Loop Diagnosis (Rec0AU7GAKAJH)

Reviewer: `socrates-contrarian` (independent, did not produce the diagnosis).
Target: `outcome/diagnosis.md` (the shippable artifact) against the evidence in `verification/enrich-results.md` and the prior adversarial pass in `plan/plan.md`.

## 1. Alternative hypotheses the coordinator may have prematurely ruled out

The mechanism chain in `outcome/diagnosis.md:31-52` is internally consistent, but it collapses to a single story (H1b = missing blob container + missing CG) faster than the evidence forces.

**Alt-H-A — "App Config itself is the bad actor (H3 config drift), not the missing resource."**
The diagnosis at `outcome/diagnosis.md:225` explicitly marks the R147 App Config CG name + target SA + container name as `[A3 UNVERIFIED[assumption]]` and calls it "the most important unknown." But the plan THEN proceeds on the inverse assumption — that R147 introduced a *new* CG/container pair that IaC must now declare. An equally valid read of the same evidence (`enrich-results.md` P5: `ContainerNotFound` with `consumerGroup` passed as a parameter, not a resolved name in the log line) is: **R147's App Config value is malformed, misconfigured, or points at the wrong storage account entirely** — e.g. a typo pushed by whoever owns the App Config keys for the R147 migration, or a missing App Config key causing the SDK to fall back to a default the operator never intended. If true, the fix is an App Config change (or a Core-team config rollback), not a Terraform PR. Probe that discriminates: read the exact App Config keys the R147 image reads (`EventHub:ConsumerGroup`, `Checkpoint:ContainerName`, `Checkpoint:StorageAccountUri` or equivalent). Without that read, the coordinator is solving the wrong problem if Alt-H-A is true.

**Alt-H-B — "The storage account itself (`savppdspbootstrapsb`) is the wrong target entirely."**
`enrich-results.md` P10 notes this SA was created 2026-04-20 14:49 UTC, less than 24h before the ticket. P11 shows it contains ONLY a `tfstate` container. The diagnosis treats this as the checkpoint SA — but the evidence for that identification is circumstantial ("dsp" = dispatching, recent provisioning near ticket time). Alternative read: `savppdspbootstrapsb` is a new Terragrunt state backend provisioned for an UNRELATED effort; R147's real checkpoint SA is somewhere else entirely (an existing account, or one that doesn't exist yet). Evidence exposing this: no probe in the matrix reads the R147 App Config's `StorageAccountUri` key or the R147 Helm chart values. The diagnosis admits this at `outcome/diagnosis.md:113` (`<target-checkpoint-SA>` is a placeholder in the IaC template). **If the coordinator guesses the wrong SA in the PR, the PR creates an orphan container and the pod keeps crashing.** This is a live silent-failure path, partially named at Step 4's falsifier (line 179) but not elevated to a blocker.

**Alt-H-C (less likely, worth naming) — "The crash is not config at all; it's a liveness/startup probe ordering bug in R147."**
Exit code 139 (SIGSEGV) is unusual for a managed .NET app failing on a missing Azure resource — the SDK throws managed `RequestFailedException`, which normally surfaces as exit 1 or a specific non-zero, not a native SIGSEGV. P6 captures exit 139. The diagnosis at `outcome/diagnosis.md:43` explicitly labels the exit-139 inference as `[INFER]`, but then walks past it. Counter-read: SIGSEGV suggests a native crash (CLR abnormal termination, JIT, native interop, or OOM via cgroup OOMKiller masquerading as 139). Probe that discriminates cheaply: `kubectl -n vpp describe pod ... | grep -iE "Reason|OOMKilled|lastState"`. If `lastState.terminated.reason == OOMKilled`, the story changes.

## 2. Attacking the fix plan (Step 1 → Step 6)

- **Ordering issue, Step 2 vs Step 3.** Step 2 drafts the Terraform PR with concrete resource names (`outcome/diagnosis.md:104-108`, container named `activationmfrr`). Step 3 verifies MI RBAC. This is backwards in at least one case: if the target SA in App Config is an account the MI has no RBAC on (and no RBAC can be granted for policy reasons), the container is irrelevant. The RBAC probe is cheaper than the PR; run it first.
- **Silent-fail in Step 2 — the convention assumption.** `outcome/diagnosis.md:111` asserts "SDK convention: container name = consumer group name." That is **convention, not guarantee.** The Azure SDK's `BlobCheckpointStore` takes a `BlobContainerClient` the caller constructs — the container name is whatever the caller passes. The diagnosis's own Q4 adversarial note (`plan/plan.md:242`) already flagged case-sensitivity but did not extend to "the container name might not be the CG name at all." If R147 passes a differently-named container, the PR creates orphans and the pod keeps crashing with the identical error — which the Step 4 falsifier on line 179 would catch loudly, but only *after* a merge+apply cycle.
- **Loud failure, Step 2 acceptance.** "Terraform plan shows exactly one `+` for the CG AND one `+` for the container, zero other changes" (line 120) is good. But there's no check that the target module/resource group/namespace the PR edits is actually the one that ArgoCD syncs for Sandbox `vpp` namespace. A PR against the wrong module applies cleanly and does nothing. Add: confirm the module path by reading an existing consumer-group declaration for `fleetoptimizer` (which enrich-results P8 confirms exists) and mirroring its location.
- **Rollback — Step 2 post-apply claim is sloppy.** Line 127: "`terraform destroy -target` on the two resources ... safe because the CG has no persistent state beyond the checkpoint blobs (which don't exist yet anyway)." True for the container. For the CG: destroying a CG on a live Event Hub evicts any active consumers on that CG immediately. The old R145 pod might be the consumer. If R145 is consuming via `$Default` (as diagnosis line 51 speculates) this is fine; if the speculation is wrong and R145 is consuming via a CG the PR touches, rollback drops production-Sandbox traffic. Speculation-based rollback safety ≠ verified rollback safety.
- **Acceptance criterion (Step 4, line 174) is genuinely discriminating, not tautological** — `PartitionInitializingAsync` is a positive SDK signal, not just an absence of error. This is the strongest part of the plan. Credit where due.
- **Step 5 (MC envs) is gated correctly** but the falsifier ("any non-Sandbox hit → escalate") is only meaningful if the operator actually runs all three env probes. There is no forcing function — the diagnosis trusts the operator. Suggest: make Step 5 a gate on Step 6 (ticket-close), not an optional appendix.
- **Step 1 (check buildId=1616964) is placed first but has no teeth** — the three outcomes S4.A / S4.B / S4.C branch correctly, but if the operator can't read the ADO UI (e.g. no permissions, pipeline retention cleared), there's no `[UNVERIFIED[blocked]]` fallback named. Default-to-S4.B from the plan (line 97) is *only* in the plan, not the outcome runbook.

## 3. The three highest-risk A1 FACT claims

**Claim #5 (`outcome/diagnosis.md:24`) — "Storage account `savppdspbootstrapsb` ... contains only a `tfstate` container. No checkpoint container."**
Risk: over-generalization. The FACT is precisely "this one SA has no checkpoint container." The LEAP is "therefore R147's checkpoint container is missing." Those are different claims. If R147 targets a different SA (Alt-H-B above), claim #5 is still factually correct but diagnostically irrelevant. The coordinator implicitly treats "missing container on this SA" as "missing container, period." Downgrade this to A2 INFER until the App Config value is read.

**Claim #2 (`outcome/diagnosis.md:21`) — "Exception: `ContainerNotFound` inside `BlobCheckpointStoreInternal.ListOwnershipAsync`."**
Risk: `--tail=300` captures the LATEST 300 lines. Crash-looping pods print the same exception on every restart; earlier, first-run exceptions (startup init, KV mount, App Config fetch) may have scrolled off. The "first-failing" class may differ from the "most-recent-failing" class. The plan originally identified pod log (F4) first-failing as the highest-information probe (`plan/plan.md:17`, bullet 6) — but `--tail=300` is not "first-failing." Cheapest improvement: `kubectl -n vpp logs <pod> --previous` on the earliest available container instance, or `--since=0s` with a log aggregator if one exists.

**Claim #6 (`outcome/diagnosis.md:25`) — "Deployment has no static CG/container env vars; reads from `vpp-appconfig-d` at runtime."**
Risk: this is inferred from the absence of those env vars in the Deployment spec. The *absence* of an env var does not prove where the config comes from — only that it's not in the K8s manifest. The service could read from a mounted config file (KV CSI injects 15 secret objects per P13), a baked-in appsettings.json, or even hardcoded fallback defaults. The coordinator never read the R147 image's config-resolution order. If the service uses a hardcoded default CG name when App Config is empty or unreachable, the entire "App Config drives config" story may be wrong. Downgrade to A2 INFER until the image's config path is confirmed with a Core team member.

## 4. Is ≈90% confidence defensible?

No — **70-75% is more honest**, because three of the most decision-critical facts (exact CG name, exact container name, exact target SA) are explicitly UNVERIFIED and the fix requires byte-exact matches on all three. The coordinator scored confidence on the mechanism (`ContainerNotFound` is really what's crashing the pod) at ~90%, which is reasonable, but **confidence in the fix** is weaker than confidence in the diagnosis, and the 90% elides that distinction. See the same issue surface at `outcome/diagnosis.md:225` — "This is the most important unknown" — written as residual risk, but not reflected in the headline number.

**Cheapest probe to raise or destroy confidence**: read the three App Config keys the R147 image uses (e.g. `az appconfig kv list --name vpp-appconfig-d --key "*activationmfrr*" -o table` with a filter, or `--key "EventHub:*"`). One command, read-only, no auth beyond what was already used in Phase 7. If the keys exist and their values are visible, the Step 2 PR can be written with byte-exact names and the case-sensitivity trap (Q6 in `plan/plan.md:256`) closes. If the keys *don't* exist, Alt-H-A (App Config itself is wrong) moves from hypothetical to leading. This single probe is worth more than anything else the operator could run and it is not in the runbook.

## 5. Framing-level check — "stuck rollout, not outage"

The coordinator's framing relies on one load-bearing claim: the old R145 ReplicaSet is "serving healthy" (`outcome/diagnosis.md:22`) and therefore production-Sandbox activation is working.

A hostile auditor would push back here. "Serving healthy" in the evidence means only: `Running`, `Ready: 1/1`, restartCount 0, uptime 12 days (P4, P7). **It does not prove the old pod is actually consuming from the Event Hub and producing activation output.** A pod can be `Ready 1/1` and silently idle — liveness/readiness probes in P6 are `/liveness` and `/readiness`, which typically check process aliveness and dependency wiring, not "am I actually processing messages." If R145's config points at a CG whose offset is now stale, or if R145 was quietly shifted to a consumer group that no longer exists (the R147 rollout might have deleted/renamed something), the old pod could be up-and-silent — and the Sandbox activation function is effectively down, just without a crash-loop signal.

This is not implausible: the diagnosis at `outcome/diagnosis.md:51` speculates R145 uses `$Default` + "a `$Default`-named container that exists elsewhere" — `$Default` is a shared consumer group, and multiple consumers on `$Default` compete for partition leases. If R147's attempted config touched `$Default`'s checkpoints (unlikely given the isolation model, but not proven), R145 could stall.

**Recommended framing correction**: the ticket remains P3/P4 DX-class ONLY IF Step 5 (pre-close) includes a positive-signal check on R145: does R145's log still show `PartitionInitializingAsync` or equivalent throughput signal in the last hour? If it doesn't, reclassify. One `kubectl logs` call on the R145 pod answers it.

## 6. Highest-impact recommendation (ONE)

**Before signing off on the ticket and opening the Terraform PR, read the R147 App Configuration values that the `activationmfrr` service resolves at startup, and pin them into `verification/r147-appconfig-values.md` as verbatim strings.** Specifically the keys that resolve to (a) consumer-group name, (b) checkpoint container name, (c) checkpoint storage account URI, (d) the key prefix filter the image uses when bootstrapping from App Config.

This one probe:
1. Converts three of the most critical A3 UNVERIFIED assumptions into A1 FACTs.
2. Discriminates Alt-H-A (App Config is the bad actor) from H1b (resources are genuinely missing) — they produce different App Config readings.
3. Eliminates the case-sensitivity silent-failure mode that Q6 of the prior adversarial pass only *guarded* against, by giving the PR author the exact strings to copy.
4. Reveals whether `savppdspbootstrapsb` is actually the target SA (discriminates Alt-H-B).
5. Is cheap, read-only, and uses the same auth path already in use.

It is absent from the current runbook. Step 2's PR template line 104 still admits `# most likely the CG name is activationmfrr following service-name convention` — that "most likely" is the gap this probe closes.

---

## Verdict

**Diagnosis survives scrutiny with the following caveats — do not ship the IaC PR until all three are closed:**

1. **Read the R147 App Config values before writing the PR.** (§6 above — highest impact.) The current plan enshrines a guess as a Terraform resource.
2. **Downgrade claims #5, #2, and #6 from A1 FACT to A2 INFER** (§3) and re-state headline confidence as ≈75% on the fix, separate from ≈90% on the crash mechanism.
3. **Add a positive-signal probe on the R145 pod** (§5) before accepting the "stuck rollout, not outage" framing — one `kubectl logs` call closes it. Without it, the "old pod is serving" claim is INFER dressed as FACT.

The mechanism story is sound. The fix as currently specified is under-evidenced at exactly the point where byte-exactness matters. Close the three caveats and the diagnosis ships. Ship it as-is and there is a real path where the PR merges, applies cleanly, and the pod keeps crash-looping with an identical-looking error — the worst outcome because it erodes operator trust in the runbook for the next ticket.
