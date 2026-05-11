#!/usr/bin/env bash
# session-end.sh — Health check at session end. Writes/clears harness-health-report.md.
# Always exits 0 (non-blocking).
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${CURSOR_PROJECT_DIR:-$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null || pwd)}}"
HARNESS_DIR="${PROJECT_DIR}/.ai/harness"
MEMORY_DIR="${PROJECT_DIR}/.ai/memory"
REPORT="${PROJECT_DIR}/.ai/harness-health-report.md"

[[ -d "$HARNESS_DIR" ]] || exit 0

gaps=()

required_governance=(
  anchor-context-startup.md memory-freshness.md ddd-freshness.md
  root-files-freshness.md specs-driven.md harness-self-improvement.md
  anti-slop-gate.md adversarial-dispatch-discipline.md
  actionable-artifact-gate.md rules-codebase-sync.md
)

# DDD files
[[ -s "$HARNESS_DIR/ddd-project.md" ]] || gaps+=("ACTION: Populate .ai/harness/ddd-project.md")
[[ -s "$HARNESS_DIR/ddd-ubiquitous-language.md" ]] || gaps+=("ACTION: Populate .ai/harness/ddd-ubiquitous-language.md")
grep -q '{{' "$HARNESS_DIR/ddd-project.md" 2>/dev/null && gaps+=("ACTION: Fill placeholders in ddd-project.md")

# Lessons
[[ -f "$MEMORY_DIR/lessons-learned.json" ]] || gaps+=("ACTION: Create .ai/memory/lessons-learned.json")

# Governance rules
for rule in "${required_governance[@]}"; do
  [[ -f "$HARNESS_DIR/rules/governance/$rule" ]] || gaps+=("ACTION: Create governance/$rule")
done

# Root files
for root in AGENTS.md CLAUDE.md GEMINI.md; do
  [[ -s "$PROJECT_DIR/$root" ]] || gaps+=("ACTION: Create $root")
done

# Write or clear report
if [[ ${#gaps[@]} -gt 0 ]]; then
  {
    printf '# Harness Health Report\n\n> Fix these before other work.\n\n**%d gap(s):**\n\n' "${#gaps[@]}"
    n=1; for gap in "${gaps[@]}"; do printf '%d. %s\n' "$n" "$gap"; ((n++)); done
    printf '\n---\nGenerated: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$REPORT"
else
  rm -f "$REPORT"
fi

# Attestation for Second Brain NN-6 memory gate
ATTESTATION="${PROJECT_DIR}/.ai/runtime/second-brain/consolidation-attestation.json"
mkdir -p "$(dirname "$ATTESTATION")" 2>/dev/null || true
if [[ ! -f "$ATTESTATION" ]]; then
  SECOND_BRAIN_ROOT="${SECOND_BRAIN_PATH:-${SECOND_BRAIN_VAULT_LOCAL:-}}"
  if [[ -z "$SECOND_BRAIN_ROOT" ]] || [[ ! -s "${SECOND_BRAIN_ROOT}/llm-wiki/_index.md" ]]; then
    status="memory_system_unavailable"; reason="vault not configured or missing llm-wiki"
  else
    status="no_durable_learnings"; reason="session-end health check ran; consolidate skill not invoked"
  fi
  printf '{"status":"%s","reason":"%s","session_id":"%s","timestamp":"%s"}\n' \
    "$status" "$reason" "${CLAUDE_SESSION_ID:-unknown}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    > "$ATTESTATION"
fi

exit 0
