#!/usr/bin/env bash
# task-workspace-guard.sh - parallel-safe task-workspace guard (PostToolUse).
#
# PURELY PATH-DERIVED authority + PER-SESSION sentinel. No shared singleton, no historical union.
# Each agent (keyed by the hook payload's session_id) owns its own sentinel at
# .ai/runtime/current-task/<session_id>.json -> its own task manifest. One agent NEVER validates
# against another agent's state, so concurrent agents on one repo cannot clobber or false-block
# each other (kills the singleton-clobber and the global-git-status attribution bug).
#
# PostToolUse semantics: exit 2 + stderr is an agent-visible warning; the tool has ALREADY run,
# so this guard advises, it does not prevent. Default non-blocking (TASK_WORKSPACE_GUARD_EXIT=0);
# Claude Code deployments set TASK_WORKSPACE_GUARD_EXIT=2 after verifying warning semantics.
#
# CONCURRENCY MODEL: N processes, ONE local filesystem. Cross-machine concurrency via a synced
# folder (Dropbox/iCloud) is OUT OF SCOPE — those layers do not preserve rename/mkdir atomicity.
#
# PORTABILITY: invoked as `bash <hook>` (settings wire it that way), so bash 3.2 `[[ ]]`/`=~` are
# safe here. No flock, no mapfile. Quote all paths.
set -u

SESSION_MANIFEST=""

INPUT="$(cat 2>/dev/null || true)"
[[ -n "$INPUT" ]] || exit 0

if ! command -v jq >/dev/null 2>&1; then
  echo "TASK WORKSPACE GUARD: jq not found; skipped" >&2
  exit 0
fi

json_field() { printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null || true; }

TOOL="$(json_field '.tool_name // .tool')"
SESSION_ID="$(json_field '.session_id')"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-${CURSOR_PROJECT_DIR:-${GEMINI_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}}}"
[[ "$PROJECT_DIR" = /* && -d "$PROJECT_DIR" ]] || exit 0
GIT_ROOT="$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
[[ -n "$GIT_ROOT" ]] || exit 0
PROJECT_DIR="$GIT_ROOT"
cd "$PROJECT_DIR" || exit 0

EXIT_CODE="${TASK_WORKSPACE_GUARD_EXIT:-0}"

warn_escape() {
  {
    echo "TASK WORKSPACE GUARD: task-scoped artifact outside .ai/tasks/{task_id}_{slug}/"
    echo "Path: $1"
    echo "Move under the current task root unless the user named this exact external path."
  } >&2
  exit "$EXIT_CODE"
}

warn_missing_current_task() {
  {
    echo "TASK WORKSPACE GUARD: write before THIS session has a valid current-task sentinel + manifest"
    echo "Path: $1"
    echo "During preflight create .ai/tasks/{task_id}_{slug}/manifest.json AND"
    echo ".ai/runtime/current-task/\$SESSION_ID.json (per-session sentinel) before load-bearing writes."
  } >&2
  exit "$EXIT_CODE"
}

warn_external_path() {
  {
    echo "TASK WORKSPACE GUARD: external write not authorized in THIS session's task manifest"
    echo "Path: $1"
    echo "Add the exact user-authorized external path to allowed_external_paths in this session's manifest."
  } >&2
  exit "$EXIT_CODE"
}

# Resolve THIS session's task manifest via the per-session sentinel.
# jq failures are treated as TRANSIENT (one retry) to tolerate a concurrent atomic publish,
# never as "unauthorized" (a half-written file must not cause a false block).
session_manifest() {
  [[ -n "$SESSION_ID" ]] || return 1
  local sentinel="$PROJECT_DIR/.ai/runtime/current-task/$SESSION_ID.json"
  [[ -f "$sentinel" ]] || return 1
  local task_id slug task_root phase preflight
  task_id=""; slug=""; task_root=""; phase=""; preflight=""
  for _ in 1 2; do
    task_id="$(jq -r '.task_id // empty' "$sentinel" 2>/dev/null)"
    slug="$(jq -r '.slug // empty' "$sentinel" 2>/dev/null)"
    task_root="$(jq -r '.task_root // empty' "$sentinel" 2>/dev/null)"
    phase="$(jq -r '.phase // empty' "$sentinel" 2>/dev/null)"
    preflight="$(jq -r '.preflight_complete == true' "$sentinel" 2>/dev/null)"
    [[ -n "$task_id" && -n "$slug" && -n "$task_root" ]] && break
    sleep 0.1
  done
  [[ "$preflight" == "true" ]] || return 1
  [[ "$task_id" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{3}$ ]] || return 1
  [[ "$slug" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || return 1
  [[ "$phase" =~ ^[1-8]$ ]] || return 1
  local expected_rel=".ai/tasks/${task_id}_${slug}"
  local expected_abs="$PROJECT_DIR/$expected_rel"
  case "$task_root" in
    "$expected_rel"|"$expected_rel/"|"$expected_abs"|"$expected_abs/"|"tasks/${task_id}_${slug}"|"tasks/${task_id}_${slug}/") ;;
    *) return 1 ;;
  esac
  local manifest="$expected_abs/manifest.json"
  [[ -s "$manifest" ]] || return 1
  # RELAXED schema: require only what the root brain actually produces.
  jq -e --arg t "$task_id" --arg s "$slug" \
    '.task_id==$t and .slug==$s and (.allowed_external_paths|type=="array")' \
    "$manifest" >/dev/null 2>&1 || return 1
  SESSION_MANIFEST="$manifest"
  return 0
}

# Authorize an external path against ONLY this session's manifest (never a union of all tasks).
is_authorized_external_path() {
  session_manifest || return 1
  jq -e --arg p "$1" '(.allowed_external_paths // []) | index($p) != null' \
    "$SESSION_MANIFEST" >/dev/null 2>&1
}

is_escaped_artifact() {
  local rel="$1" base dir
  case "$rel" in
    .ai/tasks/*|.ai/harness/*|.ai/memory/*|.ai/runtime/*|.ai/codebase-context/*) return 1 ;;
    .claude/*|.cursor/*|.codex/*|.gemini/*|.vscode/*) return 1 ;;
    src/*|lib/*|app/*|packages/*|cmd/*|internal/*|pkg/*|docs/*|scripts/*|tests/*|test/*|infra/*|terraform/*|k8s/*|charts/*|ai_agents/*|ai_editors/*|std/*) return 1 ;;
  esac
  case "$rel" in
    diagnostics/*|verification/*|reports/*|prompts/*|scratch/*|analysis/*|probes/*) return 0 ;;
    .ai/diagnostics/*|.ai/verification/*|.ai/reports/*|.ai/prompts/*|.ai/scratch/*|.ai/analysis/*|.ai/probes/*|.ai/templates/*|.ai/tmp/*|.ai/unspecified/*) return 0 ;;
    .ai/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-[0-9][0-9][0-9]_*) return 0 ;;
  esac
  base="${rel##*/}"; dir="${rel%/*}"
  if [[ "$dir" == "$rel" ]]; then
    case "$base" in
      agent-prompt.md|report-template.md|probe-*.md|diagnostic*.md|scratch*.md|analysis*.md) return 0 ;;
    esac
  fi
  return 1
}

requires_current_task() {
  case "$1" in
    .ai/tasks/*|.ai/runtime/*|.ai/harness/*|.ai/memory/*|.ai/codebase-context/*) return 1 ;;
  esac
  return 0
}

case "$TOOL" in
  Bash|shell|run_command)
    # DROP the global `git status` scan: under concurrency it attributes other agents'/worktrees'
    # uncommitted changes to THIS agent and false-blocks. Write enforcement happens on
    # Edit|Write where the path is attributable to this agent.
    exit 0
    ;;
  Edit|Write|write_file|replace|"")
    FILE="$(json_field '.tool_input.file_path // .tool_response.filePath')"
    [[ -n "$FILE" ]] || exit 0
    ;;
  NotebookEdit|notebook_edit)
    FILE="$(json_field '.tool_input.notebook_path // .tool_input.file_path // .tool_response.filePath')"
    [[ -n "$FILE" ]] || exit 0
    ;;
  *)
    exit 0
    ;;
esac

case "$FILE" in
  /*) ABS="$FILE" ;;
  *) ABS="$PROJECT_DIR/$FILE" ;;
esac

# Relative path that escapes the tree (../). Authorize against this session's manifest only.
# Degrade permissively when we cannot attribute the write to an agent (no session_id): a backstop
# that cannot identify the actor must not false-block. Primary enforcement is preflight, not this hook.
case "$FILE" in
  ..|../*|*/..|*/../*)
    if [[ -n "$SESSION_ID" ]]; then is_authorized_external_path "$ABS" || warn_external_path "$FILE"; fi
    exit 0
    ;;
esac

REL="${ABS#"$PROJECT_DIR"/}"
REL="${REL#./}"

# Absolute path outside the project root -> external authorization (this session's manifest only).
if [[ "$REL" == "$ABS" ]]; then
  if [[ -n "$SESSION_ID" ]]; then is_authorized_external_path "$ABS" || warn_external_path "$ABS"; fi
  exit 0
fi

# In-project structural surfaces are always allowed (this is where preflight scaffolds live).
case "$REL" in
  .ai/tasks/*|.ai/runtime/*|.ai/harness/*|.ai/memory/*|.ai/codebase-context/*) exit 0 ;;
  .claude/*|.cursor/*|.codex/*|.gemini/*|.vscode/*) exit 0 ;;
esac

# Escaped task-process artifact (diagnostics/, reports/, ... at a non-task location).
is_escaped_artifact "$REL" && warn_escape "$REL"

# Per-agent preflight obligation: a load-bearing in-project write requires THIS session to have
# scaffolded its own workspace first. Keyed to session_id, so another agent's preflight never
# satisfies it (no repo-level OR) and another agent's absence never blocks it. When session_id is
# absent (unattributable runtime), degrade permissively — the backstop must not false-block.
if [[ -n "$SESSION_ID" ]] && requires_current_task "$REL" && ! session_manifest; then
  warn_missing_current_task "$REL"
fi

exit 0
