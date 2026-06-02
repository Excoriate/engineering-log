---
task_id: 2026-06-02-004
agent: sherlock-holmes
status: complete
summary: "Adversarial receipt on the telemetryfunctiontestsfn /healthz 404 RCA. Core mechanism (nginx prefix mount, no rewrite-target, backend 404s unstripped path) SURVIVES attack — confirmed independently via nginx access logs showing upstream 10.0.1.167:8080 returned 404. But two material defects found: (1) the 'proven by composition' fix-claim over-reaches — the deployed Functions host serves ONLY /healthz; there are NO HTTP-trigger function routes (/api/* and /admin/* 404/401), so the rewrite fixes healthz only, not real function invocation; (2) the RCA's 404-origin reasoning ('empty body + no Server header = backend') is logically UNSOUND as written (nginx default-backend produces an identical-shape 404 here, and the Server header is absent on ALL responses incl. the 200) — the conclusion is right but for a reason the RCA did not actually establish until the access log proved it."
---

# Sherlock Adversarial Receipt — telemetryfunctiontestsfn /healthz 404 RCA

Win condition: destroy the diagnosis. Read-only probes run live against `vpp-aks01-d` / ns `vpp-agg`
and the public edge `agg.dev.vpp.eneco.com`, 2026-06-02 ~09:45-09:47 UTC. All evidence below is my own
capture, not imported from the deliverable files.

## Verdict in one line

The **mechanism holds** (backend 404s the unstripped prefixed path; nginx has no rewrite). But the RCA
**overstates the fix** and **mis-grounds one A1/A2 step**. Diagnosis: SOUND core, **two defects to correct
before sign-off** — one BLOCKING for the fix's stated scope, one HIGH for evidence integrity.

---

## What I tried to break, and what happened

### FINDING 1 — [BLOCKING for fix scope] "Proven by composition" over-reaches: the host serves ONLY /healthz; no function routes exist

The RCA (L8 Option A, fix.md L47-49) claims the rewrite enables both
`/telemetryfunctiontestsfn/healthz → /healthz` **and** `/telemetryfunctiontestsfn/api/<fn> → /api/<fn>`,
and frames the whole fix as "proven by composition."

I port-forwarded the **same pod the ingress routes to** and enumerated the Azure Functions host:

```text
/healthz            -> 200   (the only reachable route)
/api/                -> 404
/api/health          -> 404
/api/healthz         -> 404
/health              -> 404
/healthcheck         -> 404
/api/TelemetryFunctionTests -> 404
/admin/host/status   -> 401   (key-gated, no body)
/admin/functions     -> 401
root /  title        -> "Your Azure Function App is up and running."  (default host landing page)
```

**A1 (my probe).** This is a stock Functions host landing page with **zero reachable HTTP-trigger
functions** in the deployed image `adhoc-0.0.1.1457`. `/healthz` at root is effectively a **liveness shim**
(plain-text `Healthy`, not a Functions `/api/*` route).

**Why this breaks the claim as written:** the rewrite will make the edge return **200 on `/healthz` only**.
The RCA's "and `/api/<fn>` routing now works" half is **unproven and currently false** — there is no
function route to reach. "Proven by composition" is valid **for `/healthz`**; it is **not** valid for the
general "function invocation now works" framing the fix implies.

- Discriminating evidence: every `/api/*` variant 404s at the backend root (above). If the claim were true,
  at least one `/api/<fn>` would be 200 or 401-with-function-context.
- Severity: **BLOCKING** for the deliverable's stated scope. The fix is still correct for the *reported
  symptom* (healthz 404), but the RCA must scope the success claim to "healthz returns 200" and stop
  asserting function-route restoration. If the reporter (Johnson Lobo, doing E2E/QA) actually needs to
  *invoke* a function, the rewrite alone does NOT unblock that — the function isn't deployed.
- Settling probe (already run): the route table above.

### FINDING 2 — [HIGH] The stated 404-origin proof is logically unsound; the real proof is the access log (which the RCA did not cite)

RCA evidence-ledger and L3 lean on "clean 404 with **empty body + no Server header**" and treat the App
Gateway/nginx as "pass-through and innocent (A2)". As written this does **not** discriminate backend-origin
404 from **nginx default-backend** 404. I demonstrated the ambiguity and then resolved it:

Edge headers — the failing path, the working sibling, AND a **garbage path**:

```text
/telemetryfunctiontestsfn/healthz   -> 404  Content-Length: 0   (no Server header)
/this-path-should-not-exist-xyz123  -> 404  Content-Length: 0   (no Server header)  <-- IDENTICAL shape
/api/siteregistry                    -> 200  (also NO Server header)
```

**A1 (my probe).** The "no Server header / empty body" signature is present on **every** response including
the 200 — so it proves nothing about origin. A default-backend 404 would look the same at the edge. The
RCA's A2 ("the 404 originates at nginx→backend") was asserted, not established, by the cited evidence.

I then settled it the correct way — nginx access logs with a unique marker:

```text
"GET /telemetryfunctiontestsfn/healthz?m=...-PREFIXED"  404 0 ... [vpp-agg-telemetryfunctiontestsfn-8080] [] 10.0.1.167:8080 ... 404
"GET /nonexistent-...-DEFAULT"                          404 0 ... [vpp-agg-siteregistry-8080]            [] 10.0.2.235:8080 ... 404
"GET /api/siteregistry?m=...-WORKS"                     200 ... [vpp-agg-siteregistry-8080]              [] 10.0.2.235:8080 ... 200
```

**A1 (my probe).** The failing request **WAS routed to the telemetryfunctiontestsfn upstream**
(`10.0.1.167:8080` — the exact pod the service endpoint points to) and the **upstream returned 404**
(upstream_status field = 404). This is genuine backend-origin, NOT a default-backend miss.

Net: the RCA's **conclusion is correct**, but its **stated evidence chain for it is weak**. This is an
A1/A2 integrity defect (the harness's own rule: "unverified claim stated as fact = violation"). Fix by
replacing the "no Server header" reasoning with the access-log upstream_status proof.

- Bonus (kills a different RCA claim, in the RCA's favour): the garbage path routed to
  **`[vpp-agg-siteregistry-8080]`**, confirming siteregistry's `/` Prefix genuinely is the catch-all — so
  the RCA's "telemetry's longer prefix wins, won't shadow siteregistry" is **correct**. The new
  `/telemetryfunctiontestsfn(/|$)(.*)` rule is strictly more specific; no collision. (Fix Option A safe on
  this axis.)
- Severity: **HIGH** (evidence integrity; does not flip the route, but the RCA is graded as "Verified Root
  Cause depth 3" partly on an unsound step).

### FINDING 3 — [MEDIUM] The 301 redirects to `http://` (plaintext) on a TLS-terminated edge — under-documented

```text
GET https://agg.dev.vpp.eneco.com/telemetryfunctiontestsfn
-> 301  Location: http://agg.dev.vpp.eneco.com/telemetryfunctiontestsfn/   <-- note: http, not https
```

**A1 (my probe).** nginx emits an **HTTP** Location behind a TLS-terminating App Gateway (classic
missing `use-forwarded-headers`/`X-Forwarded-Proto` handling). The RCA calls this a benign
"nginx trailing-slash redirect" and moves on. It is benign for the *acceptance test* (which uses the
trailing-slash path and dodges the 301), but it is a real latent defect: a client hitting the bare prefix
gets bounced to plaintext `http://`, which from AVD/App-Gateway may fail or loop. Should be noted as a
residual, not dismissed.

- Severity: **MEDIUM** (tangential to the healthz 404; but it is a second nginx-config gap from the same
  AGIC→nginx migration and deserves a line in L10/Lessons).

### FINDING 4 — [LOW] Selector/endpoint match — checked, RCA is CORRECT

I attacked the port-forward proof on the "did you test a different pod than the ingress routes to" axis.
Service selector → endpoints → pod all reconcile to **`10.0.1.167`**, the same IP the nginx access log shows
as the upstream for the failing edge request. **No selector/endpoint mismatch.** Port-forward proof is
valid. RCA holds here.

---

## Things I could NOT break (diagnosis survives)

- Backend genuinely 404s the unstripped prefixed path while serving `/healthz` at root — re-confirmed by
  my own port-forward (`/healthz`=200, `/telemetryfunctiontestsfn/healthz`=404).
- nginx is the routing layer and forwards the prefix unstripped — confirmed by access log
  `[vpp-agg-telemetryfunctiontestsfn-8080] 10.0.1.167:8080 ... 404` on the unmodified path.
- No `rewrite-target` on the ingress — consistent with annotations being `meta.helm.sh/*` only (I did not
  re-decode the helm secret; that part I inherit as INFER, see fragile link).
- The fix's regex/capture logic for `/healthz` is mechanically sound: `/telemetryfunctiontestsfn(/|$)(.*)`
  → `$2`=`healthz` → `rewrite-target /$2` = `/healthz` (backend already 200). Composition valid **for the
  reported symptom**.
- siteregistry catch-all not shadowed (Finding 2 bonus).

## Single most fragile remaining link

**The fix has never been executed.** "Proven by composition" is a *logical* claim, not an *observed* one —
no rewrite was applied and re-curled (correctly, since it is pipeline-managed). The composition is valid for
`/healthz`, but the only way to retire the residual risk (regex actually applies under chart template's
hard-coded `pathType: Prefix`, `use-regex` honoured by controller v1.14.0, double-slash edge cases) is to
render+apply in a non-prod/ephemeral nginx and curl it. Until then the post-fix 200 is **INFER, not FACT**.

Secondary fragile link: the chart-version/annotations-empty claim (helm release secret decode) is the one
load-bearing A1 I did **not** independently re-verify in this pass — I attacked the runtime, not the helm
secret. If that decode were wrong (e.g. a rewrite annotation exists but is mis-templated), Finding 2's
mechanism would need revisiting. Low probability given the live ingress annotations are observably
`meta.helm.sh/*`-only, but it is the unverified inherited A1.

---

## Receipt classification (for the executor to action)

| # | Finding | Severity | Required disposition |
|---|---------|----------|----------------------|
| 1 | Fix fixes /healthz only; no function routes deployed; "composition" over-scoped | BLOCKING (scope) | RESOLVE: scope the success claim to "healthz=200"; add note that function *invocation* is NOT restored by the rewrite (no /api/<fn> exists in adhoc-0.0.1.1457). Ask reporter whether healthz reachability or actual function invocation is the real need. |
| 2 | 404-origin proof ("no Server header") logically unsound; real proof is access-log upstream_status | HIGH (evidence) | RESOLVE: replace the L3/ledger reasoning with the nginx access-log upstream_status=404 to `10.0.1.167:8080`. |
| 3 | 301 → http:// plaintext on TLS edge under-documented | MEDIUM | DEFER w/ note: add as residual/lesson (same migration class); revisit if bare-prefix access from AVD fails. |
| 4 | Selector/endpoint match | LOW | RESOLVED in RCA's favour (no change). |

**Does the diagnosis hold?** The *root cause* holds. The *fix's stated benefit* and *one evidence step* do
not, as written. Not a rubber stamp.
