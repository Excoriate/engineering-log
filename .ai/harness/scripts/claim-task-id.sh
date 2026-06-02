#!/usr/bin/env bash
# claim-task-id.sh — atomically allocate a collision-free task_id under N concurrent agents.
#
# CONCURRENCY MODEL: N processes, ONE local filesystem. The atomic primitive is a bare
# POSIX `mkdir` (EEXIST = taken). Cross-machine concurrency via Dropbox sync is OUT OF SCOPE:
# Dropbox does NOT preserve mkdir/rename atomicity across the sync boundary, so two agents on
# two machines sharing this tree via Dropbox sync are NOT protected by this script.
#
# PORTABILITY: target macOS bash 3.2.57 — NO flock, NO mapfile, NO ${var,,}, NO bash-only
# `[[ ]]`/`=~`. Written with POSIX `case`/`test`/`grep -E` so it is also safe under sh/zsh.
# All paths are quoted (spaces). set -u (no -e: we inspect exit codes explicitly).
#
# WHY bare mkdir on an NNN-ONLY path (sre-maniac F1, PROVEN): `mkdir` is atomic on the FULL
# path, not on the NNN component. `mkdir .ai/tasks/<date>-001_<slug>` with two different slugs
# both succeed (no EEXIST) → two live dirs, same task_id. The lock MUST be a slug-free path:
# `mkdir .ai/tasks/.locks/<date>-<NNN>`. Only that name carries no slug, so EEXIST actually
# guards the NNN. The slug-bearing task dir mkdir is NOT the lock.
#
# Usage:  claim-task-id.sh <slug> [date]
#   <slug>  required, must match ^[a-z0-9]+(-[a-z0-9]+)*$
#   [date]  optional, defaults to `date +%Y-%m-%d`; must match ^[0-9]{4}-[0-9]{2}-[0-9]{2}$
# Output:  prints ONLY the task_id (e.g. 2026-06-02-001) to stdout. Diagnostics to stderr.
# Exit:    0 on success; nonzero on bad args, symlink guard trip, or 999 exhaustion.

set -u
IFS='
'

err() {
  # Diagnostics go to stderr; stdout is reserved for the task_id alone.
  printf 'claim-task-id: %s\n' "$*" >&2
}

# --- Argument validation -----------------------------------------------------
slug="${1:-}"
if [ -z "$slug" ]; then
  err "missing required argument: <slug>"
  err "usage: claim-task-id.sh <slug> [date]"
  exit 2
fi
# grep -E is portable (BSD + GNU); avoids bash-only [[ =~ ]].
if ! printf '%s' "$slug" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
  err "invalid slug: '$slug' (must match ^[a-z0-9]+(-[a-z0-9]+)*\$)"
  exit 2
fi

date_str="${2:-}"
if [ -z "$date_str" ]; then
  date_str="$(date +%Y-%m-%d)"
fi
if ! printf '%s' "$date_str" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  err "invalid date: '$date_str' (must match ^[0-9]{4}-[0-9]{2}-[0-9]{2}\$)"
  exit 2
fi

# --- Resolve PROJECT_DIR (git root, fallback pwd), physical path -------------
project_dir="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -z "$project_dir" ]; then
  project_dir="$(pwd)"
fi
# Resolve to a physical absolute path (-P avoids symlinked-parent confusion).
# Subshell `cd -P` is portable; realpath is not guaranteed on every host.
project_dir="$(cd -P "$project_dir" 2>/dev/null && pwd -P)" || {
  err "cannot resolve project directory"
  exit 1
}

tasks_dir="$project_dir/.ai/tasks"
locks_dir="$tasks_dir/.locks"

# --- F5 symlink guard --------------------------------------------------------
# `mkdir` resolves a symlinked PARENT (PROVEN): if .ai/tasks is a symlink the lock dir lands
# elsewhere, defeating the lock. Refuse rather than lock through a symlink. We check .ai/tasks
# only if it already exists; a non-existent path is fine (mkdir -p will create a real dir).
if [ -e "$tasks_dir" ] && [ -L "$tasks_dir" ]; then
  err ".ai/tasks is a symlink ('$tasks_dir'); refusing to allocate (F5 symlink guard)"
  exit 1
fi
# Guard the .ai parent too: a symlinked .ai/ relocates the whole tree.
ai_dir="$project_dir/.ai"
if [ -e "$ai_dir" ] && [ -L "$ai_dir" ]; then
  err ".ai is a symlink ('$ai_dir'); refusing to allocate (F5 symlink guard)"
  exit 1
fi

# Create parent dirs ONLY (never the per-NNN lock with -p — that would swallow EEXIST, F2b).
if ! mkdir -p "$locks_dir" 2>/dev/null; then
  err "cannot create locks dir: '$locks_dir'"
  exit 1
fi
# Re-check after creation in case a concurrent actor swapped it for a symlink (TOCTOU).
if [ -L "$tasks_dir" ] || [ -L "$locks_dir" ]; then
  err "lock path became a symlink during setup; aborting (F5 symlink guard)"
  exit 1
fi

# --- F1 NNN-only atomic lock: bounded loop 1..999 ----------------------------
# Each iteration does a fresh bare `mkdir` of the NNN-ONLY path. EEXIST (nonzero) = taken,
# advance to NNN+1. No scan-then-pick (that re-races, F2c). No `mkdir -p` (swallows EEXIST).
task_id=""
n=1
while [ "$n" -le 999 ]; do
  nnn="$(printf '%03d' "$n")"
  lock="$locks_dir/${date_str}-${nnn}"
  if mkdir "$lock" 2>/dev/null; then
    task_id="${date_str}-${nnn}"
    break
  fi
  n=$((n + 1))
done

if [ -z "$task_id" ]; then
  err "exhausted NNN 001..999 for date $date_str; cannot allocate task_id"
  exit 1
fi

# --- Scaffold the slug-bearing task dir (NOT the lock) -----------------------
# Idempotent: mkdir -p never clobbers existing contents. We only create the standard subdirs.
task_dir="$tasks_dir/${task_id}_${slug}"
for sub in "" context plan specs verification subagent-outputs outcome; do
  if [ -z "$sub" ]; then
    target="$task_dir"
  else
    target="$task_dir/$sub"
  fi
  if ! mkdir -p "$target" 2>/dev/null; then
    err "cannot create task subdir: '$target'"
    exit 1
  fi
done

# --- Emit the task_id (ONLY this line on stdout) -----------------------------
printf '%s\n' "$task_id"
exit 0
