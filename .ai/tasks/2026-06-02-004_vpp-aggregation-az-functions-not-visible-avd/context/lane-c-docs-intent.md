---
task_id: 2026-06-02-004
agent: claude-opus-4-8
status: complete
summary: Lane C (docs/ADR/runbook intent) for the agg.dev telemetryfunctiontestsfn 404. Provides INTENT + CONVENTION + TOPOLOGY from Eneco ADO wikis/ADRs. Root cause proven elsewhere; this lane is non-diagnostic context.
---

# Lane C — Docs / ADR / Intent: agg aggregation functions exposure + AVD network path

Source: Eneco ADO (org `enecomanagedcloud`, project `Myriad - VPP`) wikis + `DesignDecisions` repo,
fetched read-only 2026-06-02 via `eneco-context-docs` skill scripts. Evidence labels per repo convention:
`A1` = quoted doc text + locator; `A2` = inference from A1; `A3` = could not probe / blocked.

This lane does NOT re-diagnose the 404. It supplies the documented INTENT and CONVENTION the RCA needs to
classify the 404 as "convention violation" vs "expected/non-canonical path." Live-probe facts already in
`context/evidence-ledger.md` are cross-referenced but not re-derived here.

---

## TL;DR (answers to the four lane questions)

1. **Exposure convention:** Documented intent (ADR AL006) = SiteRegistry API + Test Functions exposed over
   HTTPS on `https://agg.<env>.vpp.eneco.com` via an **Application Gateway listener** added to the core app
   gateway (DEV-MC + ACC), replicating the sandbox setup, behind **AAD authentication**. There is **NO
   documented nginx ingress path-prefix / rewrite-target / `/api/<func>` routing convention** for the `*fn`
   functions (search returned no results). The documented *entry point* for the test functions is the bare
   prefix `…/telemetryfunctiontestsfn` — `/healthz` under that prefix is NOT a documented endpoint.

2. **Function purpose:** `telemetryfunctiontestsfn` (and the `*fn` family) are explicitly **test-only Azure
   Functions** for E2E/integration test automation of the VPP Aggregation Layer (VPPAGL): publish mock data to
   Kafka + read/validate output from CosmosDB. ADR AL006: *"They never are going to be deployed to PROD."*
   Owned by the Aggregation Layer / QA stream (code in `Myriad - VPP - Aggregation` repo). NOT a production
   diagnostic/health endpoint.

3. **Canonical vs legacy:** `agg.<env>.vpp.eneco.com` is the **canonical, documented** aggregation host across
   dev / dev-mc / acc (Quick-Links, E2E framework config, AVD DNS table, AL006). `ionix/ishtar/jupiter` are
   **per-name dev fronts on the SAME public app-gateway IP** (`*.dev.vpp.eneco.com` → `20.76.210.221`), not a
   replacement for `agg.dev`. No deprecation/migration note for `agg.dev` was found in docs.

4. **AVD network path:** `agg.dev.vpp.eneco.com` is covered by the **public** wildcard DNS `*.dev.vpp.eneco.com`
   → `20.76.210.221` (Capgemini public DNS). It is **publicly reachable; no AVD VNET/private-endpoint/IP-whitelist
   is required** to reach it (matches the live laptop probe). This contrasts with `agg.dev-mc` / `agg.acc`, which
   resolve to **internal** IPs (`10.7.x`, internal/VPN DNS) and DO require AVD/VPN connectivity.

---

## Q1 — How is the Aggregation Layer meant to expose functions externally?

### A1 — ADR AL006 (the governing decision)

Repo `DesignDecisions`, file
`architecture-decision-records/AggregationLayer/AL006-Expose-SiteRegistry-and-TestFunctions-via-https-in-non-prod-env/README.md`
(title: *"Expose SiteRegistry and TestFunctions via https in non prod environments"*, dated 2023-22-11).
Quoted:

> "In VPPAL we have two components which can be accessed via HTTPS:
> - Site Registry API (with a swagger page) …
> - Test Functions (set of azure functions to be able to publish/read data to/from ESP). The intensions to have
>   an ability to perform manual/automated test up to ACC. They never are going to be deployed to PROD environment."

> "Both SiteRegistry API and Test Functions can be accessible only by authenticated users(AAD authentication).
> The token can be got from VPP Core UI."

> **Decision:** "In the Acceptance and DEV-MC environments add an additional listener to the existing core
> application gateway such that the Site Registry API and Test Functions area available from
> https://agg.<env>.vpp.eneco.com. This effectively replicates the solution already in place in the sandbox
> environment."

> "Up until now 'tester' access to the application in CMC environments has been via port forwading directly to
> the function. This is cumbersome; direct https access would offer a much better workflow."

**A2 (inference):** The documented routing layer is an **Application Gateway listener**, not nginx path-rewrite.
The doc specifies *which host* exposes the components but does NOT specify a per-function path-prefix or
rewrite convention. So nginx ingress `rewrite-target` behaviour is an IMPLEMENTATION detail below the ADR — the
ADR neither mandates nor documents it. The 404 mechanism (proven in the evidence ledger) is therefore **not a
violation of any documented ingress-rewrite rule** (none exists); it is a gap between the app's root-served
routes and the prefix-mount, uncovered by any ADR.

### A1 — Documented entry points (no `/healthz` under prefix)

Wiki `Myriad---VPP.wiki`, page `/Myriad - VPP: Getting started/Quick Links`, "Aggregation Layer" section:

```text
# DEV
https://agg.dev.vpp.eneco.com/api/siteregistry/swagger/index.html
https://agg.dev.vpp.eneco.com/telemetryfunctiontestsfn
## DEV-MC
https://agg.dev-mc.vpp.eneco.com/api/siteregistry/swagger/index.html
https://agg.dev-mc.vpp.eneco.com/telemetryfunctiontestsfn
## ACC
https://agg.acc.vpp.eneco.com/api/siteregistry/swagger/index.html
https://agg.acc.vpp.eneco.com/telemetryfunctiontestsfn
```

Wiki `/Myriad - Aggregation Layer/QA Documents/E2E Test Automation Framework`, "Running Tests Locally" config block
documents the intended base URIs (secret values present in the page are NOT reproduced here per safety policy):

> `"SiteRegistryUri": "https://agg.dev.vpp.eneco.com/api/siteregistry"`
> `"TelemetryUri":     "https://agg.dev.vpp.eneco.com/telemetryfunctiontestsfn"`

**A2 (inference):** The documented, intended base for the test functions is the **bare path prefix**
`…/telemetryfunctiontestsfn` (no trailing `/`, no `/healthz`). Individual functions are invoked by their own
route names appended to that base (e.g. the QA page shows `POST /telemetry/generate?owner=…`). The reporter's
probe `…/telemetryfunctiontestsfn/healthz` targets a path that is **not a documented endpoint** for these
functions — `/healthz` is a generic Azure Functions / k8s health route served at the *app root*, not under the
documented prefix. This reframes the incident: the failing URL is not the documented way to reach the function.

### A1 — How a new function is wired (deployment topology, not ingress-rewrite)

Wiki `/Myriad - Aggregation Layer/Developers Guide/Steps to add new function` (Page ID 29581):

> "Helm files to deploy in dev-mc, acceptance and production environments (this is in VPP-agg-Configuration repo)"
> "This folder is configured to have the deployments happen through argo-cd which can be accessed through AVD."
> "Create a folder with function name under VPP-agg-Configuration/Helm repo … subfolders named dev,acc and prd…"

**A2:** dev-mc/acc/prd `*fn` deployments are GitOps (ArgoCD) from `VPP-agg-Configuration/Helm/<functionname>`.
This is the canonical fix-location for the missing rewrite/PathBase. (Cross-ref: evidence-ledger open item #1;
the QA Test Functions page links `VPP-agg-Configuration?path=/Helm/telemetryfunctiontestsfn` directly.)

### A3 — UNVERIFIED[blocked]

- No Terraform/Helm styleguide documenting an ingress `rewrite-target` or `/api/<func>` path convention was
  found. `wiki-search "ingress rewrite path prefix function"` → NO RESULTS;
  `wiki-search "aggregation function healthz endpoint route ingress"` → NO RESULTS. Blocking reason: such a
  convention may live only in repo code (Helm templates), out of scope for this docs lane → see repo lane.
- `/Way of Working/DevOps & Platform/Tutorials-HowTos/sandbox Ingress` (Page ID 10817) is **image-only** (single
  attachment, no quotable text). Blocked: content is in a diagram image, not extractable via the text API.

---

## Q2 — What is telemetryfunctiontestsfn / the *fn family?

### A1 — QA Test Functions page (definitive)

Wiki `/Myriad - Aggregation Layer/QA Documents/Test Functions` (Page ID 57954):

> "These Azure Functions … enable efficient and reliable **end-to-end testing** in the VPP Aggregation Layer
> (VPPAGL) test automation framework. They serve two main purposes: 1. Data Generation [publish mock/test data
> to Kafka topics] … 2. Data Validation [retrieve output data from Cosmos DB]…"

Code location (linked in page): `Myriad - VPP - Aggregation` repo, path
`/FunctionsIntegrationTests/TelemetryFunctionTests`. Helm config:
`VPP-agg-Configuration` repo, path `/Helm/telemetryfunctiontestsfn`.

Documented functions inside this app (HTTP-triggered): Data Generation — `TelemetryGeneratorFunction`,
`CreateStrikePriceFunction`, `CreateFlexCapacityFunction`, `CreateFlexReservationFunction`,
`SetPointGeneratorFunction`, `PortfolioRequestGeneratorFunction`; Data Validation — `ReadDeviceTelemetry`,
`ReadPoolTelemetry`, `ReadMeritOrderFunction`, `ReadDeviceCapacityFunction`,
`ReadDeviceDisaggregatedSetPointFunction`, `ReadActivationResponse`.

**A2 (inference):** `telemetryfunctiontestsfn` is a **test-automation Azure Functions app**, not a production
service and not a generic health endpoint. It is the deployed counterpart of the `FunctionsIntegrationTests`
test code, present in non-prod (dev/dev-mc/acc) ONLY by design (AL006: never PROD). The `*fn` siblings
(deliveryreportfn etc. seen in the cluster) are the same class: test/diagnostic functions mounted per-name.
Owner: Aggregation Layer team / its QA stream (the page lives under the Aggregation Layer wiki; "reach to
platform team" for KeyVault access). The dispatch hypothesis "owner = vpp-core" is NOT supported by docs — docs
place these under the **Aggregation Layer**, not VPP Core. [INFER — based on wiki tree placement + repo ownership;
not an explicit "owner: team X" statement.]

### A3 — UNVERIFIED[blocked]

- Per-function owner-of-record (a named team field) is not stated in any single doc. Blocked: docs attribute by
  wiki section / repo, not by an explicit RACI line. Resolving path: ADO repo permissions / CODEOWNERS (repo lane).

---

## Q3 — Is agg.dev / vpp-agg canonical, or is ionix/ishtar/jupiter the standard?

### A1 — DNS records (Application Gateway page)

Wiki `Platform-documentation`, page `/Reference/Architecture/Ingress via Application Gateway` (Page ID 56486),
"Capgemini - Public DNS - vpp.eneco.com" table (selected rows, verbatim):

```text
*.dev.vpp.eneco.com     A   20.76.210.221
dev.vpp.eneco.com       A   20.76.210.221
ionix.dev.vpp.eneco.com   A   20.76.210.221
ishtar.dev.vpp.eneco.com  A   20.76.210.221
jupiter.dev.vpp.eneco.com A   20.76.210.221
dev-mc.beta.vpp.eneco.com A   104.40.245.236
```

"Capgemini and Conclusion - Internal DNS" table:

```text
agg.acc.vpp.eneco.com     A   10.7.224.8
agg.dev-mc.vpp.eneco.com  A   10.7.32.4
```

**A2 (inference):**
- `agg.dev.vpp.eneco.com` is NOT an explicit row; it is covered by the wildcard `*.dev.vpp.eneco.com` →
  `20.76.210.221` (the same public app-gateway front the laptop hit — cross-ref evidence-ledger).
- `ionix/ishtar/jupiter` (and ~20 other code-names: thor, thrym, pikachu, voltex, zapray, salar …) are
  **named dev fronts sharing the one public dev app-gateway IP**. They look like per-stack/per-purpose dev
  hostnames on the SAME gateway — they do NOT supersede `agg.dev`; they coexist. There is no doc framing them
  as "the new standard" replacing `agg`.
- `agg.dev-mc` and `agg.acc` are the **internal** counterparts (`10.7.x`), the environments AL006 explicitly
  targeted for the app-gateway listener. `agg.dev` (public wildcard) is a separate, more-exposed front.

### A1 — Canonicality corroborated by usage docs

Quick-Links + E2E framework config (quoted in Q1) both use `agg.<env>.vpp.eneco.com` as THE aggregation entry,
across dev/dev-mc/acc. AVD DNS-resolution page lists `agg.dev-mc.vpp.eneco.com` and `agg.acc.vpp.eneco.com` as
"Working" resolutions for AVD users.

**A2:** `agg.<env>` is the canonical, current, documented aggregation host. No deprecation note found.

### A3 — UNVERIFIED[blocked]

- The semantic meaning of the code-named fronts (ionix/ishtar/jupiter/thor/…) is not defined in any doc found
  (no glossary entry). Blocked: naming scheme undocumented in wiki; likely FBE / per-stack dev fronts, but that
  is INFER, not stated. `wiki-search` for these names was not separately run (out of lane budget); flagged for
  repo/Slack lane if route depends on it. Route-impact: LOW — does not change the agg.dev 404 diagnosis.

---

## Q4 — AVD network path to agg.dev.vpp.eneco.com

### A1 — Public vs internal DNS (Application Gateway page, Page ID 56486)

`agg.dev` is matched by **public** `*.dev.vpp.eneco.com` → `20.76.210.221` (Capgemini public DNS). By contrast
the internal-DNS table only lists `agg.acc` (`10.7.224.8`) and `agg.dev-mc` (`10.7.32.4`) — i.e. those are the
private-network hosts; `agg.dev` is on the public edge.

### A1 — AVD DNS resolution table

Wiki `/Way of Working/DevOps & Platform/Tutorials-HowTos/DNS/AVD DNS resolution` (Page ID 12143), verbatim rows:

```text
agg.dev-mc.vpp.eneco.com   104.40.245.236   Working
agg.acc.vpp.eneco.com      20.4.24.37       Working
dev.beta.vpp.eneco.com     20.76.210.221    Working
```

**Note:** the AVD DNS table lists `agg.dev-mc` and `agg.acc` but does **NOT** list `agg.dev` explicitly —
consistent with `agg.dev` being a public wildcard host rather than an AVD-private resolution entry.

### A1 — AVD ↔ CMC connectivity model (for the private hosts)

Wiki `/Way of Working/DevOps & Platform/Tutorials-HowTos/AVD connectivity to CMC managed VNETS` (Page ID 44740):

> "Generally we will connect to Azure resources in CMC managed networks via private endpoints. For connectivity
> we need: 1) Outbound firewall rules for the AVD 2) Incoming firewall rules Azure VNET 3) Connectivity between
> the AVD network and the CMC managed network."
> "You raise the rules via Service Now … approved by the security team … implemented by Capgemini."
> "AVD networks connect to conclusion networks via Express Route."

**A2 (inference):**
- `agg.dev.vpp.eneco.com` is **publicly reachable** (public wildcard A record + live laptop probe in the
  evidence ledger). **No AVD VNET / private endpoint / IP-whitelist is required** to reach it — the AVD framing
  in the ticket is the reporter's vantage point, not a network gate. This corroborates the evidence-ledger A2.
- The Service-Now / private-endpoint / firewall-whitelist runbook (Page ID 44740) applies to the **internal**
  agg hosts (`agg.dev-mc`, `agg.acc`) and other CMC private resources — NOT to `agg.dev`. So a runbook for
  "whitelist an AVD IP" exists, but it is **not the relevant lever for this incident** (the host is already
  public and answering; the failure is path-level 404, not a network block).

### A3 — UNVERIFIED[blocked]

- The front-resource identity (App Gateway vs Front Door) for `20.76.210.221` is named "Application Gateway" by
  the Platform doc title and AL006 ("application gateway listener") [A1 doc], but the live Azure resource type
  was not re-probed in this lane (evidence-ledger has it pending az resource-graph). Blocked: live infra probe is
  out of docs-lane scope. Docs say App Gateway; treat as A2 until the az lookup confirms.

---

## Cross-references / corrections to inherited analysis

- Evidence-ledger open item #1 ("vpp-agg may be a legacy/ad-hoc env not actively GitOps-synced"): docs show
  `VPP-agg-Configuration/Helm/telemetryfunctiontestsfn` IS the intended GitOps source for dev-mc/acc/prd via
  ArgoCD. The running `adhoc-0.0.1.*` image drift the ledger noted is therefore better read as **a specific
  `agg.dev` front possibly diverging from the GitOps `agg.dev-mc` config**, NOT as "vpp-agg is abandoned." The
  config repo is canonical. [A2 — reconcile in repo lane.]
- Evidence-ledger open item #2 ("modern convention … telemetry-0.4.0 at /api/telemetry … is vpp-agg deprecated?"):
  no doc deprecates `agg`/`*fn`. The `/api/telemetry` Helm chart is a DIFFERENT (production) telemetry service;
  the `*fn` functions are TEST-only by AL006 and are a separate, still-current concern. [A2.]
- Reframe for the RCA: the failing URL `…/telemetryfunctiontestsfn/healthz` is **not a documented endpoint**.
  The documented entry is the bare prefix `…/telemetryfunctiontestsfn`. Whether even THAT returns 200 through
  the current `agg.dev` ingress is the real "is it reachable as intended" question — and per the evidence
  ledger, `…/telemetryfunctiontestsfn/` itself 404s, so the documented entry point is also broken on `agg.dev`.

## Provenance (commands, read-only)

All via `eneco-context-docs` skill, org `enecomanagedcloud`, project `Myriad - VPP` (auth: `AZURE_DEVOPS_PAT`):

- `repo-file.sh --repo DesignDecisions --path architecture-decision-records/AggregationLayer/AL006-…/README.md`
- `wiki-page.sh --path "/Myriad - Aggregation Layer/QA Documents/Test Functions"`  (Page ID 57954)
- `wiki-page.sh --path "/Myriad - Aggregation Layer/QA Documents/E2E Test Automation Framework"` (Page ID 57870)
- `wiki-page.sh --path "/Myriad - Aggregation Layer/Developers Guide/Steps to add new function"` (Page ID 29581)
- `wiki-page.sh --path "/Myriad - Aggregation Layer/Public API"` (Page ID 54887)
- `wiki-page.sh --path "/Myriad - VPP: Getting started/Quick Links"`
- `wiki-page.sh --wiki Platform-documentation --path "/Reference/Architecture/Ingress via Application Gateway"` (Page ID 56486)
- `wiki-page.sh --path "/Way of Working/DevOps & Platform/Tutorials-HowTos/DNS/AVD DNS resolution"` (Page ID 12143)
- `wiki-page.sh --path "/Way of Working/DevOps & Platform/Tutorials-HowTos/AVD connectivity to CMC managed VNETS"` (Page ID 44740)
- `wiki-search.sh --query "ingress rewrite path prefix function"` → NO RESULTS
- `wiki-search.sh --query "telemetryfunctiontestsfn"` → 3 results (Quick-Links, E2E framework)

No secret values, tokens, or connection strings from any fetched page are reproduced in this file.
