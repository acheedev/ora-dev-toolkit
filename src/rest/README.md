
# rest Module (`otk$rest`)

The `rest` module is a clean `UTL_HTTP` wrapper for making HTTPS REST calls from Oracle
PL/SQL. It handles SSL wallet setup, request body chunking, response assembly, Basic
and Bearer authentication, and custom headers — so call-site code stays focused on
business logic.

**Requires Oracle 19c or later.**
**Depends on: `otk$clob`** (request body chunking, response body assembly)

**Oracle 23ai compatibility note:** `UTL_HTTP.RESP` does not expose a `content_type`
component in 23ai. `otk$rest` reads the `Content-Type` response header instead,
so this package compiles and behaves consistently across supported versions.

---

## First-time Setup

HTTPS from Oracle requires two one-time environment tasks. See
**[setup/README.md](./setup/README.md)** for step-by-step instructions:

1. **Network ACL** — DBA grants your schema permission to connect to the target host
2. **Oracle Wallet** — OS-level task; imports the CA cert that signed the server's TLS certificate

After setup, call `configure()` once in your session and you're done.

---

## Quick Start

```plsql
-- 1. Configure once (wallet path printed by setup_wallet.sh)
otk$rest.configure(
    p_wallet_path => 'file:/opt/oracle/wallets/rest'
);

-- 2. Verify connectivity
DECLARE
    l_ok     BOOLEAN;
    l_report CLOB;
BEGIN
    otk$rest.check_connectivity(
        p_url     => 'https://api.example.com',
        p_success => l_ok,
        p_report  => l_report
    );
    DBMS_OUTPUT.PUT_LINE(otk$clob.to_vc2(l_report));
END;
/

-- 3. Make calls
DECLARE
    l_resp otk$rest.t_response;
BEGIN
    l_resp := otk$rest.get('https://api.example.com/v1/orders');

    IF otk$rest.is_success(l_resp) THEN
        DBMS_OUTPUT.PUT_LINE(otk$clob.to_vc2(l_resp.body));
    ELSE
        DBMS_OUTPUT.PUT_LINE('Error: ' || l_resp.status_code || ' ' || l_resp.status_text);
    END IF;
END;
/
```

---

## API Reference

### configure

```plsql
PROCEDURE configure(
    p_wallet_path     IN VARCHAR2,
    p_wallet_password IN VARCHAR2 DEFAULT NULL,
    p_connect_timeout IN NUMBER   DEFAULT 30,
    p_read_timeout    IN NUMBER   DEFAULT 60
);
```

Sets session-level globals used by all subsequent requests. Call once.
`p_wallet_password` can be omitted for auto-login wallets (`cwallet.sso`).

---

### HTTP Verbs

All return a `t_response` record.

```plsql
TYPE t_response IS RECORD (
    status_code  PLS_INTEGER,   -- e.g. 200, 404, 500
    status_text  VARCHAR2(256), -- e.g. 'OK', 'Not Found'
    content_type VARCHAR2(256), -- e.g. 'application/json'
    body         CLOB           -- full response body
);
```

```plsql
FUNCTION get  (p_url, p_headers, p_bearer, p_basic_user, p_basic_pass) RETURN t_response;
FUNCTION post (p_url, p_body, p_content_type, p_headers, p_bearer, p_basic_user, p_basic_pass) RETURN t_response;
FUNCTION put  (p_url, p_body, p_content_type, p_headers, p_bearer, p_basic_user, p_basic_pass) RETURN t_response;
FUNCTION patch(p_url, p_body, p_content_type, p_headers, p_bearer, p_basic_user, p_basic_pass) RETURN t_response;
FUNCTION del  (p_url, p_headers, p_bearer, p_basic_user, p_basic_pass) RETURN t_response;
```

`p_content_type` defaults to `'application/json'` for POST/PUT/PATCH.
`p_headers` is a JSON object of additional headers: `'{"X-Tenant":"abc"}'`.
Bearer takes precedence over Basic when both are supplied.

**Note:** `DELETE` is a PL/SQL reserved word — the function is named `del`.

---

### Response Helpers

```plsql
FUNCTION is_success(p_response IN t_response) RETURN BOOLEAN;  -- 2xx
FUNCTION is_error  (p_response IN t_response) RETURN BOOLEAN;  -- 4xx/5xx
```

---

### check_connectivity

```plsql
PROCEDURE check_connectivity(
    p_url     IN  VARCHAR2,
    p_success OUT BOOLEAN,
    p_report  OUT CLOB
);
```

Attempts a GET to `p_url` and diagnoses each failure layer in order:
wallet → ACL → SSL handshake → HTTP response. The `p_report` CLOB
is human-readable and suitable for logging with `otk$log`.

---

## Common Patterns

### Bearer token (most REST APIs)

```plsql
l_resp := otk$rest.get(
    p_url    => 'https://api.example.com/v1/jobs',
    p_bearer => l_api_token
);
```

### POST with JSON body

```plsql
l_body := JSON_OBJECT(
    'template' VALUE 42,
    'extra_vars' VALUE JSON_OBJECT('env' VALUE 'prod')
    RETURNING CLOB
);

l_resp := otk$rest.post(
    p_url    => 'https://ansible.company.com/api/v2/job_templates/42/launch/',
    p_body   => l_body,
    p_bearer => l_token
);

IF otk$rest.is_success(l_resp) THEN
    l_job_id := otk$json.get_num(l_resp.body, '$.job');
END IF;
```

### Custom headers

```plsql
l_resp := otk$rest.get(
    p_url     => 'https://api.example.com/v1/data',
    p_headers => JSON_OBJECT(
        'X-Correlation-Id' VALUE l_trace_id,
        'Accept'           VALUE 'application/json'
        RETURNING CLOB
    ),
    p_bearer  => l_token
);
```

### Error handling with logging

```plsql
l_resp := otk$rest.post(p_url => l_url, p_body => l_payload, p_bearer => l_token);

IF NOT otk$rest.is_success(l_resp) THEN
    otk$log.error(
        message => 'REST call failed',
        context => otk$log.ctx_merge(
            otk$log.ctx('url',    l_url),
            otk$log.ctx('status', TO_CHAR(l_resp.status_code))
        ),
        payload => l_resp.body
    );
    RETURN;
END IF;
```

---

## Files

```
src/rest/
    otk$rest.pks    -- package spec
    otk$rest.pkb    -- package body
    README.md       -- this file

    setup/
        README.md           -- step-by-step setup guide
        setup_acl.sql       -- DBA: grant network ACL
        setup_wallet.sh     -- create wallet, import CA cert

tests/
    rest_t1.sql     -- unit tests + commented integration tests
```

---

## Installation

Requires `otk$clob` to be installed first.

```sql
@src/clob/otk$clob.pks
@src/clob/otk$clob.pkb

@src/rest/otk$rest.pks
@src/rest/otk$rest.pkb
```

Then follow `src/rest/setup/README.md` to configure the environment.
