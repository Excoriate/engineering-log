# R2 command-correctness review

## Findings

| # | Severity | Exact command | What breaks | Corrected command |
|---|---|---|---|---|
| 1 | **BLOCKING** | §5c lines 224–225: `(.token\|@sha256? // "")` plus the preceding `@base64d` filter | Standard jq has `@base64` and `@base64d`, but **no `@sha256` formatter**. `?` does not make an undefined formatter valid: jq exits 3, and `set -e` aborts the run. The first jq expression is also logically broken: `($t\|@base64\|"na")=="na"` is always true, so it emits every full auth object. `OLD_AUTH_ID` therefore cannot be a bijective ID. | **C1** below: encode each returned token with jq `@base64`, decode into `sha256sum` outside jq, emit only matching IDs, and accept exactly one match. |
| 2 | **BLOCKING** | Every `oc ... exec "$INFLUXPOD" -- env INFLUX_TOKEN="$INFLUX_TOKEN" influx ...` in §§5c, 6A, 8, 9 | The host shell expands the admin token into the `oc` argv. It is visible in the host process command line and in the transient pod-side `env INFLUX_TOKEN=...` argv before `env` execs `influx`. This directly violates the runbook's no-secret-in-argv invariant. | **C2** below: do not `export` the host variable; stream it over `oc exec -i` stdin, read/export it inside pod `sh`, then `exec influx "$@"`. |
| 3 | **BLOCKING** | §5b: `sh -c 'curl ... -H @<(printf "Authorization: Token %s" ...); ...; rm ...'` | `<(...)` is Bash process substitution, not POSIX `sh`; `sh -n` rejects it at `(`. Even under a shell that accepts it, the final `rm` masks a failed `curl`, so `oc exec` can return 0 after no HTTP probe. | **C3** below: stream the header with `curl -H @-`, save `curl`'s status, print headers, clean up, and exit with that saved status. |
| 4 | **HIGH** | §4a `read ... < <(oc ... \| jq ... \| head -1)`; §4b/§4c `mapfile ... < <(oc ... \| jq ...)` | `set -Eeuo pipefail` does **not** propagate the producer's status out of process substitution. A failed `oc`/jq pipeline can yield partial data while `read`/`mapfile` returns 0. `head -1` also contradicts “exactly one”: it silently chooses the first match and can induce SIGPIPE under `pipefail`. | **C4** below: capture each producer pipeline in a command substitution first, make jq enforce cardinality, then populate variables/arrays. Assignment status now carries the pipeline failure. |
| 5 | **HIGH** | §4b: `select([..\|strings] \| any(test("InfluxDbOptions__Token\|"+$s)))` | `any(test(...))` is valid jq syntax, but this predicate is not authoritative: it selects a Deployment containing **either** the env-var string **or** the Secret name anywhere in the object. It can roll unrelated workloads and omit the actual linkage. `$s` is also interpreted as regex text. | Use the structural filter in **C4**: require an `.env[]` item whose `.name` is exactly `InfluxDbOptions__Token` and whose `.valueFrom.secretKeyRef.name` is exactly `$s`. |
| 6 | **HIGH** | §5a/§7: `az ... -o tsv \| tr -d '\n' \| sha256sum`; §5a: `-o jsonpath="{.data.$SECRET_KEY}"` | `tr -d '\n'` removes newlines stored **inside the secret**, not only Azure CLI's record terminator. It can hide the exact trailing-newline/byte corruption the matrix is meant to diagnose. Dynamic JSONPath also breaks for key names requiring JSONPath escaping. | **C5** below: use JSON plus `jq -j` to emit the value with no formatter-added newline, and index Secret data with `.data[$k]`. |
| 7 | **HIGH** | §7 rollback: `az keyvault secret show --vault-name "$KV" --name influxdb-api-token --id "$OLD_KV_VER" ...` followed by `az keyvault secret set ... --value "$(...)"` | Azure CLI says all other ID arguments must be omitted when `--id` is used. The restore read is therefore invalid/ambiguous. `--value "$(...)"` also expands the old token into the `az` process argv and strips trailing newlines. Separately, any unguarded `set -e` failure after the new secret is set—especially the second `rollout status`—exits without restoring the checkpoint. | **C6** below: download the checkpoint by `--id` into a mode-600 temp file, restore with `secret set --file`, and make the EXIT trap restore on any nonzero exit while `KV_MUTATED=1`. |
| 8 | **HIGH** | §8 KQL: `timestamp > datetime('$SINCE') ... summarize unauthorized=..., total=count()` over `exceptions` only | KQL datetime literal syntax is `datetime(2026-...)`, not `datetime('2026-...')`; the quoted literal can fail to parse. More importantly, `total=count()` counts **exceptions**, not scheduled invocations. A healthy invocation with no exception remains `total=0`, while an unrelated exception can make `total>0`; this cannot prove the stated effect. | **C7** below: use `datetime($SINCE)` and union `requests` with `exceptions`, counting invocation rows separately from unauthorized exception rows. |
| 9 | **HIGH** | §8 Flux: `filter(fn:(r)=> r.run != "Rec0BJKDCC4CT") \|> keep(columns:["_time"]) \|> last()` | Normal points need not have a `run` column; referencing `r.run` can fail on records without that label. `keep` removes `_value`, but `last()` defaults to `_value`, so the pipeline can then fail or return no proof. | **C8** below: exclude the probe by its known measurement, group, run `last(column:"_time")`, then keep `_time`. Positional Flux input to `influx query` itself is valid. |
| 10 | **HIGH** | §8 `NEWPOD=$(oc ... \| jq ... \| head -1)` and fallback `ownerReferences[]?.name\|test($d)` | It chooses an arbitrary Running pod, does not require Ready/non-terminating, hides multiplicity, and treats the Deployment name as an unanchored regex against ReplicaSet names. During rollout it can select the old or wrong pod; an empty result is still inserted into KQL. | **C9** below: derive the Deployment's exact selector, require exactly one Ready non-terminating pod, and let jq error otherwise. If the Deployment legitimately has multiple replicas, iterate every returned pod instead of selecting one. |
| 11 | **MEDIUM** | §5c: `ORG_JSON=$(... 2>/tmp/e.$$ || true)` then `if ! echo "$ORG_JSON" \| jq -e '.'` | `|| true` discards the Influx CLI exit status. Any valid-JSON error body is treated as successful authentication; the test proves only “some JSON parsed.” | **C10** below: put the assignment directly in `if ! ...`; preserve the command status, then validate the expected JSON array shape. |

## Corrected command blocks

### C1 — authorization hash match without jq `@sha256`

```bash
AUTH_MATCHES=$(
  influx_exec auth list --host http://localhost:8086 --json |
    jq -r '.[] | select((.token? // "") != "") | [.id, (.token | @base64)] | @tsv' |
    while IFS=$'\t' read -r id token_b64; do
      h=$(printf '%s' "$token_b64" | base64 -d | sha256sum | awk '{print $1}')
      if [ "$h" = "$POD_HASH" ]; then
        printf '%s\n' "$id"
      fi
    done
)
case "$AUTH_MATCHES" in
  "") OLD_AUTH_ID= ;;
  *$'\n'*) echo "multiple auths match POD_HASH; leaving OLD_AUTH_ID unknown"; OLD_AUTH_ID= ;;
  *) OLD_AUTH_ID=$AUTH_MATCHES ;;
esac
```

If `auth list --json` masks/omits tokens, this intentionally leaves `OLD_AUTH_ID` unknown; it must not guess by description.

### C2 — stdin-only admin-token transport

```bash
INFLUX_TOKEN=$(az keyvault secret show --subscription "$SUB" --vault-name "$KV" \
  --name influxdb-admin-token --query value -o tsv)

influx_exec() {
  printf '%s\n' "$INFLUX_TOKEN" |
    oc -n "$NS" exec -i "$INFLUXPOD" -- sh -c '
      IFS= read -r INFLUX_TOKEN || exit 1
      export INFLUX_TOKEN
      exec influx "$@"
    ' sh "$@"
}

ORG_JSON=$(influx_exec org list --host http://localhost:8086 --json)
BUCKET_JSON=$(influx_exec bucket list --host http://localhost:8086 --org vpp-agg --json)
```

Use `influx_exec` for `auth list`, `auth create`, `query`, and `auth inactive` too. The token exists in the intended `influx` process environment, but not in either host or pod argv.

### C3 — POSIX-`sh` curl probe with preserved status

```bash
oc -n "$NS" exec deploy/strikepricefn -- sh -c '
  body=/tmp/b.$$
  headers=/tmp/h.$$
  printf "Authorization: Token %s\n" "$InfluxDbOptions__Token" |
    curl -sS -o "$body" -w "%{http_code}\n" -D "$headers" -H @- \
      "http://influxdb-eneco-vpp-agg-influxdb2/api/v2/buckets?org=vpp-agg&limit=1"
  rc=$?
  printf "%s\n" "---HEADERS---"
  cat "$headers" 2>/dev/null || true
  rm -f "$body" "$headers"
  exit "$rc"
'
```

The outer single quotes correctly defer `$InfluxDbOptions__Token` expansion to the pod shell.

### C4 — fail-closed discovery and structural writer selection

```bash
SPC_MATCH=$(oc -n "$NS" get secretproviderclass secret-provider-agg-kv -o json |
  jq -er '
    [.spec.secretObjects[]? as $so
     | $so.data[]?
     | select(.objectName == "influxdb-api-token")
     | [$so.secretName, .key]]
    | if length == 1 then .[0] | @tsv
      else error("expected exactly one influxdb-api-token mapping")
      end')
IFS=$'\t' read -r K8S_SECRET SECRET_KEY <<<"$SPC_MATCH"

WRITER_TEXT=$(oc -n "$NS" get deploy -o json |
  jq -r --arg s "$K8S_SECRET" '
    .items[]
    | select(any(.spec.template.spec.containers[]?;
        any(.env[]?;
          .name == "InfluxDbOptions__Token"
          and .valueFrom.secretKeyRef.name == $s)))
    | .metadata.name' |
  sort -u)
[ -n "$WRITER_TEXT" ] || { echo "no writers found; STOP"; exit 1; }
mapfile -t WRITERS <<<"$WRITER_TEXT"

IPOD_TEXT=$(oc -n "$NS" get pods -o json |
  jq -r '.items[]
    | select(.metadata.name | test("influxdb"))
    | select(.status.phase == "Running")
    | select(any(.status.containerStatuses[]?; .ready))
    | .metadata.name')
[ -n "$IPOD_TEXT" ] || { echo "no Ready InfluxDB pod; STOP"; exit 1; }
mapfile -t IPODS <<<"$IPOD_TEXT"
[ "${#IPODS[@]}" -eq 1 ] || { echo "expected exactly one Ready InfluxDB pod; STOP"; exit 1; }
INFLUXPOD=${IPODS[0]}
```

### C5 — byte-exact hashes

```bash
KS_HASH=$(oc -n "$NS" get secret "$K8S_SECRET" -o json |
  jq -rje --arg k "$SECRET_KEY" '.data[$k] // error("secret key missing")' |
  base64 -d | sha256sum | awk '{print $1}')
KV_HASH=$(az keyvault secret show --subscription "$SUB" --vault-name "$KV" \
  --name influxdb-api-token -o json |
  jq -rje '.value // error("Key Vault value missing")' |
  sha256sum | awk '{print $1}')
```

Use the same JSON/`jq -j` form for `NEW_KV_HASH`; do not delete newlines with `tr`.

### C6 — argv-safe rollback that survives `errexit`

```bash
OLD_KV_VER=$(az keyvault secret show --subscription "$SUB" --vault-name "$KV" \
  --name influxdb-api-token --query id -o tsv)
OLDTOK=$(mktemp)
az keyvault secret download --subscription "$SUB" --id "$OLD_KV_VER" \
  --file "$OLDTOK" --overwrite -o none
KV_MUTATED=0

rollback_kv() {
  az keyvault secret set --subscription "$SUB" --vault-name "$KV" \
    --name influxdb-api-token --file "$OLDTOK" -o none
  KV_MUTATED=0
}
```

After the new `secret set --file` succeeds, set `KV_MUTATED=1`. The existing EXIT cleanup must call `rollback_kv || true` whenever its saved exit status is nonzero and `KV_MUTATED==1`, and remove `OLDTOK`. Set `KV_MUTATED=0` only after §8 and §9 succeed. This covers unguarded `set -e` exits as well as explicit rollout failures.

### C7 — KQL that distinguishes invocations from unauthorized exceptions

```bash
az monitor app-insights query --subscription "$SUB" --app "$APPID" \
  --analytics-query "union withsource=Source requests, exceptions
    | where timestamp > datetime($SINCE)
    | where cloud_RoleInstance == '$NEWPOD'
    | summarize invocations=countif(Source == 'requests'),
                unauthorized=countif(Source == 'exceptions' and
                  (outerMessage has 'InfluxDb' or outerMessage has 'Unauthorized'))" \
  -o table
```

The closure predicate is now `invocations>0 && unauthorized==0`; it is no longer inferred from the exception count.

### C8 — valid Flux freshness query

```bash
influx_exec query --host http://localhost:8086 --org vpp-agg \
  'from(bucket:"aggregation")
    |> range(start:-15m)
    |> filter(fn:(r) => r._measurement != "runbook_probe")
    |> group()
    |> last(column:"_time")
    |> keep(columns:["_time"])'
```

### C9 — exact Ready-pod selection

```bash
SELECTOR=$(oc -n "$NS" get deploy "$d" -o json |
  jq -r '.spec.selector.matchLabels
    | to_entries
    | map("\(.key)=\(.value)")
    | join(",")')
NEWPOD=$(oc -n "$NS" get pods -l "$SELECTOR" -o json |
  jq -er '
    [.items[]
     | select(.metadata.deletionTimestamp == null)
     | select(.status.phase == "Running")
     | select(any(.status.conditions[]?;
         .type == "Ready" and .status == "True"))]
    | if length == 1 then .[0].metadata.name
      else error("expected exactly one Ready pod")
      end')
```

### C10 — preserve Influx CLI failure status

```bash
if ! ORG_JSON=$(influx_exec org list --host http://localhost:8086 --json 2>"/tmp/e.$$"); then
  echo "admin token failed ($(cat "/tmp/e.$$")); use §5c-pw"
elif ! printf '%s' "$ORG_JSON" | jq -e 'type == "array"' >/dev/null; then
  echo "unexpected org-list JSON; STOP"
  exit 1
else
  rm -f "/tmp/e.$$"
  ORGID=$(printf '%s' "$ORG_JSON" | jq -r '.[] | select(.name == "vpp-agg") | .id')
fi
```

## Checked non-findings

- `if ! az keyvault secret show ...; then` is safe under `set -e`; the command is in a conditional test.
- Cleanup's `... || true` guards and `az extension add ... || true` do not trigger `errexit`; the following App Insights query still fails closed if the extension is unavailable.
- `any(test(...))` is valid jq; its current predicate is semantically overbroad. `@base64d` is valid jq; `@sha256` is not.
- For the standard InfluxDB 2.x CLI, `org list`, `bucket list`, `auth list`, `auth create --write-bucket`, `auth inactive --id`, `write`, `query`, and their shown `--json`/positional inputs are valid. The defects are token transport, auth matching, and the Flux program.
- Azure CLI accepts `keyvault secret set --file`; `network-rule add/remove --name --ip-address` are valid. Azure CLI explicitly says `secret show --id` must omit `--name`/`--vault-name`.
- On GNU userland in WSL, `date -u ... -d '-10 min'`, `sha256sum`, `base64 -d`, `awk '{print $1}'`, `mktemp`, and `printf` are valid.

## Top-3 must-fix

1. Replace §5c's nonexistent jq `@sha256` and always-true auth filter with C1; current strict-mode execution aborts and cannot produce a valid `OLD_AUTH_ID`.
2. Replace every `oc exec -- env INFLUX_TOKEN=...` with C2; current commands expose the admin token in argv.
3. Replace §5b's `sh -c` process substitution with C3; current command is a pod-shell syntax error and masks `curl` failure.

## Verdict

**NOT-READY**

The runbook contains three blocking first-run failures plus high-severity false-diagnosis, rollback, and verification defects. Evidence executed locally: standard jq rejected `@sha256` with exit 3; the existing first auth filter emitted the entire auth object; `sh -n` rejected `<(...)`; Azure CLI help confirmed `secret set --file`, `secret download --id --file`, and the `show --id` exclusivity rule.
