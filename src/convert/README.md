
# convert Module (`otk$convert`)

The `convert` module provides safe, default-returning type conversions and boolean
adapters. It eliminates the exception handlers you write over and over just to handle
bad input gracefully, and bridges the gap between PL/SQL `BOOLEAN` and the string
representations that SQL and external systems actually use.

**Compatible with Oracle 12c and later.**

---

## API Reference

### Safe Numeric Conversion

```plsql
FUNCTION to_number(p_str     IN VARCHAR2,
                   p_default IN NUMBER DEFAULT NULL) RETURN NUMBER;
```

Returns `p_default` instead of raising on bad input or NULL. Eliminates the
`BEGIN / TO_NUMBER / EXCEPTION WHEN OTHERS THEN RETURN 0 / END` blocks that
litter most PL/SQL codebases.

---

### Safe Date / Timestamp Conversion

```plsql
FUNCTION to_date     (p_str     IN VARCHAR2,
                      p_fmt     IN VARCHAR2  DEFAULT 'YYYY-MM-DD',
                      p_default IN DATE      DEFAULT NULL) RETURN DATE;

FUNCTION to_timestamp(p_str     IN VARCHAR2,
                      p_fmt     IN VARCHAR2  DEFAULT 'YYYY-MM-DD HH24:MI:SS',
                      p_default IN TIMESTAMP DEFAULT NULL) RETURN TIMESTAMP;
```

Same pattern — return `p_default` on NULL input, format mismatch, or any conversion
error. Default formats match the ISO standards used by REST APIs and most modern
data exports.

---

### Boolean Conversions

```plsql
FUNCTION to_bool(p_str  IN VARCHAR2) RETURN BOOLEAN;
FUNCTION to_yn  (p_bool IN BOOLEAN)  RETURN VARCHAR2;
FUNCTION to_tf  (p_bool IN BOOLEAN)  RETURN VARCHAR2;
```

`to_bool` accepts the full range of conventions encountered in real data:

| Input (case-insensitive) | Result  |
|--------------------------|---------|
| `Y`, `YES`, `TRUE`, `1`  | `TRUE`  |
| `N`, `NO`, `FALSE`, `0`  | `FALSE` |
| anything else / NULL     | `NULL`  |

`to_yn` and `to_tf` are the two most common output shapes:
- `to_yn` → `'Y'`/`'N'`/`NULL` — Oracle column flags, internal APIs
- `to_tf` → `'TRUE'`/`'FALSE'`/`NULL` — REST payloads, JSON, external systems

Both handle `NULL` → `NULL` cleanly. Both round-trip through `to_bool`:

```plsql
otk$convert.to_bool(otk$convert.to_yn(TRUE))  -- TRUE
otk$convert.to_bool(otk$convert.to_tf(FALSE)) -- FALSE
```

---

### NULL Coalescing

```plsql
FUNCTION nvl_str (p_val IN VARCHAR2, p_default IN VARCHAR2) RETURN VARCHAR2;
FUNCTION nvl_num (p_val IN NUMBER,   p_default IN NUMBER)   RETURN NUMBER;
FUNCTION nvl_date(p_val IN DATE,     p_default IN DATE)     RETURN DATE;
```

Typed `NVL` wrappers. Their value is in chaining — combining with safe conversions
keeps the intent clear without introducing a temp variable:

```plsql
-- Without
l_qty := TO_NUMBER(otk$json.get_str(l_json, '$.qty'));  -- raises on NULL or bad data
IF l_qty IS NULL THEN l_qty := 1; END IF;

-- With
l_qty := otk$convert.nvl_num(otk$convert.to_number(otk$json.get_str(l_json, '$.qty')), 1);
```

---

## Common Patterns

### Process a REST payload with dirty fields

```plsql
l_order_id  := otk$convert.to_number(otk$json.get_str(l_json, '$.order_id'));
l_order_date:= otk$convert.to_date  (otk$json.get_str(l_json, '$.order_date'));
l_qty       := otk$convert.nvl_num  (otk$convert.to_number(otk$json.get_str(l_json, '$.qty')), 1);
l_active    := otk$convert.to_bool  (otk$json.get_str(l_json, '$.active'));
```

### Store a BOOLEAN result in a Y/N column

```plsql
UPDATE product_master
SET    is_active = otk$convert.to_yn(l_is_active)
WHERE  product_code = l_code;
```

### Build a JSON flag for an outbound payload

```plsql
l_payload := JSON_OBJECT(
    'active'    VALUE otk$convert.to_tf(l_is_active),
    'processed' VALUE otk$convert.to_tf(TRUE)
    RETURNING CLOB
);
```

---

## Files

```
src/convert/
    otk$convert.pks    -- package spec
    otk$convert.pkb    -- package body
    README.md          -- this file

tests/
    convert_t1.sql     -- full test suite
```

---

## Installation

No dependencies. Can be installed in any order.

```sql
@src/convert/otk$convert.pks
@src/convert/otk$convert.pkb
```
