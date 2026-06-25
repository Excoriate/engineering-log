# Execution evidence — PROD *.vpp.eneco.com TLS rotation (manual, hardened)

started: 2026-06-25 11:30:20 CEST

## Step 0 — session setup + pre-mutation re-verifies — 2026-06-25 11:30:20 CEST
```
login_rc=0  MYIP=84.86.32.39
acct.id=f007df01-9295-491c-b0e9-e3981f2df0b0  acct.type=servicePrincipal
sp.certperms=Backup	Create	Delete	DeleteIssuers	Get	GetIssuers	Import	List	ListIssuers	ManageContacts	ManageIssuers	Purge	Recover	Restore	SetIssuers	Update,
agw.sslcert=https://vpp-appsec-p.vault.azure.net/secrets/wildcard-vpp-eneco-com
agw.versionless_intact=yes  agw.state=Succeeded
fw.baseline_count=0
0  fw.baseline=
verdict=PASS
```

## Step 1 — open KV firewall — 2026-06-25 11:31:56 CEST
```
add_rc=0  myip=84.86.32.39/32  myip_in_rules=
verdict=STOP
```

## Step 1 CORRECTION — 2026-06-25 11:34:46 CEST
```
FINDING: az keyvault show --query 'networkAcls.ipRules' returns EMPTY; correct path = properties.networkAcls.ipRules / network-rule list
Step 1 mutation SUCCEEDED: 84.86.32.39/32 present = yes
baseline (preserve, 6 rules): 132.220.123.93/32 20.8.40.144/32 40.118.58.239/32 40.67.207.92/32 62.145.36.17/32 82.174.84.43/32 
Step 8 MUST remove ONLY 84.86.32.39/32 and leave the baseline intact.
```

## Step 2 — record OLD version + drift — 2026-06-25 11:37:20 CEST
```
read_rc=0
OLD_SID=https://vpp-appsec-p.vault.azure.net/secrets/wildcard-vpp-eneco-com/0f67bce25f4d4277ad586bb8b2e23746
OLD_THUMB=7f62ac0d9d9684e0b8bbc2a7d707ecfbea365216  (NEW would be b8202de20be7fb3fb37e6d5141975282bf33bde7)
OLD_EXP=2026-07-01T23:59:59+00:00  OLD_SUBJ=CN=*.vpp.eneco.com
OLD_VER=0f67bce25f4d4277ad586bb8b2e23746  OLD_enabled=true
verdict=PASS
```

## Step 3 — import NEW version DISABLED — 2026-06-25 11:38:35 CEST
```
import_rc=0
NEW_SID=https://vpp-appsec-p.vault.azure.net/secrets/wildcard-vpp-eneco-com/bce5b66100c44e40b513801951761002
NEW_VER=bce5b66100c44e40b513801951761002  NEW_THUMB=b8202de20be7fb3fb37e6d5141975282bf33bde7  (expect b8202de20be7fb3fb37e6d5141975282bf33bde7)
new_version_enabled=false  versionless_now=b8202de20be7fb3fb37e6d5141975282bf33bde7 (OLD=7f62ac0d9d9684e0b8bbc2a7d707ecfbea365216)
verdict=PASS
```

## Step 3 FINDING — versionless SECRET is SecretDisabled while NEW(disabled) is latest — 2026-06-25 11:41:03 CEST
```
az keyvault secret show (versionless) -> (Forbidden) SecretDisabled
=> KV versionless resolves to LATEST version; if latest is disabled it ERRORS (no fallback to latest-enabled).
=> AGW serves cached OLD now; re-fetch only on config-change (Step 6) or ~4h poll.
=> RISK WINDOW open until Step 5 (enable): if AGW polls now, fetch fails -> possible listener auto-disable.
=> MITIGATION: proceed promptly Step 4 (gate) -> Step 5 (enable) to restore healthy enabled-NEW versionless.
NEW bytes correct: NEW_THUMB=b8202de20be7fb3fb37e6d5141975282bf33bde7 == EXPECT; new version enabled=false.
```

## Step 4 — thumbprint GATE — 2026-06-25 11:41:56 CEST
```
local_PFX=b8202de20be7fb3fb37e6d5141975282bf33bde7
vault_NEW_VER=b8202de20be7fb3fb37e6d5141975282bf33bde7
pinned=b8202de20be7fb3fb37e6d5141975282bf33bde7
gate=PASS
```

## Step 5 — enable NEW version — 2026-06-25 11:42:58 CEST
```
set_rc=0 new.enabled=true
cert_latest=b8202de20be7fb3fb37e6d5141975282bf33bde7 (NEW=b8202de20be7fb3fb37e6d5141975282bf33bde7)
secret_versionless rc=0 resolves_to=bce5b66100c44e40b513801951761002 (NEW_VER=bce5b66100c44e40b513801951761002)
verdict=PASS
```

## Step 6 — force AGW re-pull + restore versionless — 2026-06-25 11:45:24 CEST
```
versioned_rc=0 versionless_rc=0
ssl-cert=https://vpp-appsec-p.vault.azure.net/secrets/wildcard-vpp-eneco-com (expect https://vpp-appsec-p.vault.azure.net/secrets/wildcard-vpp-eneco-com)
provisioningState=Succeeded operationalState=Running
verdict=PASS (control-plane only; wire proof = Step 7)
```

## Step 7 — WIRE VERIFICATION (AVD/internal, run by Alex) — 2026-06-25 11:54:12 CEST
```
All FOUR hosts served: notAfter=Dec 30 23:59:59 2026 GMT
SHA1 Fingerprint=B8:20:2D:E2:0B:E7:FB:3F:B3:7E:6D:51:41:97:52:82:BF:33:BD:E7
  normalized = b8202de20be7fb3fb37e6d5141975282bf33bde7 == EXPECT_THUMB (NEW)
hosts: agg / gurobi / apollo / flex-trade-optimizer .vpp.eneco.com
verdict=PASS — rotation effective end-to-end; all 4 listeners up serving NEW
```

## Step 8 — remove whitelist (finally) — 2026-06-25 11:59:37 CEST
```
removed_my_ip=84.86.32.39/32  my_ip_still_present=0
after=132.220.123.93/32 20.8.40.144/32 40.118.58.239/32 40.67.207.92/32 62.145.36.17/32 82.174.84.43/32 
after_count=6 baseline_count=6 diff_empty=yes
verdict=PASS
```
