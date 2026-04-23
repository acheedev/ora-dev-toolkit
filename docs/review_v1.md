
# ora_dev_toolkit — v1 Peer Review Notes

This document summarizes a peer review of the v1 codebase conducted after the initial build.
The foundation is solid — the architecture, naming conventions, stateless logging design,
and fluent SQL builder are all well-considered choices. The changes below are corrections
and improvements, not redesigns.

---

## Compile Blockers (were preventing the code from running)

### 1. `dbms_assert/` — Package name missing `otk$` prefix + files swapped

**What was wrong:**
Both files declared the package as `assert_utils` instead of `otk$assert_utils`, breaking
the toolkit's own naming convention. Additionally, the `.pks` file contained a package
*body* and the `.pkb` file contained the *spec* — the extensions were reversed.

This meant the `dynamic_sql` type body, which calls `otk$assert_utils.simple_name()` and
`otk$assert_utils.object_name()`, would fail to compile because that package name didn't exist.

**Fix:** Rewrote both files with correct content, correct extensions, and the `otk$` prefix.

---

### 2. `dynamic_sql/otk$ds_query_t_b.sql` — `LISTAGG() OVER()` is not valid in PL/SQL

**What was wrong:**
The `build()` procedure used the analytic form of `LISTAGG` to join the `select_list`
and `where_clauses` collections:

```plsql
l_sql := l_sql || LISTAGG(SELF.select_list(i), ', ')
    WITHIN GROUP (ORDER BY i) OVER ();
```

Analytic functions can only be used inside SQL statements — not directly in PL/SQL
procedural code. This would raise a compilation error.

**Fix:** Replaced both usages with straightforward `FOR` loops:

```plsql
FOR i IN 1 .. SELF.select_list.COUNT LOOP
    IF i > 1 THEN l_sql := l_sql || ', '; END IF;
    l_sql := l_sql || SELF.select_list(i);
END LOOP;
```

---

## Code Quality Improvements

### 3. `logging/otk$log.pkb` — `ctx()` used string concatenation for JSON

**What was wrong:**
```plsql
RETURN '{"' || p_key || '":"' || p_value || '"}';
```
If `p_value` contains a double-quote or backslash, the resulting JSON is silently malformed.

**Fix:** Use `JSON_OBJECT()` with `RETURNING CLOB`, which handles escaping correctly:
```plsql
RETURN JSON_OBJECT(p_key VALUE p_value RETURNING CLOB);
```
The JSON-native logger (`otk$log_json`) already used `JSON_OBJECT()` — this brings
the CLOB logger in line.

---

### 4. `logging/otk$log.pkb` — `ctx_merge()` edge case on empty JSON object `{}`

**What was wrong:**
The merge function spliced JSON strings by stripping the outer braces. This works for
normal single-key objects but breaks when passed an empty object `{}` — `LENGTH('{}') - 1`
strips only the `{`, producing invalid JSON like `{,"key":"value"}`.

**Fix:** Added a length guard before splicing:
```plsql
IF p_ctx1 IS NULL OR DBMS_LOB.GETLENGTH(p_ctx1) <= 2 THEN RETURN p_ctx2; END IF;
IF p_ctx2 IS NULL OR DBMS_LOB.GETLENGTH(p_ctx2) <= 2 THEN RETURN p_ctx1; END IF;
```

---

### 5. `purge()` in both loggers — implicit interval arithmetic

**What was wrong:**
```plsql
WHERE log_timestamp < SYSTIMESTAMP - p_days
```
Subtracting a `NUMBER` from a `TIMESTAMP` relies on Oracle's implicit conversion to a
day interval. It works, but the intent isn't obvious and the behaviour can surprise readers.

**Fix:**
```plsql
WHERE log_timestamp < SYSTIMESTAMP - NUMTODSINTERVAL(p_days, 'DAY')
```

---

### 6. Both table DDLs — missing `CHECK` constraint and index on `log_timestamp`

**What was wrong:**
Nothing prevented code outside the package from inserting an arbitrary `log_level` value
directly into the table. And `purge()`, which filters on `log_timestamp`, would do a full
table scan on what is potentially a high-volume table.

**Fix:**
- Added `CHECK (log_level IN ('ERROR','WARN','INFO','DEBUG'))` inline on both tables
- Added `CREATE INDEX ... ON (log_timestamp)` after both table DDLs

---

## Test Improvements

### 7. No tests for injection resistance

The most important thing to verify about `dbms_assert` is that it actually *blocks*
injection. There were no tests for this.

**Fix:** Created `tests/assert_utils_t1.sql` with 12 tests covering:
- Valid identifiers accepted
- Semicolon injection rejected
- Quote injection rejected
- Comment injection rejected
- Schema-qualified object injection rejected
- NULL inputs rejected
- `literal()` and `enquote()` behaviour

---

### 8. `dynamic_sql_builder_t1.sql` was a demo, not a test

The only test was a copy of the README example — happy path only, no assertions, no
edge cases.

**Fix:** Rewrote with 7 test groups including:
- SELECT * fallback when no columns given
- Multiple WHERE clauses joined correctly with AND
- Minimal query (no ORDER BY / FETCH)
- Injection in column name rejected (T5)
- Injection in table name rejected (T6)
- Injection in ORDER BY rejected (T7)

T5–T7 verify that `otk$assert_utils` is doing its job end-to-end through the builder.

---

### 9. Logging tests — no assertions, wrong location

`test_log.sql` and `test_log_json.sql` were in `logging/` rather than `tests/`, and
relied on visual inspection of `DBMS_OUTPUT` rather than actual pass/fail checks.

**Fix:** Rewrote both and moved them to `tests/`. Each test now queries the table
after each log call to assert the row was actually written, and verifies `created_by`
was populated by the trigger. All tests use a consistent `ok(label, condition)` pattern
and print a final `N passed, N failed` summary.

---

## Documentation Fixes

### 10. Root `README.md` — stale module listing

The Modules section only listed `dbms_assert/` and described `dynamic_sql` and `logging`
as future additions — both of which already existed.

**Fix:** Updated to document all three modules, added an Installation section with the
correct `@script` deploy order and required Oracle privileges, and added a Tests section.

---

### 11. `dynamic_sql/README.md` — wrong filenames in file listing

The Files section referenced `otk$ds_query_t.sql` and `otk$ds_query_t_body.sql`.
The actual files are `otk$ds_query_t_s.sql` and `otk$ds_query_t_b.sql`.

**Fix:** Corrected both filenames.

---

## What Was Not Changed

The following were left as-is — they are good decisions worth preserving:

- **Stateless logging design** — no global variables, safe for connection pools and APEX
- **Dual CLOB/JSON-native engine strategy** — correct forward-compatibility approach
- **`AUTONOMOUS_TRANSACTION` on all log writes** — log survives caller rollbacks
- **Fluent builder pattern on `otk$ds_query_t`** — clean and composable
- **`otk$assert_utils` as the injection boundary** — centralised, correct place for it
- **Naming conventions** — well-defined and consistently applied
- **Per-module READMEs** — good structure, especially `logging/README.md`
