#!/usr/bin/env bash
# Faithful repro of target line 49-50. ggrep == GNU grep on ubuntu-24.04.
set -uo pipefail
work_items=$(command grep -F 'Related work items:' | ggrep -Po '\d+' | sort -u | paste -sd, - || true)
echo "WORK_ITEMS=[$work_items]"
