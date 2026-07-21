# SCORE 42/100

All 13 Bash fences pass `bash -n`. The third revision genuinely fixes the one-AVD-WSL execution boundary, concrete identifiers, external `sha256sum` instead of nonexistent jq `@sha256`, POSIX `sh -c` argument forwarding in `influx_exec`, token transport through stdin/files instead of `--value`/`--token`, invocation-versus-exception verification, Azure Key Vault `download --id --file` / `set --file` syntax, unquoted ISO `datetime(...)`, and the Flux `last(column:"_time")` ordering. The selector expression is syntactically valid. **Branch B is not actually fixed.**

## Itemized deductions

1. **BLOCKING — §5a / §6B / §7 / §8 (−14): Branch B cannot execute either outcome.** §5a routes a mismatch directly to §6B, so §6B's claim that the pod token “from §5b already 401s” is false. It tests only the KV token, not every distinct POD/K8S/KV candidate. On `200`, it tells the operator to “SKIP” the KV set inside §7, but the §7 block still expands undefined `NEW_TOKEN` and needs undefined `NEW_KV_HASH`. On `401`, it sends the operator to §6A even though §5c never initialized `INFLUX_TOKEN` or `BUCKETID`. Branch B then reaches §8 with no `INFLUX_TOKEN` for `influx_exec query`. Under `set -u`, these are deterministic aborts. **Fix:** make §6B a complete branch: probe all distinct candidates; run §5c before any mint/query path; for accepted-KV delivery repair set `NEW_KV_HASH="$KV_HASH"`, skip the entire checkpoint/set sub-block explicitly, roll, and initialize a working admin `INFLUX_TOKEN` before §8.

2. **BLOCKING — §5c lines 213–215 (−9): the C1 auth-hash loop still trips `errexit`.** The loop body ends in `[ hash = "$POD_HASH" ] && echo "$id"`. If a row does not match—or a matching row is followed by a nonmatching row—the loop/pipeline returns 1, the `OLD_AUTH_ID=$(...)` assignment returns 1, and Bash exits before the `case`. A synthetic Bash run reproduced exit 1 for both cases. **Fix:** use an `if ...; then printf '%s\n' "$id"; fi` body so “no match” is data, while `pipefail` still propagates real `influx`/jq failures.

3. **HIGH — §5c lines 205–231 (−6): success output does not support the documented branch decision.** The code resolves only `OLD_AUTH_ID`; it neither prints a decision record nor checks/prints the matched authorization's `status` and bucket-write permission. The operator cannot read “absent/inactive” versus “present and write-scoped” from the output, yet the prose requires that distinction. **Fix:** parse and print exactly one row containing auth ID, status, and permissions, then emit one explicit terminal such as `DECISION=BRANCH_A` or `DECISION=STOP_3_ADJACENT`.

4. **BLOCKING — §5c-pw lines 223–229 (−8): the admin-password UI branch stalls at the first credential.** `az ... -o tsv | { read -rs P; echo ...; }` consumes the password into a pipeline subshell, prints nothing, discards `P`, and leaves nothing the operator can paste into the UI. The subsequent prose gives no paste-ready shell commands for capturing the UI-created write token and admin token, and never sets `NEW_AUTH_ID`; the partial-roll instruction later expands that variable under `set -u`. The port-forward is also not health-checked. **Fix:** verify `kill -0 "$PF_PID"` plus a local readiness probe, copy the password to the Windows clipboard via stdin (or provide an equivalent no-stdout mechanism), provide exact hidden `read -rsp` commands for `NEW_TOKEN` and `INFLUX_TOKEN`, capture `NEW_AUTH_ID`, validate all three as nonempty, then emit `DECISION=APPLY_UI_TOKEN`.

5. **HIGH — §5a/§5b lines 178–198 (−5): diagnosis hard-codes `deploy/strikepricefn` after §4 discovered a writer set.** A stale or failing `-b2b`, `-b2c`, or telemetry writer can be the affected instance while the hard-coded deployment hashes/probes clean, producing the wrong `200 → escalate` branch. `POD_HASH` also represents only one writer when C1 tries to identify the old auth. **Fix:** run the byte hash and origin probe for every affected writer/pod (or map the App Insights failing `cloud_RoleInstance` to its deployment), require a consistent candidate token before repair, and print a per-writer decision table.

6. **HIGH — §7 lines 265–286 (−5): rollback is not end-to-end and can leave secret material.** The EXIT trap restores KV after a mid-loop failure but does not roll already-restarted deployments back onto the restored token, leaving mixed pod credentials. If `az keyvault secret set --file "$NEWF"` fails, `set -e` exits before `rm -f "$NEWF"`, and cleanup does not know `NEWF`, leaving the new token in a temp file. **Fix:** register `NEWF` in cleanup before writing it; track successfully rolled deployments; on failure restore KV, re-roll that tracked set to the old hash, verify it, and only then consider inactivating the unused new auth.

7. **HIGH — §8 lines 293–302 (−4): pod discovery can fail or return zero and verification silently skips the writer.** Bash `mapfile -t PODS < <(producer)` returns 0 even when the process-substitution producer fails; this was reproduced with modern Bash. There is no nonempty/cardinality check before the inner loop. The section can therefore print no result for a writer and still continue to a successful aggregate Flux query. **Fix:** capture the `oc | jq` output in an assignment whose status carries `pipefail`, populate `PODS`, require at least one Ready nonterminating pod per deployment, and print `UNKNOWN/STOP` when zero.

8. **MEDIUM — §3 line 144 (−3): the “already fixed” and “not reproducing” branches jump to §8 before its state exists.** At that point `WRITERS`, `INFLUXPOD`, and `INFLUX_TOKEN` have not been initialized; direct execution of §8 aborts under `set -u`. **Fix:** route through the read-only discovery/admin setup needed by §8, or provide a self-contained baseline-only verification block that does not depend on later mutation state.

9. **MEDIUM — §4 lines 159–170 (−2): non-Deployment writers are a human improvisation branch.** The command can print CronJobs, StatefulSets, or Jobs, but the runbook says to add them to a “mental” list and handle them “by hand”; §§7–8 iterate only Deployment names. Preflight also does not check list/get permissions for these kinds. **Fix:** either fail closed and escalate when any are found, or build typed arrays with concrete restart/exercise/verify commands and matching RBAC checks.

10. **MEDIUM — §5b lines 191–198 (−2): C3 cannot expose one of its own decision signals.** The pod-shell syntax and saved curl status are now correct, but the response body is written to `$b` and deleted without display. The operator is told to identify an “HTML challenge” that the block never shows. **Fix:** print a bounded, redacted body/content-type diagnostic before deletion, or remove HTML-body inspection from the decision and rely on explicit headers.

## To reach 100

- Replace §6B with a self-contained, variable-complete state machine; never instruct the operator to edit/skip lines inside the §7 block.
- Fix the C1 loop's no-match exit status and make §5c print auth status, permission, and a single explicit branch token.
- Make §5c-pw executable: verified tunnel, usable password transfer, exact hidden token reads, `NEW_AUTH_ID`, and validation.
- Diagnose the actual affected writer(s), not only `deploy/strikepricefn`.
- Make rollback restore both KV and every already-rolled workload; clean every token temp file on every exit.
- Turn every process-substitution array into checked producer output and reject zero Ready pods.
- Remove premature §3→§8 jumps or initialize all §8 prerequisites first.
- Either automate non-Deployment writers or stop explicitly when discovered.
- Expose every signal named in a decision, including the C3 HTML/body signal.
- Re-run `bash -n` plus branch simulations for: C1 no match/match-not-last, Branch B KV-200/KV-401, §5c-pw, §7 mid-roll failure, and §8 zero-pod/producer-failure.

## Verdict

**NOT EXECUTION-READY / NO-GO for start-to-finish human on-call use.** The main command syntax is materially improved, but common diagnosis paths still deterministically abort under strict mode, Branch B remains incomplete, and the password fallback cannot supply its first UI credential. A human would have to rewrite commands and invent state transitions during the incident.
