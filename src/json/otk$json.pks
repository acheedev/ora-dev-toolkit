CREATE OR REPLACE PACKAGE otk$json IS

    ----------------------------------------------------------------------
    -- Requires Oracle 19c or later.
    ----------------------------------------------------------------------

    ----------------------------------------------------------------------
    -- Validation
    ----------------------------------------------------------------------
    FUNCTION is_valid(p_json IN CLOB) RETURN BOOLEAN;

    ----------------------------------------------------------------------
    -- Scalar extraction
    -- Returns NULL if the path does not exist.
    -- Returns NULL (not an exception) on type mismatch.
    ----------------------------------------------------------------------
    FUNCTION get_str (p_json IN CLOB, p_path IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION get_num (p_json IN CLOB, p_path IN VARCHAR2) RETURN NUMBER;
    FUNCTION get_date(p_json IN CLOB, p_path IN VARCHAR2,
                      p_fmt  IN VARCHAR2 DEFAULT 'YYYY-MM-DD') RETURN DATE;

    -- Returns TRUE/FALSE/NULL (pure PL/SQL — not usable in SQL context)
    FUNCTION get_bool(p_json IN CLOB, p_path IN VARCHAR2) RETURN BOOLEAN;

    -- Returns 'Y'/'N'/NULL — SQL-safe equivalent of get_bool
    FUNCTION get_bool_yn(p_json IN CLOB, p_path IN VARCHAR2) RETURN VARCHAR2;

    ----------------------------------------------------------------------
    -- Object / array extraction (returns nested JSON as CLOB)
    ----------------------------------------------------------------------
    FUNCTION get_obj(p_json IN CLOB, p_path IN VARCHAR2) RETURN CLOB;
    FUNCTION get_arr(p_json IN CLOB, p_path IN VARCHAR2) RETURN CLOB;

    ----------------------------------------------------------------------
    -- Path existence
    ----------------------------------------------------------------------
    FUNCTION path_exists(p_json IN CLOB, p_path IN VARCHAR2) RETURN BOOLEAN;

    ----------------------------------------------------------------------
    -- Array utilities
    -- p_path points to the array node; defaults to root '$'
    -- p_index is 1-based, consistent with PL/SQL collection conventions
    ----------------------------------------------------------------------
    FUNCTION arr_count  (p_json  IN CLOB,
                         p_path  IN VARCHAR2    DEFAULT '$') RETURN NUMBER;
    FUNCTION arr_element(p_json  IN CLOB,
                         p_index IN PLS_INTEGER,
                         p_path  IN VARCHAR2    DEFAULT '$') RETURN CLOB;

    ----------------------------------------------------------------------
    -- Building / merging
    ----------------------------------------------------------------------
    -- Single key-value pair. For multi-key objects use JSON_OBJECT() directly in SQL.
    FUNCTION build_obj(p_key IN VARCHAR2, p_value IN VARCHAR2) RETURN CLOB;

    -- Merges two JSON objects. p_overlay wins on key conflict.
    FUNCTION merge_obj(p_base IN CLOB, p_overlay IN CLOB) RETURN CLOB;

    ----------------------------------------------------------------------
    -- Formatting
    ----------------------------------------------------------------------
    FUNCTION pretty(p_json IN CLOB) RETURN CLOB;

END otk$json;
/
