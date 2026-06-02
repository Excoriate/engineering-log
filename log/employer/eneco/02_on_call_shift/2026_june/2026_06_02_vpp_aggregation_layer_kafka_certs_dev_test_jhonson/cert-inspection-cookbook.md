---
title: "Cert inspection cookbook — run these locally against ./certs/"
timestamp: 2026-06-02
status: complete
category: on-call
---

# Cert Inspection Cookbook (local, copy-paste)

Run everything from the `certs/` folder:

```bash
cd "log/employer/eneco/02_on_call_shift/2026_june/2026_06_02_vpp_aggregation_layer_kafka_certs_dev_test_jhonson/certs"
```

Files: `kafka-cacert.pem` (CA), `kafka-clientcert.pem` (full chain), `kafka-clientcert-leaf.pem`
(leaf only), `kafka-sslkey.pem` (**private key — never paste its contents anywhere**).

Every block below was actually run against the downloaded files; the shown output is real.

---

## 1. Is it even a valid PEM? (integrity / shape)

```bash
file *.pem
```
```text
kafka-cacert.pem:          PEM certificate
kafka-clientcert-leaf.pem: PEM certificate
kafka-clientcert.pem:      PEM certificate
kafka-sslkey.pem:          ASCII text          # a PEM key; `file` just doesn't label keys
```

```bash
# Count cert blocks (chain should be > 1); confirm BEGIN/END parity
grep -c -- '-----BEGIN CERTIFICATE-----' kafka-clientcert.pem   # => 3
grep -c -- '-----END CERTIFICATE-----'   kafka-clientcert.pem   # => 3
# Hard proof it parses (exit 0 = good PEM):
openssl x509 -in kafka-cacert.pem -noout && echo "PARSES OK"
```

**The "is it corrupt?" test** — if a value looks broken, check for the JSON-escape artifact:

```bash
grep -cF '\n' kafka-cacert.pem    # => 0  (literal backslash-n = mangled; 0 = clean)
grep -c  $'\r' kafka-cacert.pem   # => 0  (CRLF = 0 is good)
```

---

## 2. Identity + validity + fingerprint (the metadata people ask for)

```bash
openssl x509 -in kafka-cacert.pem -noout -subject -issuer -startdate -enddate -serial
openssl x509 -in kafka-cacert.pem -noout -fingerprint -sha256
```
```text
subject=C=NL, O=Trust Provider B.V., OU=Domain Validated SSL, CN=Trust Provider B.V. TLS RSA CA G1
issuer =C=US, O=DigiCert Inc, OU=www.digicert.com, CN=DigiCert Global Root G2
notBefore=Nov  2 12:25:10 2017 GMT
notAfter =Nov  2 12:25:10 2027 GMT
serial=0EC411EDF002F73036C4E5D42F3E34F2
sha256 Fingerprint=00:98:71:C3:A4:...:60:7C
```

Full human-readable dump (everything):

```bash
openssl x509 -in kafka-clientcert-leaf.pem -noout -text   # all fields, extensions, key info
```

SAN + Extended Key Usage (does it actually allow *client* auth?):

```bash
openssl x509 -in kafka-clientcert-leaf.pem -noout -ext subjectAltName,extendedKeyUsage
```
```text
X509v3 Subject Alternative Name:
    DNS:esp-eet-vpp-dt.streaming.eneco.com
X509v3 Extended Key Usage:
    TLS Web Server Authentication, TLS Web Client Authentication   # <-- clientAuth present
```

---

## 3. Enumerate the chain (one clean command)

```bash
openssl crl2pkcs7 -nocrl -certfile kafka-clientcert.pem | openssl pkcs7 -print_certs -noout
```
```text
subject=CN=esp-eet-vpp-dt.streaming.eneco.com         issuer=...Trust Provider B.V. TLS RSA CA G1   # leaf
subject=...Trust Provider B.V. TLS RSA CA G1          issuer=...DigiCert Global Root G2             # intermediate
subject=...DigiCert Global Root G2                    issuer=...DigiCert Global Root G2             # root (self-signed)
```

Leaf-first order is correct for both librdkafka and Java.

---

## 4. Expiry — exact dates and machine-checkable countdown

```bash
openssl x509 -in kafka-clientcert-leaf.pem -noout -enddate          # notAfter=Jan  9 23:59:59 2027 GMT
openssl x509 -in kafka-clientcert-leaf.pem -checkend 0       && echo "NOT expired"   || echo "EXPIRED"
openssl x509 -in kafka-clientcert-leaf.pem -checkend 2592000 && echo ">30 days left" || echo "<30 days left"
```
```text
NOT expired
>30 days left
```

`-checkend N` exits non-zero if the cert expires within N seconds — perfect for a cron/alert.

---

## 5. Does the private key match the cert? (3 independent ways, no key bytes exposed)

```bash
# (a) modulus fingerprints must match
openssl x509 -in kafka-clientcert-leaf.pem -noout -modulus | openssl md5
openssl rsa  -in kafka-sslkey.pem          -noout -modulus | openssl md5
# (b) public-key byte compare (works for any key type, not just RSA)
diff <(openssl pkey -in kafka-sslkey.pem -pubout) \
     <(openssl x509 -in kafka-clientcert-leaf.pem -noout -pubkey) && echo "KEY MATCHES CERT"
```
```text
MD5(stdin)= f890aa67fa5af055b27f9e6071cf6635     # cert
MD5(stdin)= f890aa67fa5af055b27f9e6071cf6635     # key   -> identical => they pair
KEY MATCHES CERT
```

If these differ, the key and cert belong to different identities → TLS handshake fails at connect.

---

## 6. Private key — safe inspection (type/size only, never the material)

```bash
openssl pkey -in kafka-sslkey.pem -noout            && echo "KEY PARSES OK"
openssl pkey -in kafka-sslkey.pem -noout -text | head -1     # => Private-Key: (2048 bit, 2 primes)
head -1 kafka-sslkey.pem                                     # => -----BEGIN PRIVATE KEY-----  (PKCS#8, unencrypted)
```

> Never `cat` the whole key, never paste it. The commands above reveal only metadata.

---

## 7. Verify the whole chain of trust

```bash
openssl verify -CAfile kafka-cacert.pem -untrusted kafka-clientcert.pem kafka-clientcert-leaf.pem
# => kafka-clientcert-leaf.pem: OK
```

---

## 8. Format conversions (if a consumer wants something else)

```bash
# PEM -> DER (binary)               | inspect a DER:  openssl x509 -inform DER -in cert.der -noout -text
openssl x509 -in kafka-cacert.pem -outform DER -out kafka-cacert.der

# Build a Java/Spring PKCS#12 keystore (leaf + key + chain). Use kafkasslkeystorepassword as the export pwd.
openssl pkcs12 -export -in kafka-clientcert.pem -inkey kafka-sslkey.pem \
  -certfile kafka-cacert.pem -name kafka-client -out keystore.p12

# Truststore (CA only) for Java
keytool -importcert -alias kafka-ca -file kafka-cacert.pem -keystore truststore.p12 -storetype PKCS12 -noprompt

# Inspect a PKCS#12 you were given (lists what's inside; -info, no private bytes printed):
openssl pkcs12 -in keystore.p12 -info -noout
```

---

## 9. Optional — test against the live broker (needs network + the broker port)

```bash
# Does the broker present a cert your CA trusts, and will it accept this client identity?
openssl s_client -connect esp-eet-vpp-dt.streaming.eneco.com:9093 \
  -CAfile kafka-cacert.pem \
  -cert kafka-clientcert.pem -key kafka-sslkey.pem -servername esp-eet-vpp-dt.streaming.eneco.com </dev/null
# Look for: "Verify return code: 0 (ok)" and a server cert chain that validates.
```
(Port/SNI depend on the broker config; this is a connectivity check, not part of the format fix.)

---

## 10. Alternatives to openssl

```bash
# step-cli (smallstep) — friendlier output
step certificate inspect kafka-clientcert-leaf.pem
step certificate verify kafka-clientcert-leaf.pem --roots kafka-cacert.pem

# Python (cryptography) — scriptable
python3 - <<'PY'
from cryptography import x509
from cryptography.hazmat.primitives import hashes
c = x509.load_pem_x509_certificate(open("kafka-clientcert-leaf.pem","rb").read())
print("subject:", c.subject.rfc4514_string())
print("not_after:", c.not_valid_after_utc)
print("sha256:", c.fingerprint(hashes.SHA256()).hex())
PY

# Java keytool — view a PEM cert
keytool -printcert -file kafka-clientcert-leaf.pem
```

---

## 11. The one that actually fixes "bad format" — re-pull correctly from Key Vault

```bash
az account set --subscription 7b1ba02e-bac6-4c45-83a0-7f0d3104922e   # Sandbox / Dev-Test
az keyvault secret show --vault-name vpp-agg-sb --name kafka-cacert --query value -o tsv   # real newlines
# NEVER:  ... --query value -o json   (adds a JSON envelope + literal \n -> "not in good format")
# Equally safe alternative that avoids shell redirection entirely:
az keyvault secret download --vault-name vpp-agg-sb --name kafka-cacert --file kafka-cacert.pem
```
