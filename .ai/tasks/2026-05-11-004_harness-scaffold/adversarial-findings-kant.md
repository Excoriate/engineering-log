---
task_id: 2026-05-11-004
agent: kant-cognitive-scientist
timestamp: 2026-05-11T00:00:00Z
status: complete

summary: |
  Four cognitive failure modes identified in the harness scaffold. The most
  critical is a dual-surface contradiction: the hook injects the anchor contract
  at session start (primacy zone), but the four alwaysApply rules inject again
  at every turn, creating attention dilution rather than behavioral reinforcement.
  CLAUDE.md is a 21-line stub with a deferred pointer — fine for load order, but
  the pointer itself has no imperative force, so a new agent can satisfy the rule
  by reading the one-line reference without traversing to AGENTS.md. The
  anchor-context-startup rule is 43 lines with a `globs: ["**/*"]` and
  alwaysApply — it WILL be read, but its behavioral force is weak (declarative
  "MUST read" without a falsifiable checkpoint). The hook output is 2981 bytes,
  well under 4 KB.

---

# Adversarial Findings — Kant Cognitive Scientist
## Harness Scaffold Audit — Cognitive Failure Modes

---

**[FINDING-K1] severity: HIGH**

**Claim**: CLAUDE.md is a deferred pointer with no imperative force; a new agent can satisfy it without traversing to AGENTS.md.

**Evidence**: CLAUDE.md is 21 lines. Line 4: `Shared project instructions: '.ai/harness/AGENTS.md' (read it).` The verb "read it" is parenthetical — low-commitment phrasing in training priors. The stub contains no task framing, no consequence for skipping, and no content that would make skipping costly. An agent initializing a session sees CLAUDE.md → satisfies the "I've seen the root file" pattern → proceeds to rules injection. The traversal to AGENTS.md is a second voluntary read that recency bias and task urgency will suppress.

**Mechanism**: Law 4 (Training Prior Supremacy). The root file pattern in training correlates with "I've read the root file → proceed." Nothing about the stub creates a HALT-if-not-traversed forcing function.

**Fix**: Inline the Startup Read-Head (the 8-item list) directly into CLAUDE.md, not as a pointer to AGENTS.md. Or add a hard imperative at top of CLAUDE.md: "DO NOT respond to any user request until you have Read `.ai/harness/AGENTS.md` in full. The instructions there are not optional." Pointer-only = voluntary.

---

**[FINDING-K2] severity: MEDIUM**

**Claim**: Four `alwaysApply: true` rules inject ~196 lines into every turn. Three of the four are maintenance/freshness rules — not runtime behavior constraints. This is attention waste, not behavior change.

**Evidence**: `anchor-context-startup.md` (43 lines), `repository-structure.md` (67 lines), `memory-freshness.md` (53 lines), `ddd-freshness.md` (33 lines). Total: 196 lines injected always.

`memory-freshness.md` and `ddd-freshness.md` govern harness update tasks — they are irrelevant to the primary workflow (on-call incident triage). `repository-structure.md` (67 lines) is a directory map that is high-value once and low-value on every subsequent turn.

**Mechanism**: Law 1 (Conservation of Attention). Every line of a maintenance rule injected during an on-call triage session is attention subtracted from the anchor contract and domain vocabulary pointer. The agent is not more compliant — it is more diluted.

**Fix**: Demote `memory-freshness.md`, `ddd-freshness.md` to `globs: [".ai/memory/**", ".ai/harness/**"]` (trigger only on harness/memory edits). Demote `repository-structure.md` to `alwaysApply: false` with a glob that fires on structural edits. Only `anchor-context-startup.md` has a case for alwaysApply.

---

**[FINDING-K3] severity: MEDIUM**

**Claim**: The `anchor-context-startup` rule uses declarative "MUST read" with no falsifiable behavioral checkpoint — high compliance theater risk.

**Evidence**: The rule body (`.claude/rules/governance/anchor-context-startup.md`) lists 8 numbered steps ending with "Skipping anchor context = working without the map." This is a well-structured mandate, but it contains no mechanism that forces the agent to emit a compliance signal before proceeding. The agent can read the rule, pattern-match "I understand I should read those files," and proceed without reading them — because nothing in the rule requires the agent to declare "I have now read ddd-project.md" before issuing a first tool call.

**Mechanism**: Law 4 (Training Prior Supremacy) + missing axiom. "MUST read X before work" is a common pattern in training data that agents often satisfy by acknowledging the instruction, not by executing it. The rule lacks a synthetic a priori: a required output token that proves compliance.

**Fix**: Add a required preamble to the rule: "Before your first content tool call, emit: `[ANCHOR-LOADED: ddd-project=read, ubiquitous-language=read, lessons-checked=yes/no]`. This token is required. Absence = non-compliance." The emitted token is cheap, externally verifiable, and creates an attention-forcing step.

---

**[FINDING-K4] severity: LOW**

**Claim**: The hook output is within 4 KB budget (2981 bytes, confirmed) and lands in the primacy zone correctly. However, the DDD head-truncation drops the Top Gotchas section — the highest-value operational content.

**Evidence**: `session-start.sh` line 34: `head -n 40 "${HARNESS_DIR}/ddd-project.md"`. The ddd-project.md file is 104 lines. Lines 1–40 cover frontmatter, Task Startup Index table, Identity, Tech Stack, and the start of "Important Files." The Top Gotchas section (the four operational pitfalls: ArgoCD three-plane RBAC, ADO silent state drift, Rootly+Azure convergence, CCoE KV noise) begins at line 77 — outside the 40-line window.

**Mechanism**: Truncation at line 40 preserves the task-routing index (correct) but drops the highest-density operational knowledge. The gotchas are exactly what should fire at session start for on-call work.

**Fix**: Either raise `head -n 40` to `head -n 85` (adds ~120 bytes, stays under 4 KB budget), or extract Top Gotchas into a dedicated `ddd-gotchas-top.md` and add a separate `head -c 600` block for it in the hook after the DDD section.
