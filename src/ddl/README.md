
# ddl Module (`otk$ddl`)

The `ddl` module provides existence checks, conditional drops, and safe DDL execution.
It eliminates the boilerplate of checking `ALL_OBJECTS` before every `DROP` and wraps
`EXECUTE IMMEDIATE` with error context that makes failures debuggable.

**Compatible with Oracle 12c and later.**
**Depends on: `otk$assert_utils`** (identifier validation before DDL string assembly)

---

## API Reference

### Generic Existence Check

```plsql
FUNCTION object_exists(p_name  IN VARCHAR2,
                       p_type  IN VARCHAR2,
                       p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
```

Queries `ALL_OBJECTS`. `p_type` matches the `OBJECT_TYPE` column exactly —
`'TABLE'`, `'VIEW'`, `'PACKAGE'`, `'PACKAGE BODY'`, `'TYPE'`, etc.
`p_owner` defaults to the current schema when NULL.

---

### Type-Specific Shortcuts

All delegate to `object_exists` with the appropriate type literal.

```plsql
FUNCTION table_exists   (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
FUNCTION view_exists    (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
FUNCTION index_exists   (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
FUNCTION sequence_exists(p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
FUNCTION package_exists (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
FUNCTION type_exists    (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
FUNCTION trigger_exists (p_name IN VARCHAR2, p_owner IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
```

---

### Column and Constraint Checks

```plsql
FUNCTION column_exists(p_table  IN VARCHAR2,
                       p_column IN VARCHAR2,
                       p_owner  IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;

FUNCTION constraint_exists(p_constraint IN VARCHAR2,
                           p_table      IN VARCHAR2 DEFAULT NULL,
                           p_owner      IN VARCHAR2 DEFAULT NULL) RETURN BOOLEAN;
```

`constraint_exists` accepts an optional `p_table` to scope the search.
Omit it to search all constraints in the schema.

---

### Conditional Drop

```plsql
PROCEDURE drop_if_exists(p_name  IN VARCHAR2,
                         p_type  IN VARCHAR2,
                         p_owner IN VARCHAR2 DEFAULT NULL);

PROCEDURE drop_table_if_exists(p_name                IN VARCHAR2,
                               p_cascade_constraints IN BOOLEAN  DEFAULT FALSE,
                               p_owner               IN VARCHAR2 DEFAULT NULL);
```

Both silently no-op if the object does not exist — no exception, no noise.
Object names are validated through `otk$assert_utils` before the DDL string
is assembled, preventing identifier injection.

---

### DDL Execution

```plsql
PROCEDURE exec_ddl(p_ddl IN VARCHAR2);
FUNCTION  try_exec(p_ddl IN VARCHAR2, p_err OUT VARCHAR2) RETURN BOOLEAN;
```

**`exec_ddl`** — use in install and upgrade scripts where failure should stop execution.
On error it raises `ORA-20001` with the Oracle error message **and** the DDL text
appended, so you see exactly what failed:

```
ORA-20001: ORA-00942: table or view does not exist
DDL: ALTER TABLE otk_no_such_table ADD (new_col VARCHAR2(100))
```

**`try_exec`** — use in conditional upgrade logic where you need to branch on success
or failure without an exception handler:

```plsql
IF NOT otk$ddl.try_exec('ALTER TABLE t ADD (col VARCHAR2(100))', l_err) THEN
    otk$log.warn(message => 'Column add failed', context => otk$log.ctx('reason', l_err));
END IF;
```

---

## Common Patterns

### Idempotent upgrade script

```plsql
-- Add a column only if it doesn't exist
IF NOT otk$ddl.column_exists('order_header', 'external_ref') THEN
    otk$ddl.exec_ddl('ALTER TABLE order_header ADD (external_ref VARCHAR2(100))');
END IF;

-- Add a constraint only if it doesn't exist
IF NOT otk$ddl.constraint_exists('order_header_ref_uq', 'order_header') THEN
    otk$ddl.exec_ddl('ALTER TABLE order_header ADD CONSTRAINT order_header_ref_uq UNIQUE (external_ref)');
END IF;
```

### Clean sandbox rebuild

```plsql
otk$ddl.drop_table_if_exists('order_line_item', p_cascade_constraints => TRUE);
otk$ddl.drop_table_if_exists('order_header',    p_cascade_constraints => TRUE);
otk$ddl.drop_table_if_exists('customer');

otk$ddl.exec_ddl('CREATE TABLE customer    ( ... )');
otk$ddl.exec_ddl('CREATE TABLE order_header( ... )');
otk$ddl.exec_ddl('CREATE TABLE order_line_item( ... )');
```

### Check before referencing

```plsql
IF otk$ddl.table_exists('staging_orders') THEN
    otk$ddl.exec_ddl('INSERT INTO order_header SELECT ... FROM staging_orders');
    otk$ddl.drop_table_if_exists('staging_orders');
END IF;
```

---

## Files

```
src/ddl/
    build.sql       -- installs this module only
    otk$ddl.pks    -- package spec
    otk$ddl.pkb    -- package body
    README.md      -- this file

tests/
    ddl_t1.sql     -- full test suite
```

---

## Installation

Requires `otk$assert_utils` to be installed first.

```sql
@src/dbms_assert/build.sql
@src/ddl/build.sql
```
