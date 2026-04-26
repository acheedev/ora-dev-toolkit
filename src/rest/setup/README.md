
# otk$rest — Environment Setup

Two things must be in place before `otk$rest` can make HTTPS calls:
1. A **Network ACL** granting your schema permission to connect to the target host
2. An **Oracle Wallet** containing the CA certificate that signed the target server's TLS certificate

Both are one-time per-environment tasks. Once done, your PL/SQL code never touches
either of them again — everything goes through `otk$rest.configure()`.

---

## Step 1 — Network ACL (DBA required)

The ACL controls which database schemas can make outbound network calls and to which hosts.

```sql
-- Run as DBA from SQL*Plus or SQLcl
@src/rest/setup/setup_acl.sql MY_APP_SCHEMA api.ansible-tower.company.com 443
```

**What it does:** Grants `connect` and `resolve` privileges to `MY_APP_SCHEMA`
for port 443 on the target host.

**One ACL per host.** If you need to reach multiple hosts, run the script once
per host. It is safe to re-run — `APPEND_HOST_ACE` adds privileges without
replacing existing ones.

**Verify with:**
```sql
SELECT host, lower_port, upper_port, principal
FROM   dba_host_aces
WHERE  principal = 'MY_APP_SCHEMA';
```

---

## Step 2 — Oracle Wallet (oracle OS user)

The wallet is Oracle's TLS trust store. It needs to contain the CA certificate
that signed the server certificate of every HTTPS host you call.

```bash
# Edit configuration at the top of the script first
vi src/rest/setup/setup_wallet.sh

chmod +x src/rest/setup/setup_wallet.sh
./src/rest/setup/setup_wallet.sh
```

**Getting the CA certificate:**

```bash
# Option A — Pull directly from the server (most reliable)
openssl s_client -connect api.ansible-tower.company.com:443 \
    -showcerts </dev/null 2>/dev/null \
    | openssl x509 -outform PEM > /tmp/ca.crt

# Option B — Use the system CA bundle (covers most public/enterprise CAs)
# RHEL/CentOS:
cp /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem /tmp/ca.crt
# Ubuntu/Debian:
cp /etc/ssl/certs/ca-certificates.crt /tmp/ca.crt
```

**Auto-login vs password wallet:**

The script creates an auto-login wallet (`cwallet.sso`). Auto-login wallets
open without a password at runtime, which is the right default for a service
account running from a scheduled job or background process.

If your security policy requires a password-protected wallet, pass
`p_wallet_password` to `otk$rest.configure()`.

---

## Step 3 — Configure and verify from PL/SQL

```plsql
-- Configure the session (call once, e.g. in a package initialiser)
otk$rest.configure(
    p_wallet_path => 'file:/opt/oracle/wallets/rest'
);

-- Run the connectivity check
DECLARE
    l_ok     BOOLEAN;
    l_report CLOB;
BEGIN
    otk$rest.check_connectivity(
        p_url     => 'https://api.ansible-tower.company.com',
        p_success => l_ok,
        p_report  => l_report
    );
    DBMS_OUTPUT.PUT_LINE(otk$clob.to_vc2(l_report));
END;
/
```

Expected output when everything is configured correctly:

```
otk$rest connectivity check
URL : https://api.ansible-tower.company.com
------------------------------------------------------------
OK    Wallet path : file:/opt/oracle/wallets/rest
OK    Target host : api.ansible-tower.company.com
      Attempting connection...
OK    HTTP 200 OK
------------------------------------------------------------
RESULT: OK
```

---

## Troubleshooting

| Error | Meaning | Fix |
|-------|---------|-----|
| `ORA-24247` | No ACL for this host | Run `setup_acl.sql` as DBA |
| `ORA-28759` | Wallet file not found | Check `p_wallet_path` in `configure()` |
| `ORA-28860` | Server cert not trusted | Import the correct CA cert into the wallet |
| `ORA-29024` | SSL handshake failed | CA cert may be wrong version or cert is expired |
| `ORA-12541` | No listener | Wrong host or port — check URL |

`check_connectivity()` identifies and reports on all of these automatically.

---

## Adding a second host

```bash
# Import the CA cert for the new host
openssl s_client -connect new-host.company.com:443 \
    -showcerts </dev/null 2>/dev/null \
    | openssl x509 -outform PEM > /tmp/new-ca.crt

orapki wallet add \
    -wallet /opt/oracle/wallets/rest \
    -trusted_cert \
    -cert /tmp/new-ca.crt \
    -pwd WalletPasswd123
```

```sql
-- Grant ACL for the new host (DBA)
@src/rest/setup/setup_acl.sql MY_APP_SCHEMA new-host.company.com 443
```
