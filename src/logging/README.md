
# Logging Subsystem (`otk$log` and `otk$log_json`)

The `logging` module provides a fully **stateless**, production‑grade logging
framework for the `ora_dev_toolkit`. It includes two parallel engines:

- **`otk$log`** — Classic CLOB‑based logger (Oracle 11g → 23c)
- **`otk$log_json`** — JSON‑native logger using the new `JSON` data type (Oracle 23ai+)

Both engines expose the same API and behave identically. The only difference is
the underlying storage type.

This module is designed to be safe for **connection pools**, **APEX**, **ORDS**,
**JDBC**, **Python**, and any environment where session state must not leak.

---

## Stateless Design

Unlike many PL/SQL logging utilities, this module **does not use global
variables**. All logging calls are self‑contained and explicit.

This avoids:

- Session bleed in connection pools
- Cross‑request contamination
- Hidden state
- Debug level leakage
- Context/payload persistence

Every log entry is fully defined by the parameters passed into the logging call.

---

## Features

### ✔ Logging Levels
- `ERROR` — captures SQLERRM, stack, backtrace
- `WARN` — recoverable issues
- `INFO` — operational events
- `DEBUG` — verbose diagnostics

### ✔ Stateless Context Logging
Attach metadata to a log entry:

```plsql
otk$log.info(
    message => 'User created',
    context => otk$log.ctx('module','user_sync')
);
```

Or merge multiple context entries:

```plsql
otk$log.info(
    message => 'User created',
    context => otk$log.ctx_merge(
        otk$log.ctx('module','user_sync'),
        otk$log.ctx('user','alice')
    )
);
```

### ✔ JSON Payload Logging
Attach structured JSON to a log entry:

```plsql
otk$log.info(
    message => 'Submitting API request',
    payload => l_request_json
);
```

### ✔ Autonomous Transactions
All log writes survive caller rollbacks.

### ✔ Utilities
- `purge(days)`
- `get_recent(limit)`
- `search(keyword)`

---

## Storage Engines

### 1. Classic Logger (CLOB-based)
Table: `otk_error_log`

Columns:
- `context_data` (CLOB)
- `json_payload` (CLOB)
- `error_stack`, `error_backtrace` (CLOB)

Compatible with all Oracle versions.

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

Preferred when running on 23ai+.

---

## File Layout

```
src/logging/
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

tests/
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
        otk$log.error(
            message => 'Division failed',
            context => otk$log.ctx('module','calc'),
            payload => JSON_OBJECT('input' VALUE '1/0')
        );
        RAISE;
END;
/
```

### Info + JSON Payload

```plsql
otk$log.info(
    message => 'Submitting API request',
    payload => l_request_json
);
```

### Debug Logging

```plsql
otk$log.debug(
    message => 'SQL about to execute',
    payload => JSON_OBJECT('sql' VALUE l_sql)
);
```

### Search & Recent

```plsql
l_rc := otk$log.get_recent(10);
l_rc := otk$log.search('timeout');
```

### Purge

```plsql
otk$log.purge(30); -- delete logs older than 30 days
```

---

## Choosing Which Logger to Use

| Oracle Version | Recommended Logger |
|----------------|--------------------|
| 11g → 23c      | `otk$log` (CLOB)   |
| 23ai+          | `otk$log_json`     |

Both can coexist in the same database.

---

## Future Enhancements

- Correlation IDs
- Session‑level context stacks
- Structured event types
- Performance timers (`otk$log.profile()`)
- Integration with dynamic SQL builder

---
