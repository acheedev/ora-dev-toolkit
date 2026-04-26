CREATE OR REPLACE PACKAGE otk$clob IS

    ----------------------------------------------------------------------
    -- Compatible with Oracle 12c and later.
    ----------------------------------------------------------------------

    ----------------------------------------------------------------------
    -- Inspection
    ----------------------------------------------------------------------
    FUNCTION is_empty  (p_clob IN CLOB) RETURN BOOLEAN;
    FUNCTION clob_len  (p_clob IN CLOB) RETURN NUMBER;      -- NULL-safe DBMS_LOB.GETLENGTH

    ----------------------------------------------------------------------
    -- Conversion
    -- to_vc2: if CLOB exceeds p_max_len, returns truncated value with
    --         ' ...[TRUNCATED]' appended rather than silently losing data.
    ----------------------------------------------------------------------
    FUNCTION to_vc2  (p_clob    IN CLOB,
                      p_max_len IN PLS_INTEGER DEFAULT 32767) RETURN VARCHAR2;
    FUNCTION from_vc2(p_str IN VARCHAR2) RETURN CLOB;

    ----------------------------------------------------------------------
    -- Search
    ----------------------------------------------------------------------
    FUNCTION contains   (p_clob IN CLOB, p_search IN VARCHAR2) RETURN BOOLEAN;
    FUNCTION find_pos   (p_clob IN CLOB, p_search IN VARCHAR2,
                         p_occurrence IN PLS_INTEGER DEFAULT 1) RETURN NUMBER;
    FUNCTION starts_with(p_clob IN CLOB, p_prefix IN VARCHAR2) RETURN BOOLEAN;
    FUNCTION ends_with  (p_clob IN CLOB, p_suffix IN VARCHAR2) RETURN BOOLEAN;

    ----------------------------------------------------------------------
    -- Modification
    ----------------------------------------------------------------------
    FUNCTION replace_str(p_clob    IN CLOB,
                         p_search  IN VARCHAR2,
                         p_replace IN VARCHAR2) RETURN CLOB;
    FUNCTION trim_clob  (p_clob IN CLOB) RETURN CLOB;

    ----------------------------------------------------------------------
    -- Concatenation
    -- append: NOCOPY avoids copying the target CLOB on entry.
    --         Initialises a temporary CLOB if p_target is NULL.
    ----------------------------------------------------------------------
    FUNCTION  concat_clob(p_clob1 IN CLOB, p_clob2 IN CLOB) RETURN CLOB;
    PROCEDURE append     (p_target IN OUT NOCOPY CLOB, p_src IN CLOB);

    ----------------------------------------------------------------------
    -- Chunking
    -- Primary use: feeding a CLOB to UTL_HTTP.WRITE_TEXT (32767-byte limit).
    -- p_chunk_num is 1-based. chunk() returns NULL if chunk_num > chunk_count().
    ----------------------------------------------------------------------
    FUNCTION chunk_count(p_clob IN CLOB,
                         p_size IN PLS_INTEGER DEFAULT 32767) RETURN NUMBER;
    FUNCTION chunk      (p_clob      IN CLOB,
                         p_chunk_num IN PLS_INTEGER,
                         p_size      IN PLS_INTEGER DEFAULT 32767) RETURN VARCHAR2;

    ----------------------------------------------------------------------
    -- Line utilities
    -- Handles both LF and CRLF line endings. Empty lines are preserved.
    -- Elements in split_lines are capped at VARCHAR2(4000) per line.
    ----------------------------------------------------------------------
    FUNCTION line_count (p_clob IN CLOB) RETURN NUMBER;
    FUNCTION get_line   (p_clob IN CLOB, p_line_num IN PLS_INTEGER) RETURN VARCHAR2;
    FUNCTION split_lines(p_clob IN CLOB) RETURN SYS.ODCIVARCHAR2LIST;

END otk$clob;
/
