#!/usr/bin/env bash
# Faithful repro of target lines 77-86 (the skip + union logic).
set -uo pipefail
current="$1"; TAG="$2"
[[ "$current" == "None" ]] && current=""
if [[ -n "$current" && ";$(tr -d ' ' <<<"$current");" == *";${TAG};"* ]]; then
  echo "SKIP (already has $TAG)"
else
  new_tags="$TAG"; [[ -n "$current" ]] && new_tags="$current; $TAG"
  echo "WRITE new_tags=[$new_tags]"
fi
