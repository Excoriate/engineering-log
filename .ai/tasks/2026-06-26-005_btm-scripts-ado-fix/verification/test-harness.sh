#!/usr/bin/env bash
# Functional test harness for the hardened azure-boards-add-tag.sh.
# Stubs `git` and `az` via a PATH shim; runs the REAL script under scenarios that target the
# adversarial findings (over-harvest, clobber-on-read-failure, unset-TAG non-block).
set -uo pipefail

SCRIPT="/Users/alextorresruiz/Dropbox/@AZUREDEVOPS/eneco-src/enecomanagedcloud/myriad-vpp/Eneco.Vpp.BehindTheMeter/azure-pipelines/steps/azure-boards-add-tag.sh"
SHIM=$(mktemp -d)

cat > "$SHIM/git" <<'EOF'
#!/usr/bin/env bash
# Only `git log -1 --format=%B` is used by the script.
printf '%s\n' "$GIT_BODY"
EOF

cat > "$SHIM/az" <<'EOF'
#!/usr/bin/env bash
# Minimal az boards stub driven by env vars.
args="$*"
case "$args" in
  *"boards query"*)   printf '%s\n' "$QUERY_IDS" ;;                 # one id per line
  *"work-item show"*)
      # extract --id N
      id=""; prev=""; for a in "$@"; do [[ "$prev" == "--id" ]] && id="$a"; prev="$a"; done
      if [[ -n "${SHOW_FAIL_ID:-}" && "$id" == "$SHOW_FAIL_ID" ]]; then
        echo "ERROR: TF400813 simulated show failure for $id" >&2; exit 1
      fi
      eval "printf '%s\n' \"\${SHOW_TAGS_$id:-None}\"" ;;
  *"work-item update"*)
      id=""; fields=""; prev=""; for a in "$@"; do [[ "$prev" == "--id" ]] && id="$a"; [[ "$prev" == "--fields" ]] && fields="$a"; prev="$a"; done
      echo "  >> UPDATE id=$id $fields" ;;
esac
EOF
# Mirror the ubuntu agent's GNU grep (macOS grep is BSD and lacks -P): forward to ggrep.
cat > "$SHIM/grep" <<'EOF'
#!/usr/bin/env bash
exec ggrep "$@"
EOF
chmod +x "$SHIM/git" "$SHIM/az" "$SHIM/grep"
export PATH="$SHIM:$PATH"

run() { echo "----- $1 -----"; shift; ( "$@" ); echo "exit=$?"; echo; }

echo "######## TEST 1: scoped harvest — HEAD merge commit has ONE PR's items; unrelated PR ids in body history are NOT walked (git log -1) ########"
export GIT_BODY=$'Merged PR 183920: Feature 854674\n\nRelated work items: #854674'
export QUERY_IDS=$'854674'
export SHOW_TAGS_854674="DEV"      # already has DEV? no, TAG=ACC here so it should add
TAG=ACC SYSTEM_COLLECTIONURI="https://x/" SYSTEM_TEAMPROJECT="P" run "harvest=#854674 only, TAG=ACC -> union 'DEV; ACC'" bash "$SCRIPT"

echo "######## TEST 2: stray digits on marker line are NOT harvested (only #NNN) ########"
export GIT_BODY=$'Merged PR 999: Title\n\nRelated work items: #123 fixed on 2026-06-26 v1.2'
export QUERY_IDS=$'123'
export SHOW_TAGS_123=""
TAG=DEV SYSTEM_COLLECTIONURI="https://x/" SYSTEM_TEAMPROJECT="P" run "should harvest ONLY 123 (not 2026/06/26/1/2/999)" bash "$SCRIPT"

echo "######## TEST 3: CLOBBER GUARD — show FAILS on item that really has 'ACC; PRD'; must SKIP, not replace ########"
export GIT_BODY=$'Merged PR 1: t\n\nRelated work items: #100'
export QUERY_IDS=$'100'
export SHOW_TAGS_100="ACC; PRD"
export SHOW_FAIL_ID=100
TAG=DEV SYSTEM_COLLECTIONURI="https://x/" SYSTEM_TEAMPROJECT="P" run "show fails for 100 -> NO update line, warn+continue (tags preserved)" bash "$SCRIPT"
unset SHOW_FAIL_ID

echo "######## TEST 4: happy union — existing 'DEV' + TAG=ACC -> 'DEV; ACC' (no clobber) ########"
export GIT_BODY=$'Merged PR 2: t\n\nRelated work items: #200'
export QUERY_IDS=$'200'
export SHOW_TAGS_200="DEV"
TAG=ACC SYSTEM_COLLECTIONURI="https://x/" SYSTEM_TEAMPROJECT="P" run "expect UPDATE System.Tags=DEV; ACC" bash "$SCRIPT"

echo "######## TEST 5: unset TAG must be NON-BLOCKING (exit 0) ########"
export GIT_BODY=$'x'
( unset TAG; SYSTEM_COLLECTIONURI="https://x/" SYSTEM_TEAMPROJECT="P" bash "$SCRIPT" ); echo "exit=$?"

rm -rf "$SHIM"
