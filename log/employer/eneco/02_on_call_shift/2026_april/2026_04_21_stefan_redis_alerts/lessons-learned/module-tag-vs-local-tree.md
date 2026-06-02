---
task_id: 2026-04-21-001
agent: claude-code
status: complete
type: finding
summary: IaC investigation gotcha — when a consumer pins a module via ?ref=vX.Y.Z, reading the local working tree alone can lie about the module's contents. Always read via `git show vX.Y.Z:...` for tag-pinned consumers.
---

# Lesson — module ref vs local working tree

When a Terraform consumer pins a module with `?ref=vX.Y.Z`, the local working
tree of the module repo can be at any commit — including pre-tag commits where
the module's current shape doesn't exist yet.

Concrete in this task: the local `Eneco.Infrastructure` working tree was at a
pre-v2.5.0 commit where the `rediscache` module had no alert resources. Running
`grep` / `Read` directly on the tree would have supported a false claim that
"these alerts don't exist in this repo." The alerts exist — they're in
`git show v2.5.3:terraform/modules/rediscache/variables.tf`, and the consumer
does reach them because that's what `?ref=v2.5.3` fetches at `terraform init`.

## Rule

When investigating a module whose consumer pins a specific ref:
1. Read the consumer's `?ref=...` value first.
2. Read via `git show <ref>:path/to/file`, not via the filesystem.
3. If the working tree differs, note it but treat the tag as authoritative.
4. Git log with `--all` to see commits that may be on remote branches or
   between tags.

This pattern generalizes beyond Terraform: any "source = <vcs>?ref=<rev>"
dependency (Go modules via replace, Python pip git+, npm git#ref, etc.)
makes the on-disk tree a convenience view, not the truth surface.
