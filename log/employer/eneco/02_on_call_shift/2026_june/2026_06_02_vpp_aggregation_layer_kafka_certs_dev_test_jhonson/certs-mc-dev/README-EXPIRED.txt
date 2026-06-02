MC DEV runtime Kafka certs (vault vpp-agg-appsec-d, sub MCC-Dev-VPP 839af51e).
SOURCE SECRETS: kafka-dev-caCertificate / kafka-dev-clientCertificate (base64(PEM)),
                kafka-dev-sslKeyPfx (base64(PKCS#12), password in secret kafka-dev-sslKeyPassword).
*** THE CLIENT LEAF IS EXPIRED: notAfter = 2026-01-10 (CN esp-eet-vpp-dt). DO NOT USE. ***
The VALID replacement (same CN, notAfter 2027-01-09, rotated 2026-05-29) is in the SANDBOX vault
vpp-agg-sb -> see ../certs/. The rotation was applied to sandbox but NOT propagated to this MC Dev
runtime vault. Older secrets kafka-cacert/clientcert/sslkey (2023) here are ALSO mangled (spaces
for newlines) and expired. Keystore uses legacy RC2-40-CBC: open with `openssl pkcs12 -legacy`.
