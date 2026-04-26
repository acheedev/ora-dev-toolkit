
# ansible Module (`otk$ansible`)

The `ansible` module is an Ansible Tower / AWX REST API client built on `otk$rest`.
It covers the complete job lifecycle: launch → poll → inspect → output → cancel.

**Requires Oracle 19c or later.**
**Depends on: `otk$rest`, `otk$json`**
**Targets: Ansible Tower / AWX REST API v2**

---

## Quick Start

```plsql
-- 1. Configure rest module (once per session)
otk$rest.configure(
    p_wallet_path => 'file:/opt/oracle/wallets/rest'
);

-- 2. Configure ansible module (once per session)
--    Set job timeout/poll defaults here — no need to repeat them per call
otk$ansible.configure(
    p_base_url        => 'https://ansible-tower.company.com',
    p_bearer          => 'your_oauth2_token',
    p_job_timeout_sec => 300,   -- raise ORA-20002 after 5 minutes
    p_job_poll_sec    => 10     -- check status every 10 seconds
);

-- 3. Launch and wait
DECLARE
    l_job_id NUMBER;
    l_status VARCHAR2(20);
BEGIN
    l_job_id := otk$ansible.launch_job(
        p_template_id => 42,
        p_extra_vars  => '{"env":"prod","version":"2.1.0"}'
    );

    l_status := otk$ansible.wait_for_job(l_job_id);

    IF l_status = otk$ansible.c_status_successful THEN
        DBMS_OUTPUT.PUT_LINE('Job completed successfully');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Job ended with status: ' || l_status);
    END IF;
END;
/
```

---

## API Reference

### configure

```plsql
PROCEDURE configure(
    p_base_url        IN VARCHAR2,           -- e.g. 'https://ansible-tower.company.com'
    p_bearer          IN VARCHAR2 DEFAULT NULL,
    p_basic_user      IN VARCHAR2 DEFAULT NULL,
    p_basic_pass      IN VARCHAR2 DEFAULT NULL,
    p_job_timeout_sec IN NUMBER   DEFAULT 300,
    p_job_poll_sec    IN NUMBER   DEFAULT 10
);
```

Sets session-level state used by all subsequent calls. `p_job_timeout_sec` and
`p_job_poll_sec` are the defaults for `wait_for_job` — override them per-call
by passing explicit values to `wait_for_job`.

Bearer token is preferred. Generate one in Tower under
**User Settings → Tokens → Add**.

---

### ping

```plsql
FUNCTION ping RETURN BOOLEAN;
```

Calls `/api/v2/ping/`. Returns `FALSE` rather than raising on network or auth errors.
Use to verify connectivity and credentials before launching jobs.

---

### launch_job

```plsql
FUNCTION launch_job(
    p_template_id IN NUMBER,
    p_extra_vars  IN CLOB     DEFAULT NULL,
    p_limit       IN VARCHAR2 DEFAULT NULL,
    p_inventory   IN NUMBER   DEFAULT NULL
) RETURN NUMBER;
```

Launches the job template and returns the new job ID.
Raises `ORA-20003` if the API call fails or Tower rejects the launch.

`p_extra_vars` must be a valid JSON object: `'{"key":"value"}'`.
`p_limit` is the Ansible `--limit` host pattern.
`p_inventory` overrides the template's default inventory.

---

### Job Inspection

```plsql
FUNCTION job_status (p_job_id IN NUMBER) RETURN VARCHAR2;
FUNCTION job_complete(p_job_id IN NUMBER) RETURN BOOLEAN;
FUNCTION job_succeeded(p_job_id IN NUMBER) RETURN BOOLEAN;
FUNCTION get_job(p_job_id IN NUMBER) RETURN CLOB;
FUNCTION get_job_output(p_job_id IN NUMBER) RETURN CLOB;
```

`job_status` returns the raw Tower status string. Compare against the
package constants to avoid magic strings:

```plsql
IF otk$ansible.job_status(l_job_id) = otk$ansible.c_status_failed THEN ...
```

`job_complete` returns `TRUE` for any terminal state: `successful`, `failed`,
`error`, `canceled`. Use it when you don't care how the job ended, only that it has.

`get_job` returns the full Tower JSON response — useful for extracting fields
not exposed by the other functions using `otk$json`.

`get_job_output` returns the raw playbook stdout text.

---

### wait_for_job

```plsql
FUNCTION wait_for_job(
    p_job_id      IN NUMBER,
    p_timeout_sec IN NUMBER DEFAULT NULL,   -- NULL = use configure() value
    p_poll_sec    IN NUMBER DEFAULT NULL    -- NULL = use configure() value
) RETURN VARCHAR2;
```

Polls until the job reaches a terminal state. Returns the final status string.
Raises `ORA-20002` if `p_timeout_sec` seconds elapse without completion.

**This is a blocking call.** The database session is held for the duration
of polling. Size `p_job_timeout_sec` in `configure()` to your longest expected
playbook runtime. For very long-running jobs (hours), consider a
`DBMS_SCHEDULER` approach instead.

Override defaults for a specific call:
```plsql
-- This job usually runs in 30 seconds — use a tighter timeout
l_status := otk$ansible.wait_for_job(l_job_id, p_timeout_sec => 60);
```

---

### cancel_job

```plsql
PROCEDURE cancel_job(p_job_id IN NUMBER);
```

Sends a cancel request. Silently no-ops if the job is already in a terminal state.
Raises `ORA-20003` on unexpected API errors.

---

## Status Constants

```plsql
otk$ansible.c_status_new        -- 'new'
otk$ansible.c_status_pending    -- 'pending'
otk$ansible.c_status_waiting    -- 'waiting'
otk$ansible.c_status_running    -- 'running'
otk$ansible.c_status_successful -- 'successful'
otk$ansible.c_status_failed     -- 'failed'
otk$ansible.c_status_error      -- 'error'
otk$ansible.c_status_canceled   -- 'canceled'
```

---

## Common Patterns

### Full lifecycle with logging

```plsql
DECLARE
    l_job_id NUMBER;
    l_status VARCHAR2(20);
    l_ctx    CLOB;
BEGIN
    l_job_id := otk$ansible.launch_job(
        p_template_id => 42,
        p_extra_vars  => JSON_OBJECT('env' VALUE 'prod' RETURNING CLOB)
    );

    l_ctx := otk$log.ctx_merge(
        otk$log.ctx('template_id', '42'),
        otk$log.ctx('job_id',      TO_CHAR(l_job_id))
    );

    otk$log.info(message => 'Ansible job launched', context => l_ctx);

    l_status := otk$ansible.wait_for_job(l_job_id);

    IF l_status = otk$ansible.c_status_successful THEN
        otk$log.info(message => 'Ansible job succeeded', context => l_ctx);
    ELSE
        otk$log.error(
            message => 'Ansible job did not succeed',
            context => otk$log.ctx_merge(l_ctx, otk$log.ctx('status', l_status)),
            payload => otk$ansible.get_job(l_job_id)
        );
    END IF;
END;
```

### Extract fields from job JSON

```plsql
DECLARE
    l_job      CLOB   := otk$ansible.get_job(l_job_id);
    l_started  DATE   := otk$json.get_date(l_job, '$.started',  p_fmt => 'YYYY-MM-DD"T"HH24:MI:SS');
    l_finished DATE   := otk$json.get_date(l_job, '$.finished', p_fmt => 'YYYY-MM-DD"T"HH24:MI:SS');
    l_elapsed  NUMBER := otk$json.get_num(l_job, '$.elapsed');
BEGIN
    DBMS_OUTPUT.PUT_LINE('Elapsed: ' || l_elapsed || 's');
END;
```

---

## Files

```
src/ansible/
    otk$ansible.pks    -- package spec
    otk$ansible.pkb    -- package body
    README.md          -- this file

tests/
    ansible_t1.sql     -- unit tests + commented integration tests
```

---

## Installation

```sql
@src/clob/otk$clob.pks
@src/clob/otk$clob.pkb

@src/json/otk$json.pks
@src/json/otk$json.pkb

@src/rest/otk$rest.pks
@src/rest/otk$rest.pkb

@src/ansible/otk$ansible.pks
@src/ansible/otk$ansible.pkb
```

Configure the `otk$rest` wallet and ACL first — see `src/rest/setup/README.md`.
