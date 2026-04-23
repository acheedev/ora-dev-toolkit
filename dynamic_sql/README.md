
# dynamic_sql Module

The `dynamic_sql` module provides a fluent, object‑oriented API for safely constructing
dynamic SQL `SELECT` statements in Oracle. It is built on top of the toolkit’s
`otk$assert_utils` package and uses the standalone object type `otk$ds_query_t` to
represent a query under construction.

This module is intentionally minimal for v1 — it focuses exclusively on safe,
composable `SELECT` statements. Future versions will expand into INSERT/UPDATE/DELETE
builders and full AST‑style SQL construction.

---

## Purpose

Dynamic SQL is powerful but error‑prone. This module provides:

- A clean, fluent API for building SQL queries
- Safe identifier validation using `otk$assert_utils`
- Automatic bind variable collection
- Predictable, testable SQL generation
- A foundation for more advanced SQL builders in future releases

The goal is to eliminate string‑concatenation SQL and replace it with a structured,
declarative builder.

---

## Core Components

### **Object Type: `otk$ds_query_t`**

This object represents a SQL query under construction.
It stores:

- `select_list` — list of validated column names
- `table_name` — validated table name
- `where_clauses` — list of raw WHERE clause fragments
- `bind_values` — list of bind values (as strings)
- `order_by_clause` — validated ORDER BY column
- `fetch_rows` — optional row limit

It also exposes fluent member functions:

- `select_cols(...)`
- `from_table(...)`
- `where_clause(...)`
- `order_by(...)`
- `fetch_first(...)`
- `build(...)`

### **Package: `otk$dynamic_sql_builder`**

Provides the constructor:

```
FUNCTION new_query RETURN otk$ds_query_t;
```

This returns a fully initialized query object with empty lists and null optional fields.

---

## Example Usage

```plsql
DECLARE
    l_sql   VARCHAR2(4000);
    l_binds SYS.ODCIVARCHAR2LIST;
BEGIN
    otk$dynamic_sql_builder.new_query
        .select_cols( SYS.ODCIVARCHAR2LIST('EMPLOYEE_ID', 'LAST_NAME') )
        .from_table('HR.EMPLOYEES')
        .where_clause('DEPARTMENT_ID = :b1', ANYDATA.ConvertNumber(50))
        .order_by('LAST_NAME')
        .fetch_first(10)
        .build(l_sql, l_binds);

    DBMS_OUTPUT.put_line('SQL: ' || l_sql);

    FOR i IN 1 .. l_binds.COUNT LOOP
        DBMS_OUTPUT.put_line('Bind ' || i || ': ' || l_binds(i));
    END LOOP;
END;
/
```

Produces SQL:

```
SELECT EMPLOYEE_ID, LAST_NAME
FROM HR.EMPLOYEES
WHERE DEPARTMENT_ID = :b1
ORDER BY LAST_NAME
FETCH FIRST 10 ROWS ONLY
```

---

## Files

```
otk$ds_query_t_s.sql        -- standalone object type (spec)
otk$ds_query_t_b.sql        -- object type body (fluent API)
otk$dynamic_sql_builder.pks -- constructor package spec
otk$dynamic_sql_builder.pkb -- constructor package body
README.md                   -- this file
```

---

## Future Enhancements

- JOIN support (inner, left, right)
- Automatic bind placeholder numbering
- INSERT/UPDATE/DELETE builders
- Expression helpers (eq, lt, like, between, in)
- ORDER BY multiple columns
- GROUP BY / HAVING
- Full AST‑style SQL construction
