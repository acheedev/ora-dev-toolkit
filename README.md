
# ora_dev_toolkit

The **ora_dev_toolkit** is a modular collection of Oracle PL/SQL utilities designed to make everyday development safer, cleaner, and more productive.
Every module follows a consistent naming convention, uses the `otk$` package prefix, and lives in its own functional namespace.

This toolkit is built to grow over time — each module is self‑contained, documented, and focused on solving a specific problem in Oracle development.

---

## Modules

### **dbms_assert/**
Safe wrappers around Oracle's `DBMS_ASSERT` package for identifier and literal validation. Foundation for all dynamic SQL construction in this toolkit.

➡️ [View the dbms_assert module](./dbms_assert/README.md)

---

### **dynamic_sql/**
A fluent, object‑oriented API for safely constructing dynamic `SELECT` statements. Built on `otk$assert_utils` — all identifiers are validated before the SQL string is assembled.

➡️ [View the dynamic_sql module](./dynamic_sql/README.md)

---

### **logging/**
A fully stateless, production‑grade logging framework with two parallel engines:
- `otk$log` — CLOB‑based, compatible with Oracle 12c and later
- `otk$log_json` — JSON‑native storage, requires Oracle 23ai+

➡️ [View the logging module](./logging/README.md)

---

## Installation

Objects must be installed in dependency order. Run scripts as the target schema owner.

### 1. dbms_assert (no dependencies)

```sql
@dbms_assert/otk$assert_utils.pks
@dbms_assert/otk$assert_utils.pkb
```

### 2. dynamic_sql (depends on dbms_assert)

```sql
@dynamic_sql/otk$ds_query_t_s.sql
@dynamic_sql/otk$ds_query_t_b.sql
@dynamic_sql/otk$dynamic_sql_builder.pks
@dynamic_sql/otk$dynamic_sql_builder.pkb
```

### 3. logging — classic CLOB engine (no dependencies)

```sql
@logging/otk_error_log.sql
@logging/otk_error_log_biu.sql
@logging/otk$log.pks
@logging/otk$log.pkb
```

### 4. logging — JSON‑native engine (Oracle 23ai+ only, no dependencies)

```sql
@logging/json_native/otk_error_log_json.sql
@logging/json_native/otk_error_log_json_biu.sql
@logging/json_native/otk$log_json.pks
@logging/json_native/otk$log_json.pkb
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
@tests/test_log.sql
@tests/test_log_json.sql       -- Oracle 23ai+ only
```

Each script prints `N passed, N failed` on completion.

---

## Goals

- Provide reusable, production‑quality PL/SQL utilities
- Standardize safe dynamic SQL patterns
- Reduce boilerplate and repeated code across projects
- Serve as a personal and team‑wide Oracle development reference
- Encourage modular, discoverable, well‑documented utilities

---

## Contributing

Each module directory contains:

- A `README.md` describing the module
- A package spec (`.pks`) and body (`.pkb`)
- Object type spec (`_s.sql`) and body (`_b.sql`) where applicable

Follow the naming conventions and structure when adding new utilities.
