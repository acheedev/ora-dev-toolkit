
# otk Test Mock Server

A local Python server that simulates both a generic REST API and Ansible Tower API v2.
The test suites for `otk$rest` and `otk$ansible` hit this server — no external
dependencies, no wallet required, deterministic responses.

---

## Prerequisites

- Python 3.8+
- The database server can reach `127.0.0.1:8765` from PL/SQL
  (if Oracle runs on a different host, replace `127.0.0.1` with that host's IP
  and update the URLs in the test files accordingly)

---

## Setup (one-time, per environment)

### 1. Install Python dependencies

```bash
cd tests/mock_server
pip install -r requirements.txt
```

### 2. Grant network ACL (DBA required, once per schema)

```sql
@tests/mock_server/setup_test_acl.sql MY_APP_SCHEMA 8765
```

For the default local test port, you can also use:

```sql
@tests/mock_server/setup_localhost_8765_acl.sql MY_APP_SCHEMA
```

---

## Running the tests

### 3. Start the mock server (leave running in a separate terminal)

```bash
python tests/mock_server/mock_server.py
```

Output confirms it is listening:
```
otk mock server  http://0.0.0.0:8765
────────────────────────────────────────────────────────────
REST endpoints:
  GET  /get             POST /post  ...
```

### 4. Run the test suites from SQL*Plus / SQLcl

```sql
@tests/rest_t1.sql
@tests/ansible_t1.sql
```

---

## How it works

### REST endpoints (httpbin-style)

Each verb endpoint echoes back the method, URL, headers, and body as JSON.
This lets the PL/SQL tests assert on what was actually sent:

```
GET  /get             -> { method, url, headers, args }
POST /post            -> { method, url, headers, data, json }
PUT  /put             -> same as post
PATCH /patch          -> same as post
DELETE /delete        -> { method, url, headers }
GET  /bearer          -> 200 if Authorization: Bearer ... present, else 401
GET  /basic-auth/u/p  -> 200 if correct Basic credentials, else 401
GET  /status/{code}   -> returns that HTTP status code, empty body
GET  /slow/{seconds}  -> sleeps N seconds then 200 (triggers read timeout)
GET  /headers         -> { headers: {...} }
```

### Ansible Tower endpoints

Job state machine — each `GET /api/v2/jobs/{id}/` increments a call counter:

| Template ID | Outcome after 2 polls |
|------------|----------------------|
| `1`        | `successful`          |
| `2`        | `failed`              |
| `3`        | `error`               |
| `999`      | always `running`      |

This means `wait_for_job` on template 1 with `p_poll_sec => 1` will poll
twice and return `'successful'` in about 2 seconds.

Template 999 never completes — use it for cancel tests and timeout tests.

### Admin

`POST /admin/reset` clears all job state. The test files call this at the
start of each run to ensure a clean slate.

---

## Troubleshooting

| Symptom | Likely cause |
|---------|-------------|
| `ORA-24247` | ACL not granted — run `setup_test_acl.sql` |
| `ORA-12541` | Mock server not running, or wrong port |
| `Connection refused` | Same as above |
| Tests hang on `wait_for_job` | `p_poll_sec` too high or template 999 used without cancel |

---

## Stopping the server

`Ctrl+C` in the terminal running `mock_server.py`.
