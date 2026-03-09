---
task_id: 2026-03-09-002
agent: coordinator
status: draft
summary: Plan for Rust CLI diagnose tool
---
# Plan

## Steps
1. Write Cargo.toml
2. Write src/main.rs
3. cargo build --release (falsifier: exit 0)
4. ./target/release/diagnose --help (falsifier: shows usage)
5. Delete diagnose.py

## Adversarial Challenge
Q1: az binary missing → az_json catches Err from Command::new, returns None, run() exits 2 with clear message.
Q5 probed: --filter confirmed live; dead-letter-message subcommand confirmed absent.
