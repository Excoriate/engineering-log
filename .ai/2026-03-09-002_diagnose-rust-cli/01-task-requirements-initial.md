---
task_id: 2026-03-09-002
agent: coordinator
status: draft
summary: Replace diagnose.py with minimalistic Rust CLI (clap + serde_json + chrono)
---

# Task: Convert diagnose.py → Rust CLI

## Constraints
- Replace diagnose.py entirely — same runbook/ directory
- Crates: clap 4 (derive), serde_json 1, chrono 0.4 (clock+std only)
- stdlib subprocess: std::process::Command for az CLI calls
- Exit: 0 = healthy, 1 = action required, 2 = fatal (auth/az failure)
- NO tokio, NO reqwest, NO external HTTP — all queries via az CLI binary

## Verified cargo
- cargo 1.94.0, rustc 1.94.0
- clap = "4.5.60"

## Falsifier
cargo build --release exits 0 AND ./target/release/diagnose --help shows usage
