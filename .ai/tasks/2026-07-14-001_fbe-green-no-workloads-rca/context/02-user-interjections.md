---
title: "Scope updates — live sandbox and vault evidence"
description: "User-authorized additions to the incident investigation truth surfaces"
version: "1.0"
status: "stable"
category: "investigation"
updated: "2026-07-14"
authors: ["OMP"]
related:
  - ./01-task-requirements-initial.md
---

# Scope updates — live sandbox and vault evidence

## User interjections verbatim

> consider you have aks accesss to sandbox; and can run/fetch all probes you need.

> also check obsidian's vault for fbe incidents.

## Route impact

- Run read-only AKS, Kubernetes, and Argo CD probes against the sandbox/ishtar surface when the environment tooling resolves it.
- Do not repeat the historical finalizer removal; mutation remains outside scope.
- Search the Obsidian vault for prior FBE incidents, recurrence evidence, and the best durable runbook owner.
- Treat current cluster state as recovery/status evidence, not direct proof of the historical state before Fabrizio's fix.
