---
task_id: 2026-07-20-001-recheck2
agent: verification-engineer
timestamp: 2026-07-20T12:33:53+02:00
status: complete
summary: |
  The second repair passes the exact R-01/R-02 falsifiers under Bash 3.2 and zsh 5.9. Guard failure makes zero `acc_oc` calls; every injected Service, Pod, EndpointSlice, and Application source failure exits nonzero with a named error; missing Application freshness exits nonzero with a named error; Service selector evaluation excludes a Ready nonmatching Pod; equal selected/endpoint UID sets emit MATCH; missing or unready endpoints emit MISMATCH. All six Feynman validations, 11 Mermaid renders, 27 Bash/zsh fence parses, ShellCheck, read-only, secret, and Application aggregation gates also pass. Documentation status is PASS at structural/local-fixture tier; live AVD activation remains PARTIAL.
key_findings:
  - finding_1: R-01 is closed by the exact published function in both supported shells.
  - finding_2: R-02 is closed for selector membership and ready Endpoint UID set equality.
  - finding_3: No new static or fixture-level regression was found; live ACC behavior is still unactivated.
---

# Final operational recheck 2

## Verdict

**Documentation: PASS. Live AVD activation: PARTIAL.**

The immutable snapshot is safe and effective at the proof tier available to this verifier: all published commands are read-only; the repaired structured function fails closed on identity/API/freshness errors; the required serving and Application false-green fixtures are discriminated; the runbook remains reusable without Lens; and the AVD ceiling is explicit. This does not promote the function or Wednesday maintenance outcome to live-proven.

| Lane | Status | Highest proof tier |
|---|---|---|
| R-01 guard short-circuit | **PASS** | exact-function local behavioral simulation in Bash and zsh |
| R-01 source failure handling | **PASS** | exact-function injected failures in Bash and zsh |
| Missing `reconciledAt` | **PASS** | exact-function negative fixture in Bash and zsh |
| R-02 Service selector membership | **PASS** | exact-function JSON/jq fixture |
| R-02 Endpoint UID equality | **PASS** | exact-function MATCH/MISMATCH fixtures |
| Application complete-fleet aggregation | **PASS** | exact-function JSON/jq fixture |
| Bash/zsh/ShellCheck | **PASS** | structural/static |
| Feynman + Mermaid | **PASS** | validator + renderer consumer |
| Read-only command posture | **PASS** | static Bash-fence scan |
| Secret safety | **PASS** | static pattern scan |
| Lens independence | **PASS** | structural contract |
| Real AVD/installed `oc` execution | **PARTIAL / NOT YET RUN** | explicit blocked consumer |

## R-01 targeted falsification

The exact function published at `argocd-replica-increase-acceptance-runbook.md:217-331` was extracted unchanged. Only `acc_guard` and `acc_oc` were replaced with deterministic test doubles.

### Guard failure

- **Claim attacked:** failed ACC identity prevents every downstream API read.
- **Falsifier:** `acc_guard` returns 41; `acc_oc` prints a marker if called.
- **Expected:** nonzero; named identity error; zero API-call markers.
- **Bash actual:** `RC=1`, `STRUCTURED_SAMPLE_FAILED: ACC identity guard`, zero `ACC_OC_CALLED` markers.
- **zsh actual:** identical result.
- **Status:** **PASS.** The previous top-level `return` failure is closed because `return 1` now executes inside `acc_structured_sample()`.

### Source failures

Each API source was independently forced to return nonzero. Every case exited 1 and named the failed source in both shells:

| Injected source failure | Bash/zsh result |
|---|---|
| Service | `STRUCTURED_SAMPLE_FAILED: Service read` |
| Pod | `STRUCTURED_SAMPLE_FAILED: Pod read` |
| EndpointSlice | `STRUCTURED_SAMPLE_FAILED: EndpointSlice read` |
| Application | `STRUCTURED_SAMPLE_FAILED: Application read` |

No failure reached the later parser for that source. Capturing JSON through command substitution before jq closes the earlier pipeline-masking defect.

### Missing Application freshness

- **Falsifier:** two Applications, one without `.status.reconciledAt`.
- **Expected:** nonzero and explicitly named.
- **Bash actual:** `RC=1`, `STRUCTURED_SAMPLE_FAILED: missing Application reconciledAt`.
- **zsh actual:** identical result.
- **Status:** **PASS.** A green Application row without freshness cannot enter the fleet summary.

## R-02 targeted falsification

Fixture topology:

- Service `server-svc` selects `app=server`.
- Ready Pods `server-1/uid-1` and `server-2/uid-2` match.
- Ready Pod `other-ready/uid-x` has `app=other` and must be excluded.
- EndpointSlice variants provide matching, missing, or unready targets.

### Selector membership and MATCH

The exact function emitted only:

```text
SELECTED_POD server-svc app=server server-1 uid-1 10.0.0.1 true
SELECTED_POD server-svc app=server server-2 uid-2 10.0.0.2 true
SERVING_CHECK server-svc uid-1,uid-2 uid-1,uid-2 MATCH
```

No `SELECTED_POD` row contained `other-ready/uid-x`. This proves the jq selector evaluation uses Pod labels rather than naming inference.

### Missing and unready endpoints

- **Missing target fixture:** selected UIDs `uid-1,uid-2`; ready endpoint UIDs `uid-1`; output `MISMATCH` in Bash and zsh.
- **Unready target fixture:** Endpoint row retained `uid-2 false`, but ready endpoint UID set was only `uid-1`; output `MISMATCH` in Bash and zsh.
- **Matching fixture:** both sets were `uid-1,uid-2`; output `MATCH` in Bash and zsh.
- **Status:** **PASS.** The old wide-output and selector-membership false greens are discriminated.

The function intentionally reports MISMATCH as evidence rather than treating it as a shell transport failure. The runbook's serving invariant and discrepancy table make any MISMATCH a non-success state.

## Application aggregation

The same exact-function fixture contained one `Synced Healthy` and one `Synced Degraded` Application, both with freshness. Output in both shells was:

```text
TOTAL 2
DISTRIBUTION Synced Degraded 1
DISTRIBUTION Synced Healthy 1
EXCEPTION degraded Synced Degraded 2026-07-20T10:01:00Z
FRESHNESS healthy 2026-07-20T10:00:00Z
FRESHNESS degraded 2026-07-20T10:01:00Z
```

The Degraded row cannot hide inside an apparently green fleet. The separate missing-freshness case exits nonzero before aggregation.

## Full regression gates

1. **Bash fences:** independently inventoried `27`; Bash 3.2 parse failures `0`; zsh 5.9 parse failures `0`; ShellCheck warning-or-higher failures `0`.
2. **Feynman validation:** all six documents returned `PASS` with `mermaid render passed`.
3. **Mermaid inventory:** 11 blocks; all were rendered by the six validator invocations.
4. **Read-only scan:** `READ_ONLY_COMMAND_SCAN=PASS`; no fenced `oc`/`kubectl` apply/create/edit/patch/replace/delete/scale/exec/debug/restart/sync/terminate path.
5. **Secret scan:** `SECRET_PATTERN_SCAN=PASS`; no private key, JWT-shaped credential, client-secret/password assignment, or long token assignment matched.
6. **Lens dependency:** three historical/convenience references exist, but `probes-explanation.md` explicitly makes authenticated CLI the source of truth and none of the ACC execution or verdict gates require Lens/Freelens.

No cluster command was executed. No immutable snapshot document was edited.

## Snapshot hashes

```text
04e2a28c791d58c5724653c2245096a91e4ebe3d54c83119d1cc7525294b1e4e  argocd-openshift-command-probes.md
bc8189cb4e23f5f3e9684b4347484d5f2bbd6fad577d75f7f10cc73f133b8e22  argocd-replica-increase-acceptance-runbook.md
c46e66f809b6503c176ddb911c1a0c3ae38b141e2d4c363b1b273a083f6093d3  argocd_replica_increase_explained.md
c0f6f60ceaf334381575ef6b1884d16824882762a28c0924c950441299f14b9d  maintenance-july-20-records-findings.md
788d0ba38c123c97350ad3e868fd2081b5f1f3aa397bd33959adf97427f5e7ac  maintenance-july-22-records-findings.md
8ab202e11cec3839d23f2cfc262f5c88c1f2a73355eb4d62183080ded8058def  probes-explanation.md
b17e6efce7250c753ad934566de5889cf2068980711bf69cd0d964ed52819ce8  validate-feynman-doc.py
```

## Proof ceiling and promotion path

- **FACT / STRUCTURAL:** document anatomy, shell parsing, static safety, secret scan, CLI-only route, and explicit proof-state wording.
- **FACT / LOCAL BEHAVIORAL SIMULATION:** exact function's guard/source/freshness behavior; selector evaluation; ready UID MATCH/MISMATCH; Application aggregation.
- **UNVERIFIED[blocked] / BEHAVIORAL-ACTIVATED:** real AVD keyboard/paste path, installed `oc`, ACC RBAC, jq availability/version, non-empty live object sets, and real selector/EndpointSlice/Application shapes.
- **UNVERIFIED[future]:** Wednesday intent, T0, replica/CPU/memory/node/serving/Application deltas, Redis quorum, stabilization, and maintenance outcome.

The runbook correctly labels the structured function `STATICALLY VERIFIED, NOT YET RUN IN THE AVD` at lines 334 and preserves the current ceiling at lines 582–587. Promotion requires a human paste or isolated-kubeconfig execution in ACC that records: API/context identity; function exit; named failure behavior for a safe negative control; non-empty Service/Pod/EndpointSlice/Application inputs; MATCH/MISMATCH rows; total/distribution/exception/freshness rows; and no secret-bearing output. Until then, live activation remains **PARTIAL** even though the documentation passes.

## Counter-hypothesis and insight audit

Alternative explanation: the fixtures pass only because they are simpler than real OpenShift data. The tests counter the previously demonstrated failure mechanisms—shell control flow, command-status masking, selector leakage, readiness filtering, UID equality, hidden Application exceptions, and stale rows—but they do not prove every installed schema or topology. A two-year maintainer should preserve these exact old/wrong variants as an executable regression harness beside the runbook; otherwise future wording edits can retain Feynman/parse green checks while silently weakening failure discrimination.
