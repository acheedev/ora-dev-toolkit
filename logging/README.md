

# Logging Subsystem (`otk$log` and `otk$log_json`)

The `logging` module provides a full‑featured, production‑grade logging framework
for the `ora_dev_toolkit`. It includes two parallel implementations:

- **`otk$log`** — Classic logger using CLOB storage (compatible with Oracle 11g → 23c)
- **`otk$log_json`** — JSON‑native logger using the new `JSON` data type (Oracle 23ai+)

Both modules expose the same ergonomic API:

```
otk$log.error()
otk$log.warn()
otk$log.info()
otk$log.debug()
```

and the JSON‑native version mirrors this exactly:

```
otk$log_json.error()
otk$log_json.warn()
otk$log_json.info()
otk$log_json.debug()
```

This gives the toolkit a consistent developer experience across all supported
Oracle versions.

---

## Features

### ✔ Logging Levels
- `ERROR` — captures SQLERRM, stack, backtrace
- `WARN` — non‑fatal issues
- `INFO` — operational events
- `DEBUG` — verbose diagnostics

### ✔ Autonomous Transactions
All log writes survive caller rollbacks.

### ✔ Context Logging (JSON object)
Attach metadata to the next log entry:

```plsql
otk$log.context('module', 'user_sync');
otk$log.context('action', 'create');
```

### ✔ JSON Payload Logging
Attach structured JSON to the next log entry:

```plsql
otk$log.json(l_payload_json);
```

Useful for:
- API request/response bodies
- Dynamic SQL metadata
- Automation payloads
- Ansible Tower / REST integrations

### ✔ Global Log Level Filtering
```plsql
otk$log.set_level('WARN');
```

### ✔ Utilities
- `purge(days)`
- `get_recent(limit)`
- `search(keyword)`

---

## Storage Engines

### 1. Classic Logger (CLOB-based)
Table: `otk_error_log`

Columns include:
- `context_data` (CLOB)
- `json_payload` (CLOB)
- `error_stack`, `error_backtrace` (CLOB)

This version is portable across all Oracle editions.

---

### 2. JSON‑Native Logger (Oracle 23ai+)
Table: `otk_error_log_json`

Uses the new `JSON` data type for:
- `context_data`
- `json_payload`

Benefits:
- Binary‑optimized storage
- Faster parsing
- Native JSON operators
- Automatic validation

This is the preferred engine when running on 23ai+.

---

## File Layout

```
logging/
    otk_error_log.sql
    otk_error_log_biu.sql
    otk$log.pks
    otk$log.pkb

    json_native/
        otk_error_log_json.sql
        otk_error_log_json_biu.sql
        otk$log_json.pks
        otk$log_json.pkb

    README.md
    test_log.sql
    test_log_json.sql
```

---

## Example Usage

### Error Logging

```plsql
BEGIN
    SELECT 1 / 0 INTO v FROM dual;
EXCEPTION
    WHEN OTHERS THEN
        otk$log.error('Division failed');
        RAISE;
END;
/
```

### Info + JSON Payload

```plsql
otk$log.context('module', 'api_sync');
otk$log.json(l_request_json);
otk$log.info('Submitting API request');
```

### Debug Logging

```plsql
otk$log.set_level('DEBUG');
otk$log.debug('SQL: ' || l_sql);
```

---

## Choosing Which Logger to Use

| Oracle Version | Recommended Logger |
|----------------|--------------------|
| 11g → 23c      | `otk$log` (CLOB)   |
| 23ai+          | `otk$log_json` (native JSON) |

Both modules can coexist in the same database.

---

## Future Enhancements

- Correlation IDs
- Session‑level context stacks
- Structured event types
- Integration with dynamic SQL builder
- Performance timers (`otk$log.profile()`)

---
