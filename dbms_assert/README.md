
# dbms_assert Module

The `dbms_assert` module provides safe, consistent wrappers around Oracle’s `DBMS_ASSERT` package.
These utilities help prevent SQL injection by validating identifiers and quoting literals correctly.

All functionality is implemented in the package:

```
otk$assert_utils
```

---

## Purpose

Oracle’s `DBMS_ASSERT` package is powerful but low‑level.
This module provides:

- Cleaner, intention‑revealing wrapper functions
- Consistent naming and usage patterns
- Safer defaults for dynamic SQL construction
- A foundation for higher‑level dynamic SQL utilities

---

## Package: `otk$assert_utils`

### Functions

| Function | Purpose |
|---------|---------|
| `simple_name` | Validates a single SQL identifier (table, column, index, constraint) |
| `object_name` | Validates a schema‑qualified SQL object name |
| `schema_name` | Validates a schema name |
| `literal` | Safely quotes a literal value |
| `enquote` | Safely quotes an identifier (case‑sensitive or special chars) |

---

## Examples

### Validate a table name
```plsql
l_table := otk$assert_utils.object_name('HR.EMPLOYEES');
```

### Validate a column name
```plsql
l_col := otk$assert_utils.simple_name('EMPLOYEE_ID');
```

### Safely quote a literal
```plsql
l_val := otk$assert_utils.literal('O''Reilly');
```

### Use in dynamic SQL
```plsql
EXECUTE IMMEDIATE
    'DROP TABLE ' || otk$assert_utils.object_name(l_user_table);
```

---

## Files

```
otk$assert_utils.pks   -- package specification
otk$assert_utils.pkb   -- package body
README.md              -- this file
```

---

## Future Enhancements

- Extended identifier validation helpers
- Integration with dynamic SQL builder module
- Test harness for injection‑resistance scenarios
