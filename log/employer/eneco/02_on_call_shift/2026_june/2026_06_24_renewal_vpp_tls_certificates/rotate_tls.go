// rotate_tls.go - PROD *.vpp.eneco.com wildcard TLS rotation orchestrator (Go CLI).
//
// Why Go here: explicit error returns make "stop on a failed probe" first-class;
// defer gives a guaranteed whitelist-off (the finally); builds to one static binary.
//
// SAFE BY DEFAULT: dry-run unless -execute is passed (dry-run mutates NOTHING).
// Every mutating step ends with a deterministic PROBE that asserts the expected
// value; a failed OR EMPTY read fails the probe and stops (no empty-result is ever
// coerced to the expected value - a silently-failed az query HALTS, it never passes).
// The full `run` removes the KV firewall rule in a defer, so a mid-run failure can
// never leave the vault open. No secret is ever logged (password / SP secret are
// redacted). State (OLD/NEW ids) persists in a JSON file so steps compose and
// rollback knows the OLD version.
//
// Build:  go build -o rotate_tls rotate_tls.go
// Run:    ./rotate_tls -step run                 # full sequence, DRY-RUN
//
//	./rotate_tls -step run -execute        # full sequence, FOR REAL (cleanup guaranteed)
//	./rotate_tls -step import -execute      # one step, for real (then its probe)
//	./rotate_tls -step rollback -execute    # emergency rollback (before Jul 1)
//
// (or `go run rotate_tls.go -step run`)
//
// NOTE: single-step -execute does NOT auto-clean the firewall (only `run` defers
// whitelist-off). If you step manually, always finish with `-step whitelist-off -execute`.
//
// Resource identifiers were verified live on 2026-06-24.
package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

// ---- verified constants ----
const (
	SUB        = "f007df01-9295-491c-b0e9-e3981f2df0b0" // MCC Production - Workload VPP
	RG         = "mcprd-rg-vpp-p-res"
	KV         = "vpp-appsec-p"
	OBJ        = "wildcard-vpp-eneco-com" // KV certificate OBJECT
	AGW        = "vpp-ag-p"
	SSL        = "wildcard-vpp-frontend-https" // AGW ssl-cert RESOURCE (!= KV object)
	SECRETPATH = "/secrets/" + OBJ
	VLESS      = "https://" + KV + ".vault.azure.net" + SECRETPATH // versionless (matches terraform)
	AZCFG      = "/tmp/azsp-prd"                                   // isolated az config
	CRED       = "/tmp/mc-production.env"                          // cached prd SP creds
	STATE      = "/tmp/vpp-rot-state.json"                         // shared state across steps
	WORKDIR    = "/Users/alextorresruiz/Dropbox/@GITHUB/@oss/engineering-log/" +
		"log/employer/eneco/02_on_call_shift/2026_june/" +
		"2026_06_24_renewal_vpp_tls_certificates/certificate_to_renovate"
	PFX            = WORKDIR + "/26061584690-_-vpp-eneco-com.pfx"
	PWF            = WORKDIR + "/certificate_password.txt"
	EXPECT_ENDDATE = "Dec 30" // 2026 - the new cert's notAfter (loose; thumbprint is the strict gate)
)

var (
	HOSTS = []string{"agg.vpp.eneco.com", "gurobi.vpp.eneco.com",
		"apollo.vpp.eneco.com", "flex-trade-optimizer.vpp.eneco.com"}
	dry = true // flipped off by -execute
)

func logln(s string) { fmt.Println("[rotate] " + s) }

func redact(args []string) []string {
	out := make([]string, 0, len(args))
	skip := false
	for _, a := range args {
		if skip {
			out = append(out, "******")
			skip = false
			continue
		}
		if a == "--password" || a == "-p" {
			out = append(out, a)
			skip = true
			continue
		}
		out = append(out, a)
	}
	return out
}

// az runs an `az` command in the isolated config. Dry-run prints (redacted) and returns "".
// On a non-zero exit it returns an error (callers MUST NOT discard it for probe reads).
func az(args ...string) (string, error) {
	full := append([]string{"az"}, args...)
	if dry {
		logln("DRY  " + strings.Join(redact(full), " "))
		return "", nil
	}
	logln("EXEC " + strings.Join(redact(full), " "))
	cmd := exec.Command("az", args...)
	cmd.Env = append(os.Environ(), "AZURE_CONFIG_DIR="+AZCFG)
	out, err := cmd.Output()
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			os.Stderr.Write(ee.Stderr)
		}
		return "", fmt.Errorf("az failed: %s", strings.Join(redact(full), " "))
	}
	return strings.TrimSpace(string(out)), nil
}

// azRead is for PROBE reads: a failed query (error) propagates, and an empty result in
// EXECUTE mode is itself a failure (a query that should return a value but didn't must
// NOT silently pass a downstream probe). In dry-run it returns "" (probes no-op on dry).
func azRead(args ...string) (string, error) {
	v, err := az(args...)
	if err != nil {
		return "", err
	}
	if !dry && v == "" {
		return "", fmt.Errorf("required read returned empty: az %s", strings.Join(redact(args), " "))
	}
	return v, nil
}

// azAllow ignores command failure (used for the idempotent whitelist remove). The SAFETY
// comes from the residual PROBE that follows, not from this command's exit code.
func azAllow(args ...string) {
	if dry {
		logln("DRY  " + strings.Join(redact(append([]string{"az"}, args...)), " "))
		return
	}
	logln("EXEC " + strings.Join(redact(append([]string{"az"}, args...)), " "))
	cmd := exec.Command("az", args...)
	cmd.Env = append(os.Environ(), "AZURE_CONFIG_DIR="+AZCFG)
	_ = cmd.Run()
}

// ---- deterministic probe helpers ----

func expect(label, got, want string) error {
	if dry {
		logln(fmt.Sprintf("  PROBE (expect %s == %q)", label, want))
		return nil
	}
	ok := got == want
	logln(fmt.Sprintf("  PROBE %s: got=%q want=%q -> %s", label, got, want, okstr(ok)))
	if !ok {
		return fmt.Errorf("PROBE FAILED: %s (got %q, want %q)", label, got, want)
	}
	return nil
}

func expectTrue(label string, cond bool, detail string) error {
	if dry {
		logln("  PROBE (expect " + label + ")")
		return nil
	}
	logln(fmt.Sprintf("  PROBE %s: %s %s", label, okstr(cond), detail))
	if !cond {
		return fmt.Errorf("PROBE FAILED: %s %s", label, detail)
	}
	return nil
}

func okstr(b bool) string {
	if b {
		return "OK"
	}
	return "FAIL"
}

// ---- state / creds / local helpers ----

func loadState() map[string]string {
	m := map[string]string{}
	if b, err := os.ReadFile(STATE); err == nil {
		_ = json.Unmarshal(b, &m)
	}
	return m
}

func saveState(kv map[string]string) {
	m := loadState()
	for k, v := range kv {
		m[k] = v
	}
	b, _ := json.MarshalIndent(m, "", "  ")
	_ = os.WriteFile(STATE, b, 0o600)
}

func get(key, def string) string {
	if v, ok := loadState()[key]; ok && v != "" {
		return v
	}
	return def
}

func readCreds() map[string]string {
	m := map[string]string{}
	b, _ := os.ReadFile(CRED)
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		line = strings.TrimPrefix(line, "export ")
		if i := strings.Index(line, "="); i > 0 {
			m[line[:i]] = strings.Trim(line[i+1:], "\"'")
		}
	}
	return m
}

func readPw() string {
	b, _ := os.ReadFile(PWF)
	return strings.TrimSpace(string(b))
}

func getIP() string {
	if dry {
		return "<your-ip>"
	}
	out, _ := exec.Command("curl", "-4", "-s", "--max-time", "10", "ifconfig.me").Output()
	return strings.TrimSpace(string(out))
}

// heldPfxSha1 returns the held PFX leaf SHA1, lower-case hex, no colons (matches az x509ThumbprintHex).
func heldPfxSha1() string {
	if dry {
		return "<held-pfx-sha1>"
	}
	p1 := exec.Command("openssl", "pkcs12", "-in", PFX, "-nokeys", "-clcerts", "-passin", "file:"+PWF, "-legacy")
	b1, _ := p1.Output()
	p2 := exec.Command("openssl", "x509", "-noout", "-fingerprint", "-sha1")
	p2.Stdin = bytes.NewReader(b1)
	b2, _ := p2.Output()
	s := string(b2)
	if i := strings.Index(s, "="); i >= 0 {
		s = s[i+1:]
	}
	s = strings.ReplaceAll(s, ":", "")
	return strings.ToLower(strings.TrimSpace(s))
}

func ensureLogin() error {
	if dry {
		logln("DRY  az login --service-principal -u <id> -p ****** --tenant <t>  (AZURE_CONFIG_DIR=/tmp/azsp-prd)")
		return nil
	}
	c := readCreds()
	cmd := exec.Command("az", "login", "--service-principal", "-u", c["ARM_CLIENT_ID"],
		"-p", c["ARM_CLIENT_SECRET"], "--tenant", c["ARM_TENANT_ID"], "-o", "none", "--only-show-errors")
	cmd.Env = append(os.Environ(), "AZURE_CONFIG_DIR="+AZCFG)
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("service-principal login failed")
	}
	set := exec.Command("az", "account", "set", "-s", SUB)
	set.Env = cmd.Env
	_ = set.Run()
	got, err := azRead("account", "show", "--query", "id", "-o", "tsv")
	if err != nil {
		return err
	}
	return expect("active subscription is prod", got, SUB)
}

func ipRuleCount(ip string) (string, error) {
	return azRead("keyvault", "show", "-n", KV, "-g", RG, "--subscription", SUB,
		"--query", fmt.Sprintf("length(networkAcls.ipRules[?value=='%s/32'])", ip), "-o", "tsv")
}

func verStr(sid string) string { // last path segment of a versioned secret id
	return sid[strings.LastIndex(sid, "/")+1:]
}

// ---------- steps (action + probe) ----------

func stepPreflight() error {
	logln("PREFLIGHT (no mutation)")
	var missing []string
	for _, f := range []string{PFX, PWF, CRED} {
		if _, err := os.Stat(f); err == nil {
			logln("  ok : " + f)
		} else {
			logln("  MISSING: " + f)
			missing = append(missing, f)
		}
	}
	logln("  held cert SHA1 (the value the import must produce): " + heldPfxSha1())
	logln("  REMINDER: OLD cert expires 2026-07-01 -> execute by 2026-06-27 for safe rollback.")
	logln("  REMINDER: verify-effect needs AVD/internal access (prod listeners are private).")
	logln("  REMINDER: confirm no in-flight prd terraform apply during the window.")
	return expectTrue("all required files present", len(missing) == 0, strings.Join(missing, ","))
}

func stepWhitelistOn() error {
	logln("WHITELIST-ON")
	if err := ensureLogin(); err != nil {
		return err
	}
	ip := getIP()
	if err := expectTrue("egress IP resolved", ip != "", "ip="+ip); err != nil {
		return err
	}
	saveState(map[string]string{"ip": ip})
	if _, err := az("keyvault", "network-rule", "add", "--name", KV, "-g", RG,
		"--subscription", SUB, "--ip-address", ip+"/32", "-o", "none"); err != nil {
		return err
	}
	logln("  added " + ip + "/32; waiting 25s for firewall propagation")
	logln("  NOTE: if you are running steps individually, remember to run whitelist-off when done.")
	if !dry {
		time.Sleep(25 * time.Second)
	}
	n, err := ipRuleCount(ip)
	if err != nil {
		return err
	}
	return expect("KV firewall rule present", n, "1")
}

func stepBaseline() error {
	logln("BASELINE (record OLD version for rollback)")
	if err := ensureLogin(); err != nil {
		return err
	}
	sid, err := az("keyvault", "certificate", "show", "--vault-name", KV, "--name", OBJ, "--query", "sid", "-o", "tsv")
	if err != nil {
		return err
	}
	thumb, err := az("keyvault", "certificate", "show", "--vault-name", KV, "--name", OBJ, "--query", "x509ThumbprintHex", "-o", "tsv")
	if err != nil {
		return err
	}
	enabled, err := az("keyvault", "certificate", "show", "--vault-name", KV, "--name", OBJ, "--query", "attributes.enabled", "-o", "tsv")
	if err != nil {
		return err
	}
	thumb = strings.ToLower(thumb)
	if dry { // placeholders so later dry-run commands and probes read cleanly
		sid, thumb, enabled = "<OLD_SID>", "<OLD_THUMB>", "true"
	}
	saveState(map[string]string{"old_sid": sid, "old_thumb": thumb, "old_enabled": enabled})
	logln("  OLD sid=" + sid)
	logln("  OLD thumb=" + thumb + " enabled=" + enabled)
	if err := expectTrue("OLD sid is a versioned id for the object",
		dry || strings.Contains(sid, SECRETPATH+"/"), "sid="+sid); err != nil {
		return err
	}
	// real value compared; an empty/failed read above already returned, and "" != "true" would fail here too
	return expect("OLD version is enabled (valid rollback target)", enabled, "true")
}

func stepImport() error {
	logln("IMPORT (new version, DISABLED so it is not live before the gate)")
	if err := ensureLogin(); err != nil {
		return err
	}
	pw := "<pfx-password>"
	if !dry {
		pw = readPw()
	}
	out, err := az("keyvault", "certificate", "import", "--vault-name", KV, "--name", OBJ,
		"--file", PFX, "--password", pw, "--disabled", "-o", "json")
	if err != nil {
		return err
	}
	if dry {
		saveState(map[string]string{"new_sid": "<NEW_SID>", "new_ver": "<NEW_VER>", "new_thumb": "<NEW_THUMB>"})
	} else {
		var j struct {
			ID    string `json:"id"`
			Sid   string `json:"sid"`
			Thumb string `json:"x509ThumbprintHex"`
		}
		if err := json.Unmarshal([]byte(out), &j); err != nil {
			return fmt.Errorf("could not parse import output: %v", err)
		}
		if j.ID == "" || j.Sid == "" || j.Thumb == "" {
			return fmt.Errorf("import output missing id/sid/thumbprint")
		}
		saveState(map[string]string{"new_sid": j.Sid, "new_ver": verStr(j.ID), "new_thumb": strings.ToLower(j.Thumb)})
		logln("  imported version " + verStr(j.ID))
	}
	ver := get("new_ver", "<NEW_VER>")
	en, err := azRead("keyvault", "certificate", "show", "--vault-name", KV, "--name", OBJ, "--version", ver, "--query", "attributes.enabled", "-o", "tsv")
	if err != nil {
		return err
	}
	return expect("new version is DISABLED after import", en, "false")
}

func stepVerifyImport() error {
	logln("VERIFY-IMPORT (gate: imported thumbprint == held PFX, case-normalized)")
	expectV := heldPfxSha1()
	got := get("new_thumb", "<NEW_THUMB>")
	logln("  expect(held PFX) = " + expectV)
	logln("  got(KV new)      = " + got)
	return expect("imported cert matches held PFX", got, expectV)
}

func stepEnable() error {
	logln("ENABLE (new version becomes latest-enabled)")
	if err := ensureLogin(); err != nil {
		return err
	}
	ver := get("new_ver", "<NEW_VER>")
	if _, err := az("keyvault", "certificate", "set-attributes", "--vault-name", KV, "--name", OBJ,
		"--version", ver, "--enabled", "true", "-o", "none"); err != nil {
		return err
	}
	en, err := azRead("keyvault", "certificate", "show", "--vault-name", KV, "--name", OBJ, "--version", ver, "--query", "attributes.enabled", "-o", "tsv")
	if err != nil {
		return err
	}
	if err := expect("new version enabled", en, "true"); err != nil {
		return err
	}
	latest, err := azRead("keyvault", "certificate", "show", "--vault-name", KV, "--name", OBJ, "--query", "x509ThumbprintHex", "-o", "tsv")
	if err != nil {
		return err
	}
	return expect("latest-enabled thumbprint == new", strings.ToLower(latest), get("new_thumb", "<NEW_THUMB>"))
}

func stepRefresh() error {
	logln("REFRESH (force AGW re-pull; empty 'update' does NOT work - MS docs Resolution E)")
	if err := ensureLogin(); err != nil {
		return err
	}
	newSid := get("new_sid", "<NEW_SID>")
	if _, err := az("network", "application-gateway", "ssl-cert", "update", "-g", RG,
		"--gateway-name", AGW, "-n", SSL, "--key-vault-secret-id", newSid, "-o", "none"); err != nil {
		return err
	}
	logln("  repointed AGW ssl-cert to the NEW versioned URI (a keyVaultSecretId change forces re-pull)")
	if _, err := az("network", "application-gateway", "ssl-cert", "update", "-g", RG,
		"--gateway-name", AGW, "-n", SSL, "--key-vault-secret-id", VLESS, "-o", "none"); err != nil {
		logln("  !!! RESTORE-TO-VERSIONLESS FAILED - AGW may be left on the versioned URI (autorotation off + terraform drift).")
		logln("      Restore manually: az network application-gateway ssl-cert update -g " + RG + " --gateway-name " + AGW + " -n " + SSL + " --key-vault-secret-id " + VLESS)
		return err
	}
	logln("  restored the versionless URI (keeps autorotation + matches terraform)")
	state, err := azRead("network", "application-gateway", "show", "-g", RG, "-n", AGW, "--query", "provisioningState", "-o", "tsv")
	if err != nil {
		return err
	}
	if err := expect("AGW provisioningState", state, "Succeeded"); err != nil {
		return err
	}
	kvsid, err := azRead("network", "application-gateway", "ssl-cert", "show", "-g", RG,
		"--gateway-name", AGW, "-n", SSL, "--query", "keyVaultSecretId", "-o", "tsv")
	if err != nil {
		return err
	}
	return expectTrue("ssl-cert restored to versionless URI",
		dry || strings.HasSuffix(strings.TrimRight(kvsid, "/"), SECRETPATH), "kvSecretId="+kvsid)
}

func stepVerifyEffect() error {
	logln("VERIFY-EFFECT (the real proof - run these from AVD / internal network)")
	for _, h := range HOSTS {
		logln(fmt.Sprintf("  echo | openssl s_client -connect %s:443 -servername %s | openssl x509 -noout -enddate -fingerprint -sha1", h, h))
	}
	logln(fmt.Sprintf("  PROBE (expect notAfter contains %q ... 2026 AND thumbprint == new on ALL four hosts)", EXPECT_ENDDATE))
	if !dry {
		c := exec.Command("bash", "-c",
			"echo | openssl s_client -connect gurobi.vpp.eneco.com:443 -servername gurobi.vpp.eneco.com 2>/dev/null | openssl x509 -noout -enddate")
		out, _ := c.Output()
		s := strings.TrimSpace(string(out))
		if s == "" {
			logln("  gurobi public (best-effort from here): unreachable - MUST verify from AVD")
		} else if strings.Contains(s, EXPECT_ENDDATE) {
			logln("  gurobi public served-cert expiry: " + s + "  -> OK (matches new cert)")
		} else {
			logln("  gurobi public served-cert expiry: " + s + "  -> MISMATCH, investigate before declaring success")
		}
	}
	return nil
}

func stepWhitelistOff() error {
	logln("WHITELIST-OFF (idempotent; runs in the defer of a full run)")
	ip := get("ip", "")
	if ip == "" {
		ip = getIP()
	}
	if err := ensureLogin(); err != nil {
		return err
	}
	azAllow("keyvault", "network-rule", "remove", "--name", KV, "-g", RG,
		"--subscription", SUB, "--ip-address", ip+"/32", "-o", "none")
	n, err := ipRuleCount(ip)
	if err != nil {
		logln("  !!! could NOT confirm the firewall residual - REMOVE MANUALLY and verify:")
		logln(fmt.Sprintf("      az keyvault network-rule remove --name %s -g %s --subscription %s --ip-address %s/32", KV, RG, SUB, ip))
		return err
	}
	if !dry && n != "0" {
		logln(fmt.Sprintf("  !!! KV FIREWALL STILL OPEN for %s/32 - remove manually:", ip))
		logln(fmt.Sprintf("      az keyvault network-rule remove --name %s -g %s --subscription %s --ip-address %s/32", KV, RG, SUB, ip))
	}
	return expect("KV firewall residual for our IP", n, "0")
}

func stepRollback() error {
	logln("ROLLBACK (emergency; only useful while OLD cert is unexpired, i.e. before Jul 1)")
	if err := ensureLogin(); err != nil {
		return err
	}
	oldSid := get("old_sid", "<OLD_SID>")
	newVer := get("new_ver", "<NEW_VER>")
	// R-4: re-check the OLD version is STILL enabled NOW before pointing prod at it.
	// Pointing AGW at a disabled/unresolvable version => listener auto-disable => outage.
	oldEn, err := azRead("keyvault", "certificate", "show", "--vault-name", KV, "--name", OBJ,
		"--version", verStr(oldSid), "--query", "attributes.enabled", "-o", "tsv")
	if err != nil {
		return err
	}
	if err := expect("OLD version still enabled (rollback target resolvable)", oldEn, "true"); err != nil {
		logln("  !!! OLD version is NOT enabled - aborting rollback (would disable the listener). Escalate / fix forward.")
		return err
	}
	if _, err := az("network", "application-gateway", "ssl-cert", "update", "-g", RG,
		"--gateway-name", AGW, "-n", SSL, "--key-vault-secret-id", oldSid, "-o", "none"); err != nil {
		return err
	}
	if _, err := az("keyvault", "certificate", "set-attributes", "--vault-name", KV, "--name", OBJ,
		"--version", newVer, "--enabled", "false", "-o", "none"); err != nil {
		return err
	}
	logln("  AGW repointed to the OLD versioned URI + new version disabled")
	kvsid, err := azRead("network", "application-gateway", "ssl-cert", "show", "-g", RG,
		"--gateway-name", AGW, "-n", SSL, "--query", "keyVaultSecretId", "-o", "tsv")
	if err != nil {
		return err
	}
	if err := expect("ssl-cert points at OLD sid", kvsid, oldSid); err != nil {
		return err
	}
	en, err := azRead("keyvault", "certificate", "show", "--vault-name", KV, "--name", OBJ, "--version", newVer, "--query", "attributes.enabled", "-o", "tsv")
	if err != nil {
		return err
	}
	logln("  NOTE: AGW pinned to a versioned URI (temporary terraform drift) - restore versionless after a good cert.")
	return expect("new version disabled", en, "false")
}

func runAll() (err error) {
	logln("FULL SEQUENCE (each step is probe-gated; a failed probe stops here)")
	if err = stepPreflight(); err != nil {
		return err
	}
	// from here on, guarantee whitelist-off on ANY return path (the finally)
	defer func() {
		if ce := stepWhitelistOff(); ce != nil && err == nil {
			err = ce
		}
	}()
	for _, s := range []func() error{
		stepWhitelistOn, stepBaseline, stepImport, stepVerifyImport, stepEnable, stepRefresh, stepVerifyEffect,
	} {
		if err = s(); err != nil {
			return err
		}
	}
	logln("Control-plane sequence OK. NOT YET VERIFIED: run the verify-effect handshakes from AVD -")
	logln("the rotation is UNVERIFIED until all 4 hosts serve Dec 30 2026 + the new thumbprint.")
	logln("If that handshake fails, run:  rotate_tls -step rollback -execute  (before Jul 1)")
	return nil
}

func main() {
	execute := flag.Bool("execute", false, "actually mutate Azure (default: dry-run, mutates nothing)")
	step := flag.String("step", "", "step: preflight|whitelist-on|baseline|import|verify-import|enable|refresh|verify-effect|whitelist-off|rollback|run")
	flag.Parse()
	if *step == "" && flag.NArg() >= 1 {
		*step = flag.Arg(0)
	}
	dry = !*execute
	mode := "DRY-RUN"
	if *execute {
		mode = "EXECUTE"
	}
	logln(fmt.Sprintf("mode = %s   step = %s", mode, *step))

	steps := map[string]func() error{
		"preflight": stepPreflight, "whitelist-on": stepWhitelistOn, "baseline": stepBaseline,
		"import": stepImport, "verify-import": stepVerifyImport, "enable": stepEnable,
		"refresh": stepRefresh, "verify-effect": stepVerifyEffect,
		"whitelist-off": stepWhitelistOff, "rollback": stepRollback, "run": runAll,
	}
	fn, ok := steps[*step]
	if !ok {
		fmt.Fprintf(os.Stderr, "unknown -step %q\n", *step)
		flag.Usage()
		os.Exit(2)
	}
	if err := fn(); err != nil {
		logln("ERROR: " + err.Error())
		os.Exit(1)
	}
}
