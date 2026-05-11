---
task_id: 2026-05-11-002
agent: claude-opus-4-7
status: complete
summary: Final requirements — rotate-the-4-PATs runbook + harvest doc + automation proposal; document-only with embedded probes-to-confirm + rotation commands.
phase: 3
---

# P3 — Final Requirements

## Scope decisions (vs. P1 initial)

| Dimension | P1 initial | P3 final | Delta |
|---|---|---|---|
| PAT scope | "expired ArgoCD secrets" (unclear) | **All 4 PATs** (1 sandbox + 3 MC) | NARROWED to a definitive 4-item list; the 3 MC PATs are explicitly in-scope despite being not-yet-expired |
| Probes | "az/argocd/kubectl... full privileges" | **Documentation includes probes inline**; coordinator does NOT execute rotation | CLARIFIED to "embed probe commands in the runbook for the executor; don't execute them in this task" |
| Adjacent rotation surfaces (F4 AAD SP, ESP cert, TF SP) | Mentioned tangentially | **OUT of scope** for `how-to-rotate.md`; **REFERENCED** in `proposal-rotation-automation.md` as adjacent classes | Sharper |
| Visuals | "include visuals" | **≥1 mermaid + ≥1 ASCII in each of the 3 deliverables** | More explicit |
| [PENDING] block format | "list pending points" | **Each gap is a `[PENDING: ask Fabrizio about <X>]` block with specific context for why it's load-bearing** | More explicit |

## Final deliverable contracts

### Deliverable 1 — `draft-rotation-secrets.md`

**Purpose**: Comprehensive harvest of every claim about the 4 ArgoCD PAT secrets, with source citation per claim.

**Required sections**:

1. The 4 PATs (table with expiry dates + status + ownership)
2. Slack intake summary (timeline of 2026-05-08 → 2026-05-11 events)
3. Vault citations (recipe + pattern + incident + supporting notes — each note's role)
4. Cross-source corroboration table (claim ↔ vault ↔ Slack ↔ wiki ↔ runtime probe ↔ `[UNVERIFIED]`)
5. Source coverage matrix (which claims are A1 FACT, A2 INFER, A3 UNVERIFIED)
6. Open questions to Fabrizio (full list, grouped by topic)

**Hard requirements**:
- Every load-bearing claim has a source citation OR `[UNVERIFIED[<class>: <reason>]]`
- Slack message URLs are quoted verbatim from intake
- Vault note links use the canonical `[[note-name]]` form

### Deliverable 2 — `how-to-rotate.md`

**Purpose**: Step-by-step action-bearing runbook with mermaid + ASCII visuals, embedded probes-to-confirm-state, and rotation commands. The on-call should be able to copy-paste this and rotate the PAT(s).

**Required sections**:

1. When to use this runbook (pattern signatures from the vault pattern doc)
2. Pre-execution gates (G1-G5 + adapted for MC envs)
3. **Section A — Sandbox PAT (`argo-cd-sandbox`)** — adapted from vault recipe with explicit cross-cluster note; includes mermaid flowchart
4. **Section B — MC PATs (`argo-cd-{devmc,accmc,prdmc}-cmc-goldilocks-repository`)** — explicit `[PENDING: ask Fabrizio]` blocks for the unknowns from P2 discovery-map Group A/B/C; includes mermaid showing the conjectured KV→cluster path
5. Verification probes (post-rotation kubectl + curl probes from the pattern doc Step 5+8)
6. Anti-patterns (verbatim from recipe + extended for MC class)
7. Escalation template (Slack message to `#myriad-platform`)
8. Gap list (every `[PENDING: ask Fabrizio about X]` from this doc, deduplicated)

**Hard requirements**:
- ≥1 mermaid diagram (rotation flow)
- ≥1 ASCII diagram (4-PAT topology or KV→cluster propagation)
- Each `[PENDING: ask Fabrizio]` block has: (a) the specific question, (b) why it's load-bearing for the runbook, (c) the probe that would resolve it
- Each command block has a "Decision rule" line (what success looks like; what failure looks like)
- Inline probes BEFORE every state-changing command (verify-before-act)

### Deliverable 3 — `proposal-rotation-automation.md`

**Purpose**: Forward-looking proposal for automation of PAT rotation, framed against the 4 PATs in scope + adjacent classes (F4 AAD SP, ESP cert, TF SP).

**Required sections**:

1. Problem statement (drift: alert exists, SLA doesn't; tribal knowledge; KV-→-cluster mechanism unclear; 4 separate clusters)
2. Current state diagram (mermaid: alert → human → propagation → reconcile)
3. Target state options (3 alternatives — each with named tradeoffs)
   - Option A: Workflow-Identity (Federated Credentials) replacing PATs
   - Option B: ESO ExternalSecret + scheduled KV secret rotation (Logic App / Function)
   - Option C: Status-quo + SLA + ownership + observability (minimal-effort path)
4. Adjacent classes covered by each option (F4 / ESP / TF SP)
5. Sequencing (3-month / 6-month / 12-month proposals)
6. Anti-patterns to NOT propose
7. Open dependencies on Fabrizio / Trade Platform decisions

**Hard requirements**:
- Each option explicitly names: ROI, blast radius, blast-radius mitigation, who owns, how it's verifiable, rollback
- Named tradeoffs — never "X is better"; instead "X trades A for B because Z"

## Verification Strategy (the P5/P8 contract)

### Falsifiers (each will be tested in P8)

| # | Falsifier | How to test |
|---|---|---|
| F1 | If `draft-rotation-secrets.md` has a load-bearing claim WITHOUT source citation or `[UNVERIFIED]` flag → FAIL | grep for unflagged factual sentences; manual sample read |
| F2 | If `how-to-rotate.md` Section B (MC PATs) does NOT explicitly mark KV→cluster sync mechanism as `[PENDING]` → FAIL (would imply false certainty) | grep for "[PENDING: ask Fabrizio]" near "ESO\|CSI\|kubectl patch" |
| F3 | If any command block lacks a "Decision rule" line → FAIL | grep `bash\n` blocks followed by Decision rule |
| F4 | If `how-to-rotate.md` lacks ≥1 mermaid + ≥1 ASCII → FAIL | grep for ```mermaid + ASCII block markers |
| F5 | Gap list in `how-to-rotate.md` is SPLIT into two phases per P8 Linus verdict: Phase-1 surgical set = 3-7 questions (MC-blocking, send FIRST); Phase-2 research set = remaining questions deferred. SC1 ceiling (3-7) wins over earlier floor (≥5). FAIL if Phase-1 has <3 or >7 questions, OR if instruction batches all questions in one send | count + grep for "Phase 1" / "Phase 2" split in §Gap list |
| F6 | If `proposal-rotation-automation.md` has < 3 distinct options with named tradeoffs → FAIL | section count + tradeoff phrasing audit |
| F7 | If any deliverable promotes vault content to FACT without re-citing the underlying Slack/runtime source → Agent Laundering FAIL | sample audit |
| F8 | If escalation template is missing or doesn't include the rotation status fields → FAIL | grep for escalation template section |

### Success Criteria (USER outcome)

- SC1: Alex can hand the `[PENDING]` gap list (extracted from `how-to-rotate.md`) directly to Fabrizio as a focused questionnaire (3-7 surgical questions, not a blank page).
- SC2: Alex (or any on-call) can copy-paste Section A of `how-to-rotate.md` and execute the sandbox PAT rotation TODAY without re-reading the vault notes.
- SC3: Section B is **honest** about MC ambiguity — claims are bounded by [PENDING] markers; nothing is bluffed.
- SC4: The proposal document gives Trade Platform a starting menu of options with explicit tradeoffs.
- SC5: All three deliverables are in `log/employer/eneco/02_on_call_shift/2026_05_11_rotating_expired_argocd_secrets/`.

### Witness ≠ producer

- Verifier in P8 will be `el-demoledor` OR `linus-torvalds` (different agent_type from the P7 attackers `neo-hacker` + `sre-maniac`).
- Coordinator does NOT self-grade — runs P8 falsifier checks but the adversarial-check-the-verification meta-attack is dispatched.

### Truth surface

- External judges: (a) reader (Alex) on understandability, (b) reader (Fabrizio) on whether the [PENDING] list is the right one to surface to him, (c) executor (on-call) on whether Section A actually rotates the sandbox PAT successfully.
- NOT coordinator-only.

## Phase Compression Mode

**Full** — unchanged from P1. CRUBVG=8 (U=2 still — MC env mechanics still unverified).

## Frame composition for P5/P7 (locked in)

- **P5 Adversarial**: `socrates-contrarian` attacks "the rotation procedure is what we think it is" (assumption attack on vault recipe's inheritance)
- **P7 Adversarial 1**: `neo-hacker` attacks rotation procedure trust-boundary (PAT leak surfaces, race conditions during cutover, scope-leakage)
- **P7 Adversarial 2**: `sre-maniac` attacks runbook failure paths (what breaks if Step 5 succeeds but Step 6 hangs; what if MC ESO sync interval is 1 hour)
- **P8 Adversarial**: `el-demoledor` meta-attacks "am I verifying the right thing?"

## Out of scope (firmly)

- Executing the rotation itself (user task, not this task's task)
- F4 AAD SP rotation (referenced in proposal only)
- ESP/Axual cert rotation (referenced in proposal only)
- TF SP credential rotation (referenced in proposal only)
- Building the automation proposed in deliverable 3 (proposal is the deliverable; implementation is future work)
- Changing vault notes (the vault recipe stays as-is; the new runbook supersedes for the 4-PAT scope)
