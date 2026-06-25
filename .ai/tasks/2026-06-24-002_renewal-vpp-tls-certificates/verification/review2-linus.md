---
task_id: 2026-06-24-002
agent: linus-torvalds
timestamp: 2026-06-24T00:00:00Z
status: complete
summary: |
  Code-correctness + cross-artifact equivalence review of rotate_tls.go vs rotate_tls.py
  vs rotation-execution-spec.md. Toolchain clean (gofmt no-diff, go vet exit 0, py_compile
  exit 0). Resource identifiers all match ground-truth exactly; no KV-object/AGW-ssl-cert
  name confusion, correct RG/sub. The defer cleanup in runAll is correct (runs on every
  path, does not clobber the real error). ONE systemic reliability-class defect confirmed
  across BOTH Go and Python: the "empty-default" idiom (`if x=="" { x=<probe-want> }` /
  `or "<want>"`) turns a FAILED az query in EXECUTE mode into a PASSING probe at 7 sites in
  Go and 6 in Python. Highest-severity instance is whitelist-off residual check reporting
  firewall-clean on a failed query. Command equivalence Go==Py==spec holds for all steps.
---

# Review 2 — Linus: rotate_tls.go correctness + cross-artifact equivalence

## Key Findings

- **Finding 1** — FAILURE-MASKING (HIGH, systemic): discarded `az()` error + empty-default == probe-want makes a failed EXECUTE-mode query report PASS. 7 Go sites / 6 Py sites.
- **Finding 2** — Worst instance: `stepWhitelistOff` residual check (go:455/464, py:334/338) reports firewall-CLEAN when the residual query itself failed -> standing security exposure declared safe.
- **Finding 3** — Resource identifiers VERIFIED correct: sub/RG/KV/OBJ/AGW/SSL/VLESS all match ground-truth; no object-vs-ssl-cert confusion.
- **Finding 4** — Command equivalence VERIFIED: every step's az command (flags, `--query`, object vs ssl-cert names) matches across Go, Python, and the spec Manual mode.
- **Finding 5** — `defer` cleanup in `runAll` VERIFIED correct: whitelist-off runs on every return path and preserves the original error (only sets `err` if `err==nil`).

**Lane:** code correctness + taste; failure-masking hunt; Go==Python==spec command equivalence; resource-name correctness.
**Mode:** READ-ONLY. No Azure mutation. Local tooling only.
**Files (FACT, located on disk):**
- `.../2026_06_24_renewal_vpp_tls_certificates/rotate_tls.go` (551 lines)
- `.../rotate_tls.py` (401 lines)
- `.../rotation-execution-spec.md` (318 lines)

> Note: the user-provided paths (`.ai/tasks/.../`) did not contain these files. The actual
> artifacts live under `log/employer/eneco/02_on_call_shift/2026_june/2026_06_24_renewal_vpp_tls_certificates/`.
> Reviewed those (only copies of `rotate_tls.{go,py}` + `rotation-execution-spec.md` in the repo).

---

## Toolchain (VERIFIED — commands run, output captured)

| Tool | Command | Result |
|---|---|---|
| gofmt | `gofmt -l rotate_tls.go` | empty output, exit 0 — **already formatted, no diff** |
| go vet | `go vet ./rotate_tls.go` (go1.25.5) | exit 0 — **clean** |
| py_compile | `python3 -m py_compile rotate_tls.py` (3.14.6) | exit 0 — **compiles** |

No syntax/vet defects. The defects below are semantic and vet cannot see them.

---

## Verdict

**NEEDS WORK.** The structure is good — small probe-gated steps, safe-by-default dry-run,
guaranteed cleanup. Taste is fine. But there is one *systemic reliability defect* repeated
across ~7 sites that directly contradicts the file's own stated invariant ("a failed probe
returns an error and stops"). In EXECUTE mode, several probes cannot fail when the underlying
query fails — they report success. For a PROD TLS rotation that is exactly the class of bug
that ends in "the script said OK and the listener served a dead cert / the firewall stayed open."

---

## FINDING 1 — FAILURE-MASKING via discarded-error + empty-default (HIGH, systemic) [CODE-VERIFIED]

### Mechanism (the generator, not a local patch)

`az()` returns `("", err)` on command failure (go:95-101). EXECUTE-mode callers then do:

```go
x, _ := az(...)        // error DISCARDED
if x == "" { x = D }   // D substitutes a value
return expect("...", x, W)  // probe
```

When `D == W` (the default equals what the probe wants), a **failed az query is laundered into a PASSING probe**. The discarded `_` is half the bug; the `default == want` is the other half. Python has the identical shape with `az([...]) or "<D>"`.

This is not 13 independent bugs. It is **one reasoning defect** — "treat empty output as the benign value" — applied uniformly, including where the benign value is the success value.

### Discriminator applied to every site

A site is DANGEROUS iff `default == probe.want` (failed query -> PASS).
A site is SAFE iff `default != probe.want` (failed query -> the probe still FAILS, correct direction) or there is no probe on the value.

**DANGEROUS (default == want -> masks failure):**

| # | Go | Python | Step | Default | Probe wants | Effect when query fails in EXECUTE |
|---|---|---|---|---|---|---|
| 1a | `ipRuleCount` go:242 (`""->"0"`), consumed go:455/464 | py:183 (`or "0"`), consumed py:334/338 | whitelist-off | `"0"` | `"0"` | **Firewall residual check reports CLEAN. Vault may be left open; script says safe. WORST instance.** |
| 1b | go:349 (`en==""->"false"`) | py:251 (`or "false"`) | import | `"false"` | `"false"` | Failed "is new version disabled?" read -> PASS. Gate-before-exposure invariant unproven but reported proven. |
| 1c | go:375 (`en==""->"true"`) | py:275 (`or "true"`) | enable | `"true"` | `"true"` | Failed "is new version enabled?" read -> PASS. |
| 1d | go:384 (`latest==""->want`) | py:279 (`or st.get(new_thumb)`) | enable | `new_thumb` | `new_thumb` | Failed latest-thumbprint read -> PASS. "versionless resolves to NEW" claimed without proof. |
| 1e | go:407 (`state==""->"Succeeded"`) | py:295 (`or "Succeeded"`) | refresh | `"Succeeded"` | `"Succeeded"` | Failed AGW health read -> "AGW healthy" reported. A genuinely Failed gateway can be masked. |
| 1f | go:415 (`kvsid==""->VLESS`) | py:299 (`or VLESS`) | refresh | `VLESS` (ends `/secrets/OBJ`) | suffix `SECRETPATH` | Failed ssl-cert read -> "restored to versionless" reported. Possible silent terraform drift / autorotation off. |
| 1g | go:485 (`kvsid==""->oldSid`) | py:354 (`or old_sid`) | rollback | `oldSid` | `oldSid` | Failed ssl-cert read during EMERGENCY rollback -> "points at OLD sid" reported. Worst possible time to lie. |
| 1h | go:492 (`en==""->"false"`) | py:358 (`or "false"`) | rollback | `"false"` | `"false"` | Failed "new version disabled?" read -> PASS during rollback. |

**SAFE (verified non-masking — keep, but see note):**

| Go | Why safe |
|---|---|
| go:295 `sid==""->"<OLD_SID>"` | probe go:311 checks `Contains(sid, "/secrets/OBJ/")`; `<OLD_SID>` does NOT contain it -> probe FAILS correctly. |
| go:300 `thumb==""->"<OLD_THUMB>"` | only logged/stored, no probe asserts thumb directly. |
| go:433 `s==""` (verify-effect) | handled explicitly: logs "unreachable - MUST verify from AVD", never a false PASS. |
| go:447 `ip==""->getIP()` | fallback to re-resolve IP, not a probe value. Fine. |

### Why this is real and not Linus-reflex (steelman + survival)

**Steelman:** "In dry-run, `az()` returns `""` by design, so these defaults exist to make the dry-run print sensible probe expectations rather than blow up." That is true and correct *for dry-run*. The defaults ARE needed for the `dry` path.

**Why I still flag it:** the defaults are not guarded by `dry`. They apply in EXECUTE too. Look at go:460-463 — the author *knew* the dry/execute distinction matters for the residual probe and special-cased `got` with `if !dry`. That same discipline is missing at 1b-1h. The `expect()`/`expectTrue()` helpers already short-circuit on `dry` (go:119, go:132) and return nil — so in dry-run the `got` value is never compared anyway. **That means the empty-defaults are not even needed for dry-run correctness** — `expect` ignores `got` when `dry`. The defaults only ever change behavior in EXECUTE, and there they mask failures. This survives the steelman.

**Counter-evidence that would retract this:** if `az()` were changed to never return `""` on failure (e.g. it already `os.Exit`s), the masking could not occur. It does not — it returns `("", err)` and the caller discards `err`. Confirmed go:99-101.

### Conditional fix (one fix for the whole class)

The probe helpers already no-op in dry-run. So the defaults are pure liability. Two options:

**Option A (smallest, preferred) — stop discarding the error; let a failed query fail the probe.**

```go
// instead of:  en, _ := az(...); if en == "" { en = "false" }
en, err := az("keyvault", "certificate", "show", ..., "--query", "attributes.enabled", "-o", "tsv")
if err != nil {
    return err            // a failed query STOPS, as the header promises
}
return expect("new version is DISABLED after import", en, "false")
```

This deletes the empty-default lines entirely (negative line count) and makes the header's
claim true. In dry-run, `az()` returns `("", nil)` and `expect` still no-ops on `dry` — so
dry-run output is unchanged.

For Python, drop the `or "<want>"` and let `az()` raise (it already does on non-zero unless
`allow_fail=True`):

```python
got = az([...,"--query","attributes.enabled","-o","tsv"])  # raises on failure
expect("new version is DISABLED after import", got, "false")
```

**Option B (if you insist on keeping a default for log readability)** — make the default the
*failing* sentinel, never the wanted value:

```go
if en == "" { en = "<QUERY-FAILED>" }   // can never == "false"/"true" -> probe fails loudly
```

Option A is correct taste: the probe failing on a failed query is the *entire point* of a probe.

**Special note on 1a (whitelist-off):** even with Option A, keep the existing
go:456-459 "remove manually" warning — that operator hint is good. Just make `ipRuleCount`
propagate the query error so the probe at go:464 fails instead of reading `"0"`.

---

## FINDING 2 — `azAllow` swallows errors by design; acceptable but document the asymmetry [CODE-VERIFIED, LOW]

`azAllow` (go:105-114) runs the network-rule *remove* and ignores failure (`_ = cmd.Run()`).
That is correct — remove is idempotent and may legitimately "fail" if the rule is already gone.
The *safety* comes from the subsequent `ipRuleCount` probe, NOT from the remove succeeding.
That design is sound **only if Finding 1a is fixed** — otherwise the one thing that makes
`azAllow`'s fire-and-forget safe (the residual probe) is itself blind. Fix 1a and this is fine.
Python mirror: `allow_fail=True` at py:332 — same contract, same dependency on the probe. Equivalent.

---

## FINDING 3 — `defer` cleanup in runAll: CORRECT [CODE-VERIFIED]

The user asked specifically: does whitelist-off truly run on every path, and does it clobber
the real error?

```go
func runAll() (err error) {                       // named return
    if err = stepPreflight(); err != nil { return err }   // BEFORE defer registered
    defer func() {
        if ce := stepWhitelistOff(); ce != nil && err == nil {
            err = ce                              // only overwrites if err is nil
        }
    }()
    for _, s := range []func() error{...} {
        if err = s(); err != nil { return err }
    }
    return nil
}
```

- **Runs on every path after registration:** yes — Go runs deferred funcs on any return,
  including the `return err` inside the loop and the panic path. (Preflight is intentionally
  before the defer: nothing was mutated yet, so there is nothing to clean up if preflight fails.
  Correct scoping.)
- **Does it clobber the real error?** No. The guard `ce != nil && err == nil` means a
  cleanup error only surfaces when the sequence otherwise succeeded. A mid-run step failure
  (`err != nil`) is preserved; cleanup still *runs* but its error is not allowed to mask the
  real cause. This is exactly the right precedence (real failure > cleanup failure).
- **Equivalence to Python:** py:366-376 uses `try/.../finally: step_whitelist_off()`. Behaviorally
  equivalent for the success and cleanup-fails cases. **One subtle divergence:** Python's
  `finally` does NOT have the `err == nil` guard — if both the body AND `step_whitelist_off`
  raise, Python propagates the `finally`'s exception and *discards the original* (standard
  Python semantics). Go preserves the original. So under the rare "step failed AND cleanup
  failed" case, Go surfaces the root cause and Python surfaces the cleanup error.
  [SEVERITY: LOW] — both still stop non-zero, but Go's diagnostic is better. Optional: wrap
  Python's `step_whitelist_off()` in the `finally` with its own try/except that logs but does
  not raise, to match Go. Not a reliability defect, a diagnostics nicety.

Verdict on the cleanup question the user raised: **the Go defer is correct on both counts.**

---

## FINDING 4 — Command equivalence Go == Python == spec: VERIFIED [CODE-VERIFIED]

Compared each step's az invocation across all three artifacts (flags, `--query` expression,
`-o` format, and object-name vs ssl-cert-name). Result: **equivalent on every step.**

| Step | Go line | Py line | Spec line | Match |
|---|---|---|---|---|
| login probe `account show --query id -o tsv` | 235 | 178 | 114 | == |
| whitelist add `network-rule add ... --ip-address IP/32 -o none` | 278 | 209 | 128 | == |
| whitelist probe `keyvault show ... length(networkAcls.ipRules[?value=='IP/32'])` | 240 | 182 | 134/276 | == |
| baseline sid `certificate show --query sid -o tsv` | 294 | 221 | 149 | == |
| baseline thumb `... x509ThumbprintHex ... | lower` | 298 | 223 | 150 | == |
| baseline enabled `... attributes.enabled` | 303 | 225 | 157 | == |
| import `certificate import --file PFX --password ** --disabled -o json` | 326 | 239 | 171 | == |
| import probe `... --version VER --query attributes.enabled` | 348 | 250 | 181 | == |
| verify-import (thumbprint compare, local openssl) | 357/361 | 258/263 | 195/196 | == |
| enable `set-attributes --version VER --enabled true` | 370 | 271 | 210 | == |
| enable probe latest `... x509ThumbprintHex` | 381 | 278 | 217 | == |
| refresh toggle->NEW_SID then ->VLESS `ssl-cert update --key-vault-secret-id` | 396/401 | 287/290 | 231/232 | == |
| refresh probe `application-gateway show --query provisioningState` + `ssl-cert show --query keyVaultSecretId` | 406/413 | 294/298 | 238/239 | == |
| verify-effect `openssl s_client ... | x509 -noout -enddate -fingerprint -sha1` | 425 | 307 | 254 | == |
| whitelist-off `network-rule remove ... -o none` | 453 | 331 | 270 | == |
| rollback `ssl-cert update --key-vault-secret-id OLD_SID` + `set-attributes --enabled false` | 474/478 | 347/349 | 290/291 | == |

No flag drift, no `--query` drift, no object/ssl-cert swap. The Manual commands in the spec
are the same commands the code runs.

---

## FINDING 5 — Resource-name correctness: VERIFIED [CODE-VERIFIED]

All constants match the provided ground-truth byte-for-byte, and the KV-object vs
AGW-ssl-cert distinction is respected everywhere:

| Constant | Code value (go:38-45 / py:47-54) | Ground truth | Match |
|---|---|---|---|
| SUB | `f007df01-9295-491c-b0e9-e3981f2df0b0` | same | == |
| RG | `mcprd-rg-vpp-p-res` | same | == |
| KV | `vpp-appsec-p` | same | == |
| OBJ (KV cert object) | `wildcard-vpp-eneco-com` | same | == |
| AGW | `vpp-ag-p` | same | == |
| SSL (AGW ssl-cert resource) | `wildcard-vpp-frontend-https` | same | == |
| VLESS | `https://vpp-appsec-p.vault.azure.net/secrets/wildcard-vpp-eneco-com` | same | == |

- `keyvault certificate ...` calls always use `--name OBJ` (go:294/298/303/326/348/370/374/381/478/491). Never SSL. Correct.
- `application-gateway ssl-cert ...` calls always use `-n SSL` (go:396/401/413/474/483). Never OBJ. Correct.
- `VLESS`/`SECRETPATH` are composed from `KV`+`OBJ` (go:44-45), so the versionless URI embeds
  the KV **object** name (`/secrets/wildcard-vpp-eneco-com`) — which is correct: the secret path
  uses the object name, while the gateway resource is addressed separately by `-n SSL`. No confusion.

This is the single most dangerous confusion class for this task (object vs ssl-cert) and the
code gets it right in all paths including rollback.

---

## Taste notes (non-blocking)

- Go and Python are genuinely behaviorally aligned in structure, step order (`STEPS`/`steps`
  maps identical keys), redaction, state file, and probe semantics. Good discipline.
- `redact` (go:65) and `_redact` (py:75) are equivalent. Passwords never logged. Verified.
- The `dry`-guarding in `expect`/`expectTrue` is the right place to centralize "don't compare
  in dry-run" — which is *why* the per-call empty-defaults (Finding 1) are redundant and should
  be deleted rather than guarded.

---

## Bottom line

- **Equivalence (Go/Py/spec): PASS.** Commands, flags, queries, and resource names match.
- **Resource correctness: PASS.** No object/ssl-cert confusion, correct RG/sub.
- **defer cleanup: PASS.** Runs on every path, preserves the real error.
- **Failure-masking: FAIL (HIGH).** Fix the empty-default class (Finding 1, Option A) before
  any EXECUTE run. It is one fix applied at ~7 Go / ~6 Py sites: stop discarding the az error,
  delete the defaults, let the probe fail on a failed query. The header already promises this
  behavior — the code currently does not deliver it in EXECUTE mode.

Priority-1: Finding 1a (whitelist-off residual masking) — a vault left open being reported as
clean is both a security exposure and a drift, and it is the one site that runs in the `defer`
on every failure path.
