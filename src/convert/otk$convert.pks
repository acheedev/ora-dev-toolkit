CREATE OR REPLACE PACKAGE otk$convert IS

    ----------------------------------------------------------------------
    -- Compatible with Oracle 12c and later.
    ----------------------------------------------------------------------

    ----------------------------------------------------------------------
    -- Safe numeric conversion
    -- Returns p_default instead of raising on bad input.
    ----------------------------------------------------------------------
    FUNCTION to_number(p_str     IN VARCHAR2,
                       p_default IN NUMBER DEFAULT NULL) RETURN NUMBER;

    ----------------------------------------------------------------------
    -- Safe date / timestamp conversion
    -- Returns p_default instead of raising on bad input or format mismatch.
    ----------------------------------------------------------------------
    FUNCTION to_date     (p_str     IN VARCHAR2,
                          p_fmt     IN VARCHAR2  DEFAULT 'YYYY-MM-DD',
                          p_default IN DATE      DEFAULT NULL) RETURN DATE;

    FUNCTION to_timestamp(p_str     IN VARCHAR2,
                          p_fmt     IN VARCHAR2  DEFAULT 'YYYY-MM-DD HH24:MI:SS',
                          p_default IN TIMESTAMP DEFAULT NULL) RETURN TIMESTAMP;

    ----------------------------------------------------------------------
    -- Boolean conversions
    -- to_bool: accepts Y/YES/TRUE/1 (TRUE) and N/NO/FALSE/0 (FALSE).
    --          Case-insensitive. Anything else returns NULL.
    -- to_yn:   TRUE->'Y'  | FALSE->'N'  | NULL->NULL
    -- to_tf:   TRUE->'TRUE'| FALSE->'FALSE'| NULL->NULL
    ----------------------------------------------------------------------
    FUNCTION to_bool(p_str  IN VARCHAR2) RETURN BOOLEAN;
    FUNCTION to_yn  (p_bool IN BOOLEAN)  RETURN VARCHAR2;
    FUNCTION to_tf  (p_bool IN BOOLEAN)  RETURN VARCHAR2;

    ----------------------------------------------------------------------
    -- NULL coalescing — typed NVL wrappers for clean chaining
    ----------------------------------------------------------------------
    FUNCTION nvl_str (p_val IN VARCHAR2, p_default IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION nvl_num (p_val IN NUMBER,   p_default IN NUMBER)   RETURN NUMBER;
    FUNCTION nvl_date(p_val IN DATE,     p_default IN DATE)     RETURN DATE;

END otk$convert;
/
