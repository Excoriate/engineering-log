---
task_id: 2026-06-15-001
agent: iac-reader
status: complete
summary: Cosmos throughput unmanaged in IaC (default 400 RU/s shared manual, no autoscale); fired NormalizedRUConsumption alert is NOT defined in this repo — only latency + 429 alerts are.
timestamp: 2026-06-15T16:24:25Z
---

# IaC + Platform-Docs Ground Truth — gurobi-cosmos-normalized-ru-consumption-a

## BRAIN SCAN (self, INFER until source-verified by coordinator)

- **Dangerous assumption**: that `cosmosdb-gurobi-platform-a` + its alert are defined in this repo's `src/`. FALSIFIER: grep for account name, `NormalizedRUConsumption`, `azurerm_cosmosdb_account`.
- **Result of falsifier**: account IS defined in-repo (mongodb.tf:1) — but the fired alert is NOT (see Finding 3). Throughput config is genuinely absent from IaC, corroborated by platform docs.
- **Residual risk**: live Azure state (actual provisioned RU/s, actual partition keys, actual alert resource owner) is NOT probed in this lane — that is the runtime lane's job. All "default 400 RU/s" claims are A2 INFER from provider semantics, NOT a live read.

## Repo scope verified

Full repo enumerated, 33 non-`.git` files (`find` output). All Cosmos/alert IaC lives in `src/*.tf`. No remote module wraps the Cosmos account — it is a direct `azurerm_cosmosdb_account` resource.

- A1 FACT: `find` returned exactly 4 `.tf` files touching Cosmos/alerts: `src/mongodb.tf`, `src/alerts.tf`, `src/monitoring.tf`, `src/locals.tf`. (repo file list, this session)

---

## Q1 — CosmosDB account throughput MODE / RU / shared-vs-container / serverless / free-tier

- **A1 FACT** — Account resource: `azurerm_cosmosdb_account` named `cosmosdb-gurobi-platform-${var.environment_suffix}` (acc → `-a`). `src/mongodb.tf:1-2`.
- **A1 FACT** — `offer_type = var.cosmos_db_config.offer_type` → `"Standard"`; `kind = "MongoDB"`; `mongo_server_version = "7.0"`. `src/mongodb.tf:5-7`, values from `src/environments/acceptance.tfvars:18-30`.
- **A1 FACT** — NO `capabilities` block anywhere in `mongodb.tf` → **serverless is NOT enabled** (serverless requires `capabilities { name = "EnableServerless" }`). Account is **provisioned-throughput**. `src/mongodb.tf:1-22` (absence) + repo-wide grep for `serverless|EnableServerless` returned zero hits.
- **A1 FACT** — NO `enable_free_tier` attribute → **free-tier NOT enabled** (defaults false). `src/mongodb.tf:1-22` (absence).
- **A1 FACT** — Database `azurerm_cosmosdb_mongo_database.gurobi` name `grb_rsm` has NO `throughput` argument and NO `autoscale_settings {}` block. `src/mongodb.tf:41-45`.
- **A1 FACT** — Repo-wide grep for `throughput|autoscale|max_throughput` returned ZERO hits. (grep output, this session)
- **A1 FACT** — Platform doc states verbatim: *"The Infrastructure only contains deployment resources for the CosmosDB account and the grb_ts database. Currently, throughput is not managed through Terraform yet."* `eneco-temp/platform-documentation/internal/How-To-Guides/Gurobi/cluster-provisioning.md:29`.
- **A2 INFER** (provider semantics) — With no `throughput` and no `autoscale_settings` on the mongo database, and no account-level throughput resource, the database is created at the **azurerm/Cosmos default: 400 RU/s MANUAL (fixed) provisioned throughput, database-level (shared)**. Mode = **manual provisioned, NOT autoscale**. Reasoning: azurerm omits the property → Azure applies the standard 400 RU/s minimum shared throughput for a provisioned account; autoscale is opt-in only.
- **A3 UNVERIFIED[blocked: no live Azure read in this lane]** — Actual current RU/s could have been changed in-portal AFTER provisioning (doc:29 explicitly says throughput is managed OUTSIDE Terraform). The 77.67% NormalizedRUConsumption could be against 400 RU/s shared OR a higher portal-set value OR per-collection RU. Resolving path: runtime lane `az cosmosdb mongodb database throughput show` / collection throughput show on `cosmosdb-gurobi-platform-a` / `grb_rsm`.

**Throughput summary**: IaC defines provisioned (not serverless, not free-tier), shared database-level throughput, NO autoscale, NO explicit RU value → defaults to manual 400 RU/s. Throughput is explicitly declared out-of-Terraform by platform docs, so live value may differ.

---

## Q2 — Databases, containers/collections, PARTITION KEYS

- **A1 FACT** — Exactly ONE database in IaC: `azurerm_cosmosdb_mongo_database.gurobi`, name **`grb_rsm`**. `src/mongodb.tf:41-45`.
- **A1 FACT** — ZERO containers/collections defined in IaC. No `azurerm_cosmosdb_mongo_collection` resource exists; repo-wide grep for `partition_key|shard_key` returned zero hits.
- **A1 FACT** — Platform doc: *"The Cluster Manager workload creates/manages the collections in the MongoDB database on it's own."* `cluster-provisioning.md:29`.
- **A2 INFER** — **The hot-partition hypothesis cannot be evaluated from IaC.** Collections and their shard keys are created at runtime by the Gurobi Cluster Manager application, not Terraform. Partition-key paths are invisible to this lane.
- **A3 UNVERIFIED[blocked: collections are app-managed]** — To get shard keys, must inspect live MongoDB (`db.collection.getShardDistribution()` / Cosmos collection list) or the gurobi-cluster-manager app source / gurobi-gitops repo. Resolving path: runtime lane or app-source lane.
- **DRIFT FLAG (A1 FACT)** — Doc says the IaC database is **`grb_ts`** (`cluster-provisioning.md:29`), but IaC actually names it **`grb_rsm`** (`src/mongodb.tf:42`). Doc/code mismatch — `grb_ts` is the token-server process name, likely a doc error. Use `grb_rsm` as truth for the account being alerted.

---

## Q3 — The fired alert `gurobi-cosmos-normalized-ru-consumption-a`

- **A1 FACT (route-flip)** — **This alert is NOT defined in this repository.** Repo-wide grep for `normalized|NormalizedRU|ru-consumption|ru_consumption` returned ZERO hits across all 33 files. (grep output, this session, EXIT=1 no-match).
- **A1 FACT** — IaC defines metric alerts via `azurerm_monitor_metric_alert.cosmosdb` with `for_each = local.default_cosmosdb_metric_alerts`. `src/monitoring.tf:19-54`.
- **A1 FACT** — `local.default_cosmosdb_metric_alerts` contains EXACTLY TWO alerts: (1) `gurobi-cosmos-latency` (ServerSideLatency Avg > 99ms, Sev2, PT5M/PT5M); (2) `gurobi-cosmos-throttling-429` (TotalRequests Count >= 20 with dimension StatusCode=429, Sev2, PT5M/PT5M). `src/locals.tf:4-44`. There is NO third NormalizedRUConsumption alert.
- **A2 INFER** — The fired alert (`NormalizedRUConsumption`, Avg > 75%, PT15M window, `minFailingPeriodsToAlert 0 / numberOfEvaluationPeriods 0`) is therefore **externally provisioned** — not by this repo. Candidates: CCoE/platform-managed Azure Policy default alert, Azure Monitor recommended/auto-alert, or a hand-created portal alert. The `PT15M` window + zero-eval-periods shape differs from this repo's hand-written PT5M alerts, supporting "not this repo's style."
- **Account-scoped vs container-scoped (A2 INFER)**: The in-repo alerts are **account-scoped** (`scopes = [azurerm_cosmosdb_account.mongodb.id]`, `src/monitoring.tf:25`). NormalizedRUConsumption is reported per-account-with-dimensions (CollectionName/DatabaseName/Region/PartitionKeyRangeId); a 0/0 eval-period alert with Average over PT15M at account scope is the typical Azure default. **Actual scope of the FIRED alert is UNVERIFIED[blocked: not in IaC]** — must read the live alert resource.
- **In-repo alert routing (A1 FACT)**: in-repo alerts route to `data.azurerm_monitor_action_group.platform`, resolved from `var.monitoring.action_group` = name `ag-trade-platform-a`, rg `rg-pltfrm-infra-a` (acc). `src/monitoring.tf:51-52`, `src/data.tf:7-10`, `src/environments/acceptance.tfvars:47-52`. **Whether the FIRED alert routes to this same action group is UNVERIFIED[blocked]** — it is not the in-repo alert.

**Direct answer to the prompt's per-field asks (threshold/agg/window/etc.)**: NOT derivable from IaC because the alert is not in IaC. The in-repo Cosmos alerts that DO exist are latency (>99ms) and 429-throttling (>=20), neither of which is NormalizedRUConsumption. The fired alert's exact config must come from the live Azure resource (runtime lane).

---

## Q4 — acceptance vs production RU/throughput config differences

- **A1 FACT** — `cosmos_db_config` block is **byte-identical** between `acceptance.tfvars:18-30` and `production.tfvars:18-30`: same consistency (`Eventual`), mongo version (`7.0`), offer (`Standard`), kind (`MongoDB`), `public_network_access_enabled = false`, single geo_location westeurope failover_priority 0.
- **A1 FACT** — Neither env sets any throughput/RU value (no such field in `var.cosmos_db_config` object — `src/variables.tf:17-31`).
- **A1 FACT** — Only env difference relevant to capacity: prod has TWO token servers (`production.tfvars:32-51`) vs acc ONE (`acceptance.tfvars:32-42`) — token servers are Gurobi license VMs, **NOT** Cosmos RU. No Cosmos throughput difference between envs in IaC.
- **A2 INFER** — Any acc-vs-prod RU difference exists ONLY in live/portal state (out of Terraform per doc:29), not in code. If prod has higher portal-set RU and acc was left at 400 default, that would explain acc firing NormalizedRUConsumption while prod stays quiet — but this is **UNVERIFIED[blocked: live state]**.

---

## Q5 — What does cosmosdb-gurobi-platform-a STORE + WORKLOAD SHAPE

- **A1 FACT** — Cosmos is the **storage backend / data store for the Gurobi Cluster Manager**. `cluster-provisioning.md:9` ("An Azure CosmosDB MongoDB instance that is the data store for the Gurobi Cluster Manager") and `:26-27`.
- **A1 FACT** — The Cluster Manager runs in OpenShift (ArgoCD-deployed) and uses ONLY the CosmosDB connection string secret; it manages its own collections. `cluster-provisioning.md:14, 24, 29`.
- **A1 FACT (workload shape, from ADR C015)** — Gurobi solves optimization problems for the **Fleet Optimizer (FTO)**. The decision was Option 1 (Compute Server license) specifically to **"execute multiple optimizations at the same time for different TSOs"** and enable **parallel execution for multi-TSO and ID (intraday) trading**. `DesignDecisions/.../C015-FleetOptimizer-Gurobi-model/README.md:8-9, 58, 66`.
- **A2 INFER (route-flip support)** — Workload is **bursty / job-driven, NOT steady-state**: FleetOptimizer submits optimization jobs to the cluster manager; the cluster manager queues jobs (ADR mentions queuing, `:39, :69`) and the Cosmos store holds cluster-manager job/queue/node state metadata. Multi-TSO + intraday trading → **scheduled + event-triggered batches of parallel solves**. A 15-minute Average crossing 75% RU is highly consistent with a **transient batch spike** during an optimization run, not sustained saturation.
- **A2 INFER** — The 429-throttling alert comment in IaC corroborates bursty RU pressure: *"We see 429 responses regularly when tasks run on Gurobi. Metrics indicate these are 1 or 2 429's in the monitoring window."* `src/locals.tf:29-30`. The platform team already KNOWS Cosmos briefly throttles during Gurobi task runs and deliberately tuned the 429 alert threshold up to 20 to suppress that noise — strong evidence the RU-consumption alert firing at 77.67% is the **same expected transient spike**, not a capacity incident.

---

## Conditional Route Impact (lane verdict)

Per the prompt's routing table, IaC+docs evidence points to a COMBINATION:

1. **"Expected transient spike, alert mis-tuned" — STRONGEST.** Workload is batch/parallel-solve job-driven (ADR C015), the team already documented + suppressed transient 429s from the same Gurobi task runs (locals.tf:29-30), and the fired alert uses `minFailingPeriodsToAlert 0 / numberOfEvaluationPeriods 0` (no failing-period damping) with a single PT15M Average crossing 77.67% vs 75% — a 2.67-point overshoot. This shape fires on one transient window.

2. **"Provisioned RU insufficient" — PLAUSIBLE but UNVERIFIED.** IaC defaults imply 400 RU/s manual shared. IF live state is still 400 RU/s, 77.67% normalized = recurring pressure and a scale-up (or autoscale enablement) is the real fix. BLOCKED on live throughput read.

3. **"Tune autoscale ceiling" — RULED OUT for IaC.** No autoscale is configured in IaC (and likely not in live, since throughput is unmanaged). N/A unless live state was set to autoscale in-portal.

**Critical cross-lane handoff**: The fired alert is NOT managed by gurobi-infrastructure IaC. Any "fix the alert in code" action targeting this repo is WRONG unless the team first decides to bring this alert into IaC. The runtime lane MUST identify the actual owner of `gurobi-cosmos-normalized-ru-consumption-a` (CCoE policy / portal / another repo) and read live throughput before a fix route is chosen.

## Evidence index (file:line)

- `src/mongodb.tf:1-22` — Cosmos account (no capabilities/free-tier/serverless)
- `src/mongodb.tf:41-45` — `grb_rsm` mongo database (no throughput/autoscale)
- `src/monitoring.tf:19-54` — metric alert resource (for_each over locals, account-scoped)
- `src/locals.tf:4-44` — ONLY two alerts: latency + 429; NO normalized-RU
- `src/locals.tf:29-30` — team comment: Gurobi tasks regularly cause transient 429s
- `src/data.tf:7-10` — action group data lookup
- `src/variables.tf:17-31` — `cosmos_db_config` object (no throughput field)
- `src/environments/acceptance.tfvars:18-52` / `production.tfvars:18-62` — identical cosmos config; AG `ag-trade-platform-a`/`-p`
- `eneco-temp/.../How-To-Guides/Gurobi/cluster-provisioning.md:9,26-29` — Cosmos = Cluster Manager store; throughput NOT managed in Terraform; collections app-managed
- `eneco-temp/.../C015-FleetOptimizer-Gurobi-model/README.md:8-9,58,66` — workload = parallel multi-TSO/intraday optimization solves (FTO)
