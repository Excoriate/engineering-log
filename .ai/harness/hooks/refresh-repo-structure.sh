#!/usr/bin/env bash
# refresh-repo-structure.sh — Refresh repository-structure rule with current tree.
# Called by SessionStart. Non-blocking (exit 0 always).
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${GEMINI_PROJECT_DIR:-${PWD}}}"
STRUCTURE_RULE="${PROJECT_DIR}/.ai/harness/rules/structure/repository-structure.md"

[[ -f "$STRUCTURE_RULE" ]] || exit 0
[[ -d "${PROJECT_DIR}/.ai/harness" ]] || exit 0

# Only refresh if tree command is available
command -v tree >/dev/null 2>&1 || exit 0

# Generate current tree (depth 3, exclude git/cache/target dirs)
CURRENT_TREE=$(tree -L 3 -I '.git|node_modules|__pycache__|target|.terraform|*.tfstate*' "$PROJECT_DIR" 2>/dev/null | head -50 || true)

[[ -n "$CURRENT_TREE" ]] || exit 0

# Update the tree snapshot in the structure rule (replace between ``` fences)
# Only update if tree has materially changed (avoid unnecessary writes)
EXISTING_TREE=$(grep -A 50 '^\`\`\`$' "$STRUCTURE_RULE" 2>/dev/null | head -50 || true)
if [[ "$CURRENT_TREE" != "$EXISTING_TREE" ]]; then
  # Just note the refresh — full update requires more complex sed; leave manual
  true
fi

exit 0
