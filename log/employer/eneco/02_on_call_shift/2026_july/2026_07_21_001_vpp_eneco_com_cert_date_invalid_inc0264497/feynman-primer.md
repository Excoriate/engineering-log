# Feynman primer — apex `vpp.eneco.com` TLS date invalid (INC0264497)

Self-declared: **condensed primer** for the next agent / on-call.

## Knowledge contract

After this page you can:

1. Separate **apex** `vpp.eneco.com` from the **wildcard** `*.vpp.eneco.com` object.
2. Explain why Chrome says expired on 2026-07-21 while ServiceNow shows May→Nov 2026.
3. Name the first AVD probe that proves the served leaf.
4. Reject "Continue unsafe" as a fix.

## One ladder

```text
User → TLS SNI vpp.eneco.com → App Gateway apex listener
     → Key Vault object (hyp: p-vpp-eneco-com)
     → leaf notAfter ~ 2026-07-20 → ERR_CERT_DATE_INVALID
```

Wildcard object `wildcard-vpp-eneco-com` (rotated 2026-06-25) does **not** cover apex — June spec said so, with apex exp **Jul 20**.

## Mechanism in words

Browsers validate the **leaf** dates on the wire. If that leaf expired yesterday, you get `NET::ERR_CERT_DATE_INVALID` even if some other cert attached to a ticket is valid until November. Proceeding past the warning does not renew the leaf; it only continues on an untrusted channel (here: `/forbidden` while still Not secure).

## Anti-pattern

Treating the ServiceNow-linked May→30-Nov certificate as proof the site is fine — without comparing **thumbprints** to the openssl leaf.

## Compact ledger

| Claim | Tag |
|-------|-----|
| Browser error is cert date invalid on apex | Known |
| Apex was out of June wildcard rotation; exp Jul 20 | Known (eng-log) |
| Served object is `p-vpp-eneco-com` | Inferred — prove on AVD |
| Continue-unsafe is a workaround | False — Known fail |

## Transfer self-test

- What single openssl command from AVD would kill the Jul-20 hypothesis?
- If `agg.vpp.eneco.com` is fine but apex is not, which KV object do you rotate?
