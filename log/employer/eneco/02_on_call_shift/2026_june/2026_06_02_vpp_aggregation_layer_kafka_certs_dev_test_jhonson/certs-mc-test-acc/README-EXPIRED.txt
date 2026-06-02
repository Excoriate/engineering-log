MC ACC / "test" runtime Kafka certs (vault vpp-agg-appsec-a, sub MCC-Acc-VPP b524d084).
SOURCE SECRETS (2025-01-07): kafka-test-ca-certificate, kafka-test-client-certificate,
  kafka-test-ssl-key-pem (PEM), kafka-test-ssl-key-cert-pfx (base64 PKCS#12);
  keystore password = secret kafkasslkeystorepassword.
*** CLIENT LEAF IS EXPIRED: CN esp-eet-vpp-acc, notAfter 2026-01-10. DO NOT USE. ***
No valid esp-eet-vpp-acc replacement was found in any reachable vault. The only VALID agg cert is
the sandbox esp-eet-vpp-dt (vpp-agg-sb, ->2027-01-09). Older kafka-cacert/clientcert (2023) here are
base64-wrapped legacy. CA cert itself is fine (->2027); only the client leaf expired.
