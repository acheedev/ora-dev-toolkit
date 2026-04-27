
# ora_dev_toolkit

The **ora_dev_toolkit** is a modular collection of Oracle PL/SQL utilities designed to make everyday development safer, cleaner, and more productive.
Every module follows a consistent naming convention, uses the `otk$` package prefix, and lives in its own functional namespace under `src/`.

This toolkit is built to grow over time — each module is self‑contained, documented, and focused on solving a specific problem in Oracle development.

---

## Modules

### **src/ansible/**
Ansible Tower / AWX REST API v2 client. Launch job templates, poll for completion, retrieve output, cancel jobs. Timeout and poll interval defaults set once in `configure()`. Depends on `otk$clob`, `otk$rest`, and `otk$json`. Requires Oracle 19c+.

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

### Quick Install (All Modules)

To install all modules at once in the correct dependency order:

```sql
@src/build.sql
```

### Module Installs

Each module directory has a local `build.sql` that installs only that module.
Install any listed dependencies first.

### dbms_assert (no dependencies)

```sql
@src/dbms_assert/build.sql
```

### ansible (depends on clob, json, rest)

```sql
@src/clob/build.sql
@src/json/build.sql
@src/rest/build.sql
@src/ansible/build.sql
```

### rest (depends on clob)

```sql
@src/clob/build.sql
@src/rest/build.sql
```

See `src/rest/setup/README.md` for ACL and wallet configuration.

### ddl (depends on dbms_assert)

```sql
@src/dbms_assert/build.sql
@src/ddl/build.sql
```

### convert (no dependencies)

```sql
@src/convert/build.sql
```

### clob (no dependencies)

```sql
@src/clob/build.sql
```

### json (no dependencies)

```sql
@src/json/build.sql
```

### dynamic_sql (depends on dbms_assert)

```sql
@src/dbms_assert/build.sql
@src/dynamic_sql/build.sql
```

### logging - classic CLOB engine (no dependencies)

```sql
@src/logging/build.sql
```

### logging - JSON-native engine (Oracle 23ai+ only)

```sql
@src/logging/json_native/build.sql
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
    build.sql       -- Master build script (installs all modules in order)
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
