
# clob Module (`otk$clob`)

The `clob` module provides utilities for the everyday CLOB operations that Oracle's
built-ins make unnecessarily verbose or error-prone: safe conversion, search, modification,
line-by-line parsing, and chunked reads for HTTP and file I/O.

**Compatible with Oracle 12c and later.**

---

## API Reference

### Inspection

```plsql
FUNCTION is_empty(p_clob IN CLOB) RETURN BOOLEAN;
FUNCTION clob_len(p_clob IN CLOB) RETURN NUMBER;
```

`is_empty` returns `TRUE` for both `NULL` and zero-length CLOBs — they behave the same
in practice and callers rarely need to distinguish them.

`clob_len` is a NULL-safe wrapper around `DBMS_LOB.GETLENGTH`. Returns `0` for NULL
rather than raising, which is the natural value for "nothing here".

---

### Conversion

```plsql
FUNCTION to_vc2  (p_clob    IN CLOB,
                  p_max_len IN PLS_INTEGER DEFAULT 32767) RETURN VARCHAR2;
FUNCTION from_vc2(p_str IN VARCHAR2) RETURN CLOB;
```

`to_vc2` never silently truncates. If the CLOB exceeds `p_max_len`, it returns the first
N characters with ` ...[TRUNCATED]` appended. The caller can detect truncation with
`INSTR(result, '[TRUNCATED]') > 0`. Default limit is 32767 (PL/SQL VARCHAR2 max).
Pass 4000 explicitly when the result will cross into SQL.

`from_vc2` is an explicit counterpart — useful when you want to make the VARCHAR2→CLOB
promotion visible at the call site rather than relying on implicit conversion.

---

### Search

```plsql
FUNCTION contains   (p_clob IN CLOB, p_search IN VARCHAR2) RETURN BOOLEAN;
FUNCTION find_pos   (p_clob IN CLOB, p_search IN VARCHAR2,
                     p_occurrence IN PLS_INTEGER DEFAULT 1) RETURN NUMBER;
FUNCTION starts_with(p_clob IN CLOB, p_prefix IN VARCHAR2) RETURN BOOLEAN;
FUNCTION ends_with  (p_clob IN CLOB, p_suffix IN VARCHAR2) RETURN BOOLEAN;
```

`find_pos` wraps `DBMS_LOB.INSTR` and returns `0` if not found (same convention).
`p_occurrence` lets you find the 2nd, 3rd, etc. match.

NULL for either argument returns `FALSE` or `0` — no exceptions on missing input.

---

### Modification

```plsql
FUNCTION replace_str(p_clob    IN CLOB,
                     p_search  IN VARCHAR2,
                     p_replace IN VARCHAR2) RETURN CLOB;
FUNCTION trim_clob  (p_clob IN CLOB) RETURN CLOB;
```

`replace_str` replaces all occurrences. Oracle's `REPLACE()` function accepts CLOB
arguments natively — this wrapper adds NULL safety and a clean name.

`trim_clob` strips leading and trailing whitespace (spaces, tabs, CR, LF). Returns
`EMPTY_CLOB()` for an all-whitespace input, `NULL` for a NULL input.

---

### Concatenation

```plsql
FUNCTION  concat_clob(p_clob1 IN CLOB, p_clob2 IN CLOB) RETURN CLOB;
PROCEDURE append     (p_target IN OUT NOCOPY CLOB, p_src IN CLOB);
```

`concat_clob` creates a temporary CLOB and appends both inputs. NULL inputs are
treated as empty — returns the non-null side if one is NULL.

`append` modifies `p_target` in place. `NOCOPY` prevents Oracle from copying the
entire target CLOB on procedure entry — critical for large CLOBs in tight loops.
If `p_target` is NULL, a temporary CLOB is initialised automatically.

Typical pattern for building a large CLOB incrementally:

```plsql
l_body CLOB;  -- starts NULL
otk$clob.append(l_body, TO_CLOB('<root>'));
FOR r IN (SELECT ... FROM ...) LOOP
    otk$clob.append(l_body, TO_CLOB('<row>' || r.value || '</row>'));
END LOOP;
otk$clob.append(l_body, TO_CLOB('</root>'));
```

---

### Chunking

```plsql
FUNCTION chunk_count(p_clob IN CLOB,
                     p_size IN PLS_INTEGER DEFAULT 32767) RETURN NUMBER;
FUNCTION chunk      (p_clob      IN CLOB,
                     p_chunk_num IN PLS_INTEGER,
                     p_size      IN PLS_INTEGER DEFAULT 32767) RETURN VARCHAR2;
```

`UTL_HTTP.WRITE_TEXT` accepts at most 32767 bytes per call. Use these to feed a CLOB
to an HTTP request body without manual offset arithmetic:

```plsql
l_chunks := otk$clob.chunk_count(l_body);
FOR i IN 1 .. l_chunks LOOP
    UTL_HTTP.WRITE_TEXT(l_req, otk$clob.chunk(l_body, i));
END LOOP;
```

`chunk_num` is 1-based. Returns `NULL` if `chunk_num` exceeds the available chunks.

---

### Line Utilities

```plsql
FUNCTION line_count (p_clob IN CLOB) RETURN NUMBER;
FUNCTION get_line   (p_clob IN CLOB, p_line_num IN PLS_INTEGER) RETURN VARCHAR2;
FUNCTION split_lines(p_clob IN CLOB) RETURN SYS.ODCIVARCHAR2LIST;
```

Handles both LF and CRLF line endings. Empty lines are preserved as empty strings.
Each element in `split_lines` is capped at VARCHAR2(4000).

`p_line_num` in `get_line` is 1-based. Returns `NULL` for out-of-range indices.

Typical use — parse a multi-line API response or config payload:

```plsql
l_lines := otk$clob.split_lines(l_response_body);
FOR i IN 1 .. l_lines.COUNT LOOP
    IF otk$clob.starts_with(l_lines(i), 'ERROR:') THEN
        otk$log.error(message => l_lines(i));
    END IF;
END LOOP;
```

---

## Files

```
src/clob/
    otk$clob.pks    -- package spec
    otk$clob.pkb    -- package body
    README.md       -- this file

tests/
    clob_t1.sql     -- full test suite
```

---

## Installation

No dependencies. Can be installed in any order relative to other modules.

```sql
@src/clob/otk$clob.pks
@src/clob/otk$clob.pkb
```
