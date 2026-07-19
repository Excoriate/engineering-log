#!/usr/bin/env bash
# Version-matched (v0.63.1 = CI version) experiment: default vs pgp vs forced-keyless.
set -u
ARCH="darwin_arm64"
VER="0.63.1"
BIN="$(mktemp -d /tmp/tflint-bin.XXXXXX)"
echo "=== downloading tflint v$VER ($ARCH) ==="
curl -fsSL -o "$BIN/tflint.zip" "https://github.com/terraform-linters/tflint/releases/download/v${VER}/tflint_${ARCH}.zip" || { echo "download FAILED"; exit 1; }
unzip -oq "$BIN/tflint.zip" -d "$BIN" || { echo "unzip FAILED"; exit 1; }
TFLINT="$BIN/tflint"
chmod +x "$TFLINT"
echo "using: $($TFLINT --version 2>&1 | head -1)"
WORK="$(mktemp -d /tmp/tflint-matrix.XXXXXX)"
export TFLINT_PLUGIN_DIR="$WORK/plugins"; mkdir -p "$TFLINT_PLUGIN_DIR"
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
  echo "############## CASE: $name (line: '${sigline:-<none>}') ##############"
  rm -rf "$TFLINT_PLUGIN_DIR"/* 2>/dev/null
  ( cd "$dir" && "$TFLINT" --init ) 2>&1
  echo "----- exit: $? -----"; echo
}

run_case "default"        ""
run_case "pgp"            'signature = "pgp"'
run_case "force_keyless"  'signature = "keyless"'
echo "BIN=$BIN WORK=$WORK"
