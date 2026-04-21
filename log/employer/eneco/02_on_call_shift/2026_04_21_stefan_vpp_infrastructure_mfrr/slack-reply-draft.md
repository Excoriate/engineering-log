---
task_id: 2026-04-21-001
agent: claude-code
status: draft
summary: Draft Slack reply for #myriad-platform parent thread — NOT posted automatically
---

# Slack reply — DRAFT (do not auto-post)

Target: `#myriad-platform` (C063SNM8PK5), parent thread ts `1776781493.090009`.

Reporter (Stefan) is on vacation from 2026-04-22 for one week. Do NOT ping him. Route acknowledgements to Core team stand-in (Hein Leslie, R147 release master) if follow-up is needed.

---

## Draft (sober, no pleasantries, no "happy to help")

> Picking this up on-call. Small correction to the diagnosis that matters for the fix:
>
> The crash-loop is `Azure.RequestFailedException: ContainerNotFound` from `BlobCheckpointStoreInternal.ListOwnershipAsync` on Blob Storage — the missing entity is the **checkpoint blob container**, not the Event Hub consumer group itself (though the CG is also absent on `vpp-evh-sbx/iot-telemetry` — only `$Default` and `fleetoptimizer` exist). Both need to be created; by SDK convention the container name mirrors the CG name, so a single Terraform PR covers both.
>
> Current state on Sandbox:
> - R147 pre-release pod `activationmfrr-744ddb586c-*` is crash-looping (image `0.147.dev.9334f4a`, exit 139).
> - R145 ReplicaSet `activationmfrr-6778566c5f-*` is still Running (image `0.145.dev.fe1f3fa`), 0 restarts, 12 days uptime — so the activation function is still served on Sandbox through the old replica.
> - FBE namespaces (ionix/ishtar/kidu/veku) are healthy.
>
> What's needed:
> 1. Verify whether `buildId=1616964` declared both `azurerm_eventhub_consumer_group` + `azurerm_storage_container` in its Terraform plan. If yes and apply completed, a rollout restart should clear it. If no, a small PR against `VPP - Infrastructure` is needed (same shape as the Oct 2025 PR 144873 pattern).
> 2. Confirm the exact CG name the R147 image reads from `vpp-appconfig-d` — the IaC must match byte-exact (case-sensitive).
> 3. After the apply, `kubectl -n vpp rollout restart deployment/activationmfrr` and watch for `PartitionInitializingAsync` in the logs (positive signal, not just absence of error).
>
> Not a production incident — Sandbox only, R145 replica is carrying load. Leaving the ticket open; full runbook + evidence in the ticket folder.

---

## Style check (before posting)

- [ ] Banned phrases? none present ("happy to help", "let me know", "hope this helps", "feel free", "please don't hesitate" — all absent).
- [ ] Ping discipline? Stefan not mentioned. No `<@here>` or `<!channel>`.
- [ ] Register? Sober, colleague-to-colleague. No cheerfulness, no "quick update!" framing.
- [ ] Length? Long enough to carry the correction, short enough to scan in 30 seconds.
- [ ] Links? Not inlined (keeping the message thread-friendly); the `buildId=1616964` link is already in the ticket body.

## Posting policy

Do NOT post from this session automatically. The operator (Alex Torres, on-call) decides when and whether to post based on:
- Pipeline status (Step 1 runbook).
- Whether Core team (Hein/Artem/Alexandre) has already seen the ticket and is acting.
- Whether the fix can be completed within this on-call shift or will hand to morning coverage.

If pipeline `buildId=1616964` already handled it, a shorter "confirmed fixed by your pipeline trigger, details here" reply is more appropriate than the full correction above.
