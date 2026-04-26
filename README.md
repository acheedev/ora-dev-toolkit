
# ora_dev_toolkit

The **ora_dev_toolkit** is a modular collection of Oracle PL/SQL utilities designed to make everyday development safer, cleaner, and more productive.
Every module follows a consistent naming convention, uses the `otk$` package prefix, and lives in its own functional namespace under `src/`.

This toolkit is built to grow over time — each module is self‑contained, documented, and focused on solving a specific problem in Oracle development.

---

## Modules

### **src/ansible/**
Ansible Tower / AWX REST API v2 client. Launch job templates, poll for completion, retrieve output, cancel jobs. Timeout and poll interval defaults set once in `configure()`. Depends on `otk$rest` and `otk$json`. Requires Oracle 19c+.

➡️ [View the ansible module](./src/ansible/README.md)

---

### **src/rest/**
HTTPS REST client wrapping `UTL_HTTP`. Handles SSL wallet, Basic and Bearer auth, JSON headers, request body chunking, and response assembly. Includes `check_connectivity()` for environment diagnostics and a `setup/` directory with ACL and wallet scripts. Requires Oracle 19c+.

➡️ [View the rest module](./src/rest/README.md)

---

### **src/ddl/**
Existence checks for tables, views, columns, constraints and other objects. Conditional drop procedures that silently no-op on missing objects. Two-mode DDL execution: raise-on-failure for install scripts, return-false-on-failure for upgrade logic. Depends on `otk$assert_utils`. Compatible with Oracle 12c+.

➡️ [View the ddl module](./src/ddl/README.md)

---

### **src/convert/**
Safe `TO_NUMBER`/`TO_DATE`/`TO_TIMESTAMP` with defaults instead of exceptions. Boolean↔VARCHAR2 adapters covering `Y/N`, `TRUE/FALSE`, and `1/0` conventions. Typed NVL wrappers for clean chaining. Compatible with Oracle 12c+.

➡️ [View the convert module](./src/convert/README.md)

---

### **src/clob/**
Utilities for safe CLOB conversion, search, modification, chunked reads, and line parsing. Eliminates `DBMS_LOB` boilerplate and silent truncation. Compatible with Oracle 12c+.

➡️ [View the clob module](./src/clob/README.md)

---

### **src/json/**
Clean, consistent wrappers for extracting, building, merging, and validating JSON stored in CLOBs. Eliminates `JSON_VALUE`/`JSON_QUERY` boilerplate and centralises error handling. Requires Oracle 19c+.

➡️ [View the json module](./src/json/README.md)

---

### **src/dbms_assert/**
Safe wrappers around Oracle's `DBMS_ASSERT` package for identifier and literal validation. Foundation for all dynamic SQL construction in this toolkit.

➡️ [View the dbms_assert module](./src/dbms_assert/README.md)

---

### **src/dynamic_sql/**
A fluent, object‑oriented API for safely constructing dynamic `SELECT` statements. Built on `otk$assert_utils` — all identifiers are validated before the SQL string is assembled.

➡️ [View the dynamic_sql module](./src/dynamic_sql/README.md)

---

### **src/logging/**
A fully stateless, production‑grade logging framework with two parallel engines:
- `otk$log` — CLOB‑based, compatible with Oracle 12c and later
- `otk$log_json` — JSON‑native storage, requires Oracle 23ai+

➡️ [View the logging module](./src/logging/README.md)

---

## Installation

Objects must be installed in dependency order. Run scripts as the target schema owner.

### 1. dbms_assert (no dependencies — install first)

```sql
@src/dbms_assert/otk$assert_utils.pks
@src/dbms_assert/otk$assert_utils.pkb
```

### 2. ansible (depends on clob, json, rest)

```sql
@src/ansible/otk$ansible.pks
@src/ansible/otk$ansible.pkb
```

### 3. rest (depends on clob — install clob first)

```sql
@src/rest/otk$rest.pks
@src/rest/otk$rest.pkb
```

See `src/rest/setup/README.md` for ACL and wallet configuration.

### 3. ddl (depends on dbms_assert)

```sql
@src/ddl/otk$ddl.pks
@src/ddl/otk$ddl.pkb
```

### 3. convert (no dependencies)

```sql
@src/convert/otk$convert.pks
@src/convert/otk$convert.pkb
```

### 3. clob (no dependencies)

```sql
@src/clob/otk$clob.pks
@src/clob/otk$clob.pkb
```

### 3. json (no dependencies)

```sql
@src/json/otk$json.pks
@src/json/otk$json.pkb
```

### 4. dynamic_sql (depends on dbms_assert)

```sql
@src/dynamic_sql/otk$ds_query_t_s.sql
@src/dynamic_sql/otk$ds_query_t_b.sql
@src/dynamic_sql/otk$dynamic_sql_builder.pks
@src/dynamic_sql/otk$dynamic_sql_builder.pkb
```

### 5. logging — classic CLOB engine (no dependencies)

```sql
@src/logging/otk_error_log.sql
@src/logging/otk_error_log_biu.sql
@src/logging/otk$log.pks
@src/logging/otk$log.pkb
```

### 6. logging — JSON‑native engine (Oracle 23ai+ only)

```sql
@src/logging/json_native/otk_error_log_json.sql
@src/logging/json_native/otk_error_log_json_biu.sql
@src/logging/json_native/otk$log_json.pks
@src/logging/json_native/otk$log_json.pkb
```

### Required privileges

The installing schema needs:
- `CREATE TABLE`, `CREATE INDEX`, `CREATE TRIGGER` — for logging DDL
- `CREATE PROCEDURE`, `CREATE TYPE` — for packages and object types
- `EXECUTE ON DBMS_ASSERT` — for the assert_utils package
- `EXECUTE ON DBMS_UTILITY` — for error stack capture in the logger

---

## Naming Conventions

All packages use the `otk$` prefix and a consistent directory/file structure.

➡️ [docs/naming_conventions.md](./docs/naming_conventions.md)

---

## Tests

All test scripts live under `tests/`. Run them after installation to verify each module.

```sql
@tests/assert_utils_t1.sql
@tests/dynamic_sql_builder_t1.sql
@tests/ansible_t1.sql
@tests/rest_t1.sql
@tests/ddl_t1.sql
@tests/convert_t1.sql
@tests/clob_t1.sql
@tests/json_t1.sql
@tests/test_log.sql
@tests/test_log_json.sql       -- Oracle 23ai+ only
```

Each script prints `N passed, N failed` on completion.

---

## Repository Structure

```
src/
    ansible/        -- Ansible Tower/AWX API client (19c+)
    rest/           -- HTTPS REST client (19c+)
        setup/          -- ACL and wallet setup scripts
    ddl/            -- Existence checks, conditional drop, safe DDL exec
    convert/        -- Safe type conversions, boolean adapters
    clob/           -- CLOB utilities (12c+)
    json/           -- JSON/CLOB wrappers (19c+)
    dbms_assert/    -- Identifier validation wrappers
    dynamic_sql/    -- Fluent SELECT builder
    logging/        -- Stateless logging framework
        json_native/    -- JSON-native engine (23ai+)
docs/               -- Naming conventions and review notes
tests/              -- All test scripts
```

---

## Goals

- Provide reusable, production‑quality PL/SQL utilities
- Standardize safe dynamic SQL patterns
- Reduce boilerplate and repeated code across projects
- Serve as a personal and team‑wide Oracle development reference
- Encourage modular, discoverable, well‑documented utilities

---

## Contributing

Each module directory under `src/` contains:

- A `README.md` describing the module
- A package spec (`.pks`) and body (`.pkb`)
- Object type spec (`_s.sql`) and body (`_b.sql`) where applicable

Follow the naming conventions and structure when adding new utilities.
