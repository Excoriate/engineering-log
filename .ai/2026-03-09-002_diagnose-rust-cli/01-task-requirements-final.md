---
task_id: 2026-03-09-002
agent: coordinator
status: draft
summary: Final requirements — Rust CLI diagnose tool for Service Bus triage
---

# Final Requirements (differs from initial: adds Sonar constraint)

## NEW CRITERION vs initial
Cognitive complexity per function ≤ 15 (Sonar S3776). Enforced by keeping
each function to ONE responsibility. main() = arg parse + call run(). Falsifier:
no function in main.rs exceeds ~30 lines of logic.

## Design
- Binary name: `diagnose`
- Location: runbook/src/main.rs + runbook/Cargo.toml
- Deletes: runbook/diagnose.py (replaced by Cargo project)
- Crates: clap 4.5 (derive), serde_json 1, chrono 0.4 (clock+std)
- All az calls via `std::process::Command` — no network code in binary

## Spec (embedded)

### Cargo.toml
```toml
[package]
name = "diagnose"
version = "0.1.0"
edition = "2021"
[[bin]]
name = "diagnose"
path = "src/main.rs"
[dependencies]
clap = { version = "4", features = ["derive"] }
serde_json = "1"
chrono = { version = "0.4", default-features = false, features = ["clock", "std"] }
```

### main.rs structure
```
fn az_json(args) -> Option<Value>        // one az CLI call → parsed JSON
fn check_auth(sub) -> Option<String>     // az account show
fn get_topics(ns,rg,sub) -> Vec<Topic>   // az servicebus topic list
fn get_subs(ns,rg,sub,topic) -> Vec<Sub> // az topic subscription list + show (detail)
fn get_metric(ns_id,metric,topic,start,end,agg) -> Vec<f64>  // az monitor metrics list
fn get_alert_state(sub,ns_id) -> Option<Essentials>          // az rest AlertsManagement
fn metric_values(data,key) -> Vec<f64>   // extract timeseries values
fn classify(subs) -> Scenario            // pure logic → Scenario enum
fn iso_offset(mins) -> String            // chrono UTC offset
fn fmt_mb(bytes) -> String               // format bytes as MB string
fn run(args) -> i32                      // orchestrate, print, return exit code
fn main()                                // parse + std::process::exit(run(args))
```

### Adversarial
- Q1: az not in PATH → az_json returns None gracefully, error printed, exit 2
- Q5 (probed): --filter NOT --dimension (confirmed live 2026-03-09); dead-letter-message subcommand does not exist (confirmed live 2026-03-09)
