#!/usr/bin/env bash
# Reproduce the tflint --init attestation panic vs. the signature="pgp" workaround.
# Isolated: uses a throwaway plugin dir so it never touches the shared cache.
set -u
WORK="$(mktemp -d /tmp/tflint-repro.XXXXXX)"
export TFLINT_PLUGIN_DIR="$WORK/plugins"
mkdir -p "$TFLINT_PLUGIN_DIR"
echo "tflint: $(tflint --version 2>&1 | head -1)"
echo "plugin dir: $TFLINT_PLUGIN_DIR"
echo "GITHUB_TOKEN set: $([ -n "${GITHUB_TOKEN:-}" ] && echo yes || echo no)"

run_case () {
  local name="$1" sigline="$2"
  local dir="$WORK/$name"; mkdir -p "$dir"
  cat > "$dir/.tflint.hcl" <<HCL
plugin "azurerm" {
  enabled = true
  version = "0.28.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
  ${sigline}
}
HCL
  echo "############## CASE: $name ##############"
  echo "----- .tflint.hcl -----"; cat "$dir/.tflint.hcl"
  echo "----- rm plugin cache -----"; rm -rf "$TFLINT_PLUGIN_DIR"/* 2>/dev/null
  echo "----- tflint --init -----"
  ( cd "$dir" && tflint --init ) 2>&1
  echo "----- exit code: $? -----"
  echo
}

run_case "default_attestation" ""
run_case "pgp_workaround" 'signature = "pgp"'
echo "WORKDIR=$WORK"
