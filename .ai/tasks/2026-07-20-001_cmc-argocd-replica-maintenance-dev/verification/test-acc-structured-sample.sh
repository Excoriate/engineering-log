#!/usr/bin/env bash

set -u

RUNBOOK=${1:?usage: test-acc-structured-sample.sh RUNBOOK}

extract_structured_sample() {
  perl -0777 -ne '
    if (/```bash\n(acc_structured_sample\(\) \{.*?\n\}\n\nacc_structured_sample)\n```/s) {
      print $1;
      $found = 1;
    }
    END { exit($found ? 0 : 2) }
  ' "$RUNBOOK"
}

STRUCTURED_SAMPLE=$(extract_structured_sample) || {
  echo 'FAIL: exact structured sample block not found' >&2
  exit 1
}

SERVICE_FIX='{"items":[{"metadata":{"name":"server-svc"},"spec":{"selector":{"app":"server"},"ports":[{"name":"https","port":443,"protocol":"TCP"}]}}]}'
POD_FIX='{"items":[{"metadata":{"name":"server-1","uid":"uid-1","labels":{"app":"server"}},"status":{"podIP":"10.0.0.1","conditions":[{"type":"Ready","status":"True"}]}},{"metadata":{"name":"server-2","uid":"uid-2","labels":{"app":"server"}},"status":{"podIP":"10.0.0.2","conditions":[{"type":"Ready","status":"True"}]}},{"metadata":{"name":"other-ready","uid":"uid-x","labels":{"app":"other"}},"status":{"podIP":"10.0.0.9","conditions":[{"type":"Ready","status":"True"}]}}]}'
ENDPOINT_GOOD_FIX='{"items":[{"metadata":{"name":"server-slice","labels":{"kubernetes.io/service-name":"server-svc"}},"ports":[{"name":"https","port":443,"protocol":"TCP"}],"endpoints":[{"addresses":["10.0.0.1"],"conditions":{"ready":true},"targetRef":{"name":"server-1","uid":"uid-1"}},{"addresses":["10.0.0.2"],"conditions":{"ready":true},"targetRef":{"name":"server-2","uid":"uid-2"}}]}]}'
ENDPOINT_BAD_FIX='{"items":[{"metadata":{"name":"server-slice","labels":{"kubernetes.io/service-name":"server-svc"}},"ports":[{"name":"https","port":443,"protocol":"TCP"}],"endpoints":[{"addresses":["10.0.0.1"],"conditions":{"ready":true},"targetRef":{"name":"server-1","uid":"uid-1"}},{"addresses":["10.0.0.2"],"conditions":{"ready":false},"targetRef":{"name":"server-2","uid":"uid-2"}}]}]}'
APP_GOOD_FIX='{"items":[{"metadata":{"name":"healthy"},"status":{"sync":{"status":"Synced"},"health":{"status":"Healthy"},"reconciledAt":"2026-07-20T10:00:00Z"}},{"metadata":{"name":"degraded"},"status":{"sync":{"status":"Synced"},"health":{"status":"Degraded"},"reconciledAt":"2026-07-20T10:01:00Z"}}]}'
APP_MISSING_FRESHNESS_FIX='{"items":[{"metadata":{"name":"healthy"},"status":{"sync":{"status":"Synced"},"health":{"status":"Healthy"},"reconciledAt":"2026-07-20T10:00:00Z"}},{"metadata":{"name":"stale"},"status":{"sync":{"status":"Synced"},"health":{"status":"Healthy"}}}]}'

run_fixture() {
  fixture_shell=$1
  scenario=$2
  fail_source=$3
  endpoint_fixture=$4
  application_fixture=$5

  {
    printf '%s\n' \
      'ACC_NS=x' \
      'acc_guard(){ [ "$SCENARIO" != guard ] || return 41; }' \
      'acc_oc(){
        case "$*" in
          *"get service -o json"*)
            [ "$FAIL_SOURCE" != service ] || { echo INJECTED_SERVICE_FAILURE >&2; return 42; }
            printf "%s\n" "$SERVICE_FIX"
            ;;
          *"get pods -o json"*)
            [ "$FAIL_SOURCE" != pod ] || { echo INJECTED_POD_FAILURE >&2; return 42; }
            printf "%s\n" "$POD_FIX"
            ;;
          *"get endpointslices.discovery.k8s.io -o json"*)
            [ "$FAIL_SOURCE" != endpoint ] || { echo INJECTED_ENDPOINT_FAILURE >&2; return 42; }
            printf "%s\n" "$ENDPOINT_FIX"
            ;;
          *"get applications.argoproj.io -o json"*)
            [ "$FAIL_SOURCE" != application ] || { echo INJECTED_APPLICATION_FAILURE >&2; return 42; }
            printf "%s\n" "$APP_FIX"
            ;;
          *)
            echo UNEXPECTED_ACC_OC_CALL >&2
            return 99
            ;;
        esac
      }' \
      "$STRUCTURED_SAMPLE"
  } | env \
    SCENARIO="$scenario" \
    FAIL_SOURCE="$fail_source" \
    SERVICE_FIX="$SERVICE_FIX" \
    POD_FIX="$POD_FIX" \
    ENDPOINT_FIX="$endpoint_fixture" \
    APP_FIX="$application_fixture" \
    "$fixture_shell" 2>&1
}

assert_nonzero_named() {
  fixture_shell=$1
  scenario=$2
  fail_source=$3
  expected=$4
  endpoint_fixture=$5
  application_fixture=$6

  output=$(run_fixture "$fixture_shell" "$scenario" "$fail_source" "$endpoint_fixture" "$application_fixture")
  status=$?
  [ "$status" -ne 0 ] || {
    echo "FAIL: false green shell=$fixture_shell scenario=$scenario source=$fail_source" >&2
    exit 1
  }
  printf '%s\n' "$output" | rg -F -q "$expected" || {
    echo "FAIL: missing named failure shell=$fixture_shell expected=$expected" >&2
    exit 1
  }
  if [ "$scenario" = guard ] && printf '%s\n' "$output" | rg -q 'INJECTED_|SELECTED_POD|ENDPOINT|TOTAL|DISTRIBUTION|FRESHNESS'; then
    echo "FAIL: guard allowed downstream evidence shell=$fixture_shell" >&2
    exit 1
  fi
}

for shell_bin in /bin/bash /bin/zsh; do
  assert_nonzero_named "$shell_bin" guard none \
    'STRUCTURED_SAMPLE_FAILED: ACC identity guard' "$ENDPOINT_GOOD_FIX" "$APP_GOOD_FIX"
  assert_nonzero_named "$shell_bin" normal service \
    'STRUCTURED_SAMPLE_FAILED: Service read' "$ENDPOINT_GOOD_FIX" "$APP_GOOD_FIX"
  assert_nonzero_named "$shell_bin" normal pod \
    'STRUCTURED_SAMPLE_FAILED: Pod read' "$ENDPOINT_GOOD_FIX" "$APP_GOOD_FIX"
  assert_nonzero_named "$shell_bin" normal endpoint \
    'STRUCTURED_SAMPLE_FAILED: EndpointSlice read' "$ENDPOINT_GOOD_FIX" "$APP_GOOD_FIX"
  assert_nonzero_named "$shell_bin" normal application \
    'STRUCTURED_SAMPLE_FAILED: Application read' "$ENDPOINT_GOOD_FIX" "$APP_GOOD_FIX"
  assert_nonzero_named "$shell_bin" normal none \
    'STRUCTURED_SAMPLE_FAILED: missing Application reconciledAt' "$ENDPOINT_GOOD_FIX" "$APP_MISSING_FRESHNESS_FIX"

  match_output=$(run_fixture "$shell_bin" normal none "$ENDPOINT_GOOD_FIX" "$APP_GOOD_FIX") || exit 1
  printf '%s\n' "$match_output" | rg -F -q $'SERVING_CHECK\tserver-svc\tuid-1,uid-2\tuid-1,uid-2\tMATCH' || {
    echo "FAIL: matching UIDs did not emit MATCH shell=$shell_bin" >&2
    exit 1
  }
  if printf '%s\n' "$match_output" | rg -q $'^SELECTED_POD\t.*other-ready|uid-x'; then
    echo "FAIL: nonmatching Ready Pod leaked into Service selection shell=$shell_bin" >&2
    exit 1
  fi
  printf '%s\n' "$match_output" | rg -F -q $'EXCEPTION\tdegraded\tSynced\tDegraded\t2026-07-20T10:01:00Z' || {
    echo "FAIL: Degraded Application hidden shell=$shell_bin" >&2
    exit 1
  }

  mismatch_output=$(run_fixture "$shell_bin" normal none "$ENDPOINT_BAD_FIX" "$APP_GOOD_FIX") || exit 1
  printf '%s\n' "$mismatch_output" | rg -F -q $'SERVING_CHECK\tserver-svc\tuid-1,uid-2\tuid-1\tMISMATCH' || {
    echo "FAIL: missing/unready endpoint did not emit MISMATCH shell=$shell_bin" >&2
    exit 1
  }
done

echo 'PASS: current runbook guard/source/freshness/selector/backend/Application discriminators in Bash and zsh'
