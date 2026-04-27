---
task_id: 2026-04-26-001
agent: claude-code
status: complete
summary: Slack reply for #myriad-platform parent thread — final, sober, no pings on Stefan
---

# Slack reply — final

Channel: `#myriad-platform` (`C063SNM8PK5`), parent thread ts `1776781493.090009`.
Stefan on vacation since 2026-04-22 — do **not** @mention. No `<!channel>`, no `<!here>`.

---

## Message body

> Picked this back up after re-verifying live on Sandbox. Two corrections to the original framing:
>
> 1. The IaC fix was already merged on 2026-04-16 — PR 172400 ("Activation.mFRR API - Monitoring", Tiago) added `activation-mfrr` to `dispatcher-output-1.consumerGroups` in `sandbox.tfvars`. Stefan's local mirror was stale when the diagnosis was written, so it looked like the entry was missing in `origin/main`. It wasn't.
> 2. Apply on Stefan's pipeline run (`buildId=1616964`, 2026-04-21) was skipped because the `terraform-sandbox` Environment approval gate timed out at exactly 2 h — not because plan saw zero changes. Plan would have produced `+1 consumer_group + +1 storage_container`; nobody approved within the window.
>
> Runtime today (re-probed): `vpp-evh-premium-sbx/dispatcher-output-1` is missing CG `activation-mfrr`; `vppevhpremiumsb` is missing container `dispatcher-output-1-activation-mfrr`. The pod has been crashlooping on R147 the whole time. R145 still serves traffic so production was unaffected.
>
> Two paths to fix, pick one:
> - **Operational unblock now**: `az pipelines run --project "Myriad - VPP" --id 1413 --branch refs/heads/main`, then click Approve on the Apply stage within 2 h.
> - **Defensive PR (branch `fix/NOTICKET/mfrr-activation-crashloop`)**: adds a path-filtered `trigger:` to `terraform-cd-sandbox.pipeline.yaml` so future merges to main auto-queue a build instead of silently waiting for someone to remember. Approval gate intentionally untouched. Merging this PR also fixes the runtime as a side effect of the auto-triggered build.
>
> Full write-up + replication recipe in the ticket folder. Will hand to Core morning coverage if Apply still hasn't been approved by EOD.

---

## Style check (run before posting)

- [x] No banned phrases (`happy to help`, `let me know`, `hope this helps`, `feel free`, `please don't hesitate`).
- [x] No `<@stefan>` / no Stefan ping.
- [x] No `<!channel>` / `<!here>`.
- [x] No emojis.
- [x] Cites verifiable identifiers: PR 172400, buildId 1616964, branch name, pipeline id 1413.
- [x] Length ~250 words — slightly above the 150-word target because two corrections + two operational paths cannot fit shorter without losing falsifiability. Acceptable trade.

## Posting policy

Do not post automatically from this session. The on-call operator (Alex) decides whether to:

- post the full message above (recommended — Stefan's original framing was published in this thread, the correction belongs in the same thread for parity);
- post a shorter "fixed by `<commit>`" reply *after* the apply succeeds and runtime probes pass;
- DM Core morning coverage instead of public reply if it's after-hours and Apply is queued.
