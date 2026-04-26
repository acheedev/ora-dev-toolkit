CREATE OR REPLACE PACKAGE BODY otk$convert IS

    ----------------------------------------------------------------------
    -- Safe numeric conversion
    ----------------------------------------------------------------------
    FUNCTION to_number(p_str IN VARCHAR2, p_default IN NUMBER DEFAULT NULL) RETURN NUMBER IS
    BEGIN
        IF p_str IS NULL THEN RETURN p_default; END IF;
        RETURN STANDARD.TO_NUMBER(p_str);
    EXCEPTION WHEN OTHERS THEN
        RETURN p_default;
    END to_number;


    ----------------------------------------------------------------------
    -- Safe date / timestamp conversion
    ----------------------------------------------------------------------
    FUNCTION to_date(
        p_str     IN VARCHAR2,
        p_fmt     IN VARCHAR2 DEFAULT 'YYYY-MM-DD',
        p_default IN DATE     DEFAULT NULL
    ) RETURN DATE IS
    BEGIN
        IF p_str IS NULL THEN RETURN p_default; END IF;
        RETURN STANDARD.TO_DATE(p_str, p_fmt);
    EXCEPTION WHEN OTHERS THEN
        RETURN p_default;
    END to_date;

    FUNCTION to_timestamp(
        p_str     IN VARCHAR2,
        p_fmt     IN VARCHAR2  DEFAULT 'YYYY-MM-DD HH24:MI:SS',
        p_default IN TIMESTAMP DEFAULT NULL
    ) RETURN TIMESTAMP IS
    BEGIN
        IF p_str IS NULL THEN RETURN p_default; END IF;
        RETURN STANDARD.TO_TIMESTAMP(p_str, p_fmt);
    EXCEPTION WHEN OTHERS THEN
        RETURN p_default;
    END to_timestamp;


    ----------------------------------------------------------------------
    -- Boolean conversions
    ----------------------------------------------------------------------
    FUNCTION to_bool(p_str IN VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        CASE UPPER(TRIM(p_str))
            WHEN 'Y'     THEN RETURN TRUE;
            WHEN 'YES'   THEN RETURN TRUE;
            WHEN 'TRUE'  THEN RETURN TRUE;
            WHEN '1'     THEN RETURN TRUE;
            WHEN 'N'     THEN RETURN FALSE;
            WHEN 'NO'    THEN RETURN FALSE;
            WHEN 'FALSE' THEN RETURN FALSE;
            WHEN '0'     THEN RETURN FALSE;
            ELSE              RETURN NULL;
        END CASE;
    END to_bool;

    FUNCTION to_yn(p_bool IN BOOLEAN) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE p_bool
            WHEN TRUE  THEN 'Y'
            WHEN FALSE THEN 'N'
            ELSE NULL
        END;
    END to_yn;

    FUNCTION to_tf(p_bool IN BOOLEAN) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE p_bool
            WHEN TRUE  THEN 'TRUE'
            WHEN FALSE THEN 'FALSE'
            ELSE NULL
        END;
    END to_tf;


    ----------------------------------------------------------------------
    -- NULL coalescing
    ----------------------------------------------------------------------
    FUNCTION nvl_str(p_val IN VARCHAR2, p_default IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN NVL(p_val, p_default);
    END nvl_str;

    FUNCTION nvl_num(p_val IN NUMBER, p_default IN NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN NVL(p_val, p_default);
    END nvl_num;

    FUNCTION nvl_date(p_val IN DATE, p_default IN DATE) RETURN DATE IS
    BEGIN
        RETURN NVL(p_val, p_default);
    END nvl_date;


END otk$convert;
/
