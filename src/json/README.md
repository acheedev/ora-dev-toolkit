
# json Module (`otk$json`)

The `json` module provides clean, consistent wrappers for working with JSON stored in CLOBs.
It eliminates the boilerplate of `JSON_VALUE`/`JSON_QUERY` inline calls and centralises
error handling so callers deal with results, not syntax.

**Requires Oracle 19c or later.**

---

## Why this exists

Extracting values from a JSON CLOB in PL/SQL is tedious:

```plsql
-- Without otk$json
SELECT JSON_VALUE(l_payload, '$.customer.name' RETURNING VARCHAR2(4000) NULL ON ERROR)
INTO l_name FROM dual;

-- With otk$json
l_name := otk$json.get_str(l_payload, '$.customer.name');
```

Multiply that across 10 fields in a REST response handler and the difference is significant.

---

## API Reference

### Validation

```plsql
FUNCTION is_valid(p_json IN CLOB) RETURN BOOLEAN;
```

Returns `TRUE` if the CLOB contains well-formed JSON, `FALSE` otherwise (including NULL input).

---

### Scalar Extraction

All extraction functions return `NULL` if the path does not exist or the value is a JSON null.
They do **not** raise exceptions on missing paths — only on genuinely malformed JSON.

```plsql
FUNCTION get_str (p_json IN CLOB, p_path IN VARCHAR2) RETURN VARCHAR2;
FUNCTION get_num (p_json IN CLOB, p_path IN VARCHAR2) RETURN NUMBER;
FUNCTION get_date(p_json IN CLOB, p_path IN VARCHAR2,
                  p_fmt  IN VARCHAR2 DEFAULT 'YYYY-MM-DD') RETURN DATE;
FUNCTION get_bool   (p_json IN CLOB, p_path IN VARCHAR2) RETURN BOOLEAN;    -- PL/SQL only
FUNCTION get_bool_yn(p_json IN CLOB, p_path IN VARCHAR2) RETURN VARCHAR2;   -- 'Y'|'N'|NULL
```

Use `get_bool` in PL/SQL control flow. Use `get_bool_yn` when the result needs to cross
into SQL (e.g. stored in a column, used in a SELECT).

---

### Object / Array Extraction

Returns a nested JSON node as a CLOB, or NULL if the path does not exist.

```plsql
FUNCTION get_obj(p_json IN CLOB, p_path IN VARCHAR2) RETURN CLOB;
FUNCTION get_arr(p_json IN CLOB, p_path IN VARCHAR2) RETURN CLOB;
```

The returned CLOB is itself a valid JSON document and can be passed back into any
`otk$json` function.

---

### Path Existence

```plsql
FUNCTION path_exists(p_json IN CLOB, p_path IN VARCHAR2) RETURN BOOLEAN;
```

Returns `TRUE` even if the key exists but holds a JSON null — existence and nullity are
distinct concepts. Use `get_str(...) IS NULL` to test for null values.

---

### Array Utilities

```plsql
FUNCTION arr_count  (p_json  IN CLOB,
                     p_path  IN VARCHAR2    DEFAULT '$') RETURN NUMBER;
FUNCTION arr_element(p_json  IN CLOB,
                     p_index IN PLS_INTEGER,
                     p_path  IN VARCHAR2    DEFAULT '$') RETURN CLOB;
```

`p_path` points to the array node. Defaults to `'$'` when the CLOB itself is the array.
`p_index` is **1-based**, consistent with PL/SQL collection conventions.
`arr_element` returns a CLOB — pass it back to `get_str`/`get_num`/etc. for scalar elements,
or back to `get_obj` for nested object elements.

---

### Building / Merging

```plsql
FUNCTION build_obj(p_key IN VARCHAR2, p_value IN VARCHAR2) RETURN CLOB;
FUNCTION merge_obj(p_base IN CLOB, p_overlay IN CLOB)      RETURN CLOB;
```

`build_obj` produces a single key-value JSON object. For multi-key objects, use
`JSON_OBJECT(k1 VALUE v1, k2 VALUE v2 RETURNING CLOB)` directly — it is cleaner
than any vararg wrapper could be.

`merge_obj` uses `JSON_MERGEPATCH`: all keys from both objects are combined.
When the same key appears in both, `p_overlay` wins. NULL inputs are handled
gracefully (returns the non-null side).

---

### Formatting

```plsql
FUNCTION pretty(p_json IN CLOB) RETURN CLOB;
```

Returns the JSON indented and formatted for human reading. Returns the original CLOB
unchanged if serialization fails.

---

## Common Patterns

### Parse a REST response

```plsql
DECLARE
    l_response CLOB;  -- from otk$rest (coming soon)
    l_status   VARCHAR2(50);
    l_job_id   NUMBER;
    l_started  DATE;
BEGIN
    l_status  := otk$json.get_str (l_response, '$.status');
    l_job_id  := otk$json.get_num (l_response, '$.job.id');
    l_started := otk$json.get_date(l_response, '$.job.started_at');
END;
```

### Iterate a JSON array

```plsql
DECLARE
    l_items CLOB;
    l_item  CLOB;
    l_count NUMBER;
BEGIN
    l_items := otk$json.get_arr(l_payload, '$.items');
    l_count := otk$json.arr_count(l_items);

    FOR i IN 1 .. l_count LOOP
        l_item := otk$json.arr_element(l_items, i);
        DBMS_OUTPUT.put_line(otk$json.get_str(l_item, '$.sku'));
    END LOOP;
END;
```

### Validate before processing

```plsql
IF NOT otk$json.is_valid(l_payload) THEN
    otk$log.error(
        message => 'Invalid JSON payload received',
        payload => l_payload
    );
    RETURN;
END IF;
```

### Merge context for logging

```plsql
otk$log.info(
    message => 'Order processed',
    context => otk$log.ctx_merge(
        otk$log.ctx('module',   'order_sync'),
        otk$log.ctx('order_id', TO_CHAR(l_order_id))
    ),
    payload => otk$json.merge_obj(l_request, l_response)
);
```

---

## Files

```
src/json/
    build.sql       -- installs this module
    otk$json.pks    -- package spec
    otk$json.pkb    -- package body
    README.md       -- this file

tests/
    json_t1.sql     -- full test suite
```

---

## Installation

No dependencies. Can be installed in any order relative to other modules.

```sql
@src/json/build.sql
```

---

## Future Enhancements

- `get_str_d(p_default)` variants — return a default instead of NULL on missing path
- `arr_to_collection` — extract a scalar array directly into `SYS.ODCIVARCHAR2LIST`
- `from_refcursor` — serialize a `SYS_REFCURSOR` to a JSON array CLOB
