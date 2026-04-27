CREATE OR REPLACE PACKAGE BODY otk$json IS

    ----------------------------------------------------------------------
    -- Private: extract any JSON node (object or array) as CLOB
    ----------------------------------------------------------------------
    FUNCTION extract_node(p_json IN CLOB, p_path IN VARCHAR2) RETURN CLOB IS
        l_result CLOB;
        l_sql    VARCHAR2(4000);
    BEGIN
        l_sql := 'SELECT JSON_QUERY(:p_json, ''' || REPLACE(p_path, '''', '''''') || ''' RETURNING CLOB NULL ON ERROR) FROM dual';
        EXECUTE IMMEDIATE l_sql INTO l_result USING p_json;
        RETURN l_result;
    EXCEPTION
        WHEN OTHERS THEN RETURN NULL;
    END extract_node;


    ----------------------------------------------------------------------
    -- Validation
    ----------------------------------------------------------------------
    FUNCTION is_valid(p_json IN CLOB) RETURN BOOLEAN IS
        l_dummy VARCHAR2(1);
    BEGIN
        SELECT 'Y' INTO l_dummy
        FROM dual
        WHERE p_json IS JSON;
        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN FALSE;
        WHEN OTHERS        THEN RETURN FALSE;
    END is_valid;


    ----------------------------------------------------------------------
    -- Scalar extraction
    ----------------------------------------------------------------------
    FUNCTION get_str(p_json IN CLOB, p_path IN VARCHAR2) RETURN VARCHAR2 IS
        l_result VARCHAR2(32767);
        l_sql    VARCHAR2(4000);
    BEGIN
        l_sql := 'SELECT JSON_VALUE(:p_json, ''' || REPLACE(p_path, '''', '''''') || ''' RETURNING VARCHAR2(32767) NULL ON ERROR) FROM dual';
        EXECUTE IMMEDIATE l_sql INTO l_result USING p_json;
        RETURN l_result;
    EXCEPTION
        WHEN OTHERS THEN RETURN NULL;
    END get_str;

    FUNCTION get_num(p_json IN CLOB, p_path IN VARCHAR2) RETURN NUMBER IS
        l_result NUMBER;
        l_sql    VARCHAR2(4000);
    BEGIN
        l_sql := 'SELECT JSON_VALUE(:p_json, ''' || REPLACE(p_path, '''', '''''') || ''' RETURNING NUMBER NULL ON ERROR) FROM dual';
        EXECUTE IMMEDIATE l_sql INTO l_result USING p_json;
        RETURN l_result;
    EXCEPTION
        WHEN OTHERS THEN RETURN NULL;
    END get_num;

    FUNCTION get_date(
        p_json IN CLOB,
        p_path IN VARCHAR2,
        p_fmt  IN VARCHAR2 DEFAULT 'YYYY-MM-DD'
    ) RETURN DATE IS
        l_str VARCHAR2(100);
    BEGIN
        l_str := get_str(p_json, p_path);
        IF l_str IS NULL THEN RETURN NULL; END IF;
        RETURN TO_DATE(l_str, p_fmt);
    END get_date;

    FUNCTION get_bool(p_json IN CLOB, p_path IN VARCHAR2) RETURN BOOLEAN IS
        l_str VARCHAR2(10);
        l_sql VARCHAR2(4000);
    BEGIN
        l_sql := 'SELECT JSON_VALUE(:p_json, ''' || REPLACE(p_path, '''', '''''') || ''' RETURNING VARCHAR2 NULL ON ERROR) FROM dual';
        EXECUTE IMMEDIATE l_sql INTO l_str USING p_json;
        RETURN CASE LOWER(l_str)
            WHEN 'true'  THEN TRUE
            WHEN 'false' THEN FALSE
            ELSE NULL
        END;
    EXCEPTION
        WHEN OTHERS THEN RETURN NULL;
    END get_bool;

    FUNCTION get_bool_yn(p_json IN CLOB, p_path IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN CASE get_bool(p_json, p_path)
            WHEN TRUE  THEN 'Y'
            WHEN FALSE THEN 'N'
            ELSE NULL
        END;
    END get_bool_yn;


    ----------------------------------------------------------------------
    -- Object / array extraction
    ----------------------------------------------------------------------
    FUNCTION get_obj(p_json IN CLOB, p_path IN VARCHAR2) RETURN CLOB IS
    BEGIN
        RETURN extract_node(p_json, p_path);
    END get_obj;

    FUNCTION get_arr(p_json IN CLOB, p_path IN VARCHAR2) RETURN CLOB IS
    BEGIN
        RETURN extract_node(p_json, p_path);
    END get_arr;


    ----------------------------------------------------------------------
    -- Path existence
    ----------------------------------------------------------------------
    FUNCTION path_exists(p_json IN CLOB, p_path IN VARCHAR2) RETURN BOOLEAN IS
        l_result VARCHAR2(1);
        l_sql    VARCHAR2(4000);
    BEGIN
        l_sql := 'SELECT CASE WHEN JSON_EXISTS(:p_json, ''' || REPLACE(p_path, '''', '''''') || ''') THEN ''Y'' ELSE ''N'' END FROM dual';
        EXECUTE IMMEDIATE l_sql INTO l_result USING p_json;
        RETURN l_result = 'Y';
    EXCEPTION
        WHEN OTHERS THEN RETURN FALSE;
    END path_exists;


    ----------------------------------------------------------------------
    -- Array utilities
    ----------------------------------------------------------------------
    FUNCTION arr_count(p_json IN CLOB, p_path IN VARCHAR2 DEFAULT '$') RETURN NUMBER IS
        l_arr   CLOB;
        l_count NUMBER;
    BEGIN
        l_arr := CASE p_path WHEN '$' THEN p_json ELSE get_arr(p_json, p_path) END;
        IF l_arr IS NULL THEN RETURN NULL; END IF;

        SELECT COUNT(*) INTO l_count
        FROM JSON_TABLE(l_arr, '$[*]' COLUMNS (dummy FOR ORDINALITY));
        RETURN l_count;
    EXCEPTION WHEN OTHERS THEN
        RETURN NULL;
    END arr_count;

    FUNCTION arr_element(
        p_json  IN CLOB,
        p_index IN PLS_INTEGER,
        p_path  IN VARCHAR2 DEFAULT '$'
    ) RETURN CLOB IS
        l_arr    CLOB;
        l_result CLOB;
        l_scalar VARCHAR2(32767);
        l_idx    VARCHAR2(20);
    BEGIN
        l_arr := CASE p_path WHEN '$' THEN p_json ELSE get_arr(p_json, p_path) END;
        IF l_arr IS NULL THEN RETURN NULL; END IF;

        l_idx := TO_CHAR(p_index - 1);   -- convert 1-based to 0-based JSON index

        -- Try as object or array first
        BEGIN
            EXECUTE IMMEDIATE 'SELECT JSON_QUERY(:p_arr, ''$[' || l_idx || ']'' RETURNING CLOB NULL ON ERROR) FROM dual'
            INTO l_result USING l_arr;
        EXCEPTION WHEN OTHERS THEN
            l_result := NULL;
        END;

        -- Fall back to scalar if the element is a primitive value
        IF l_result IS NULL THEN
            BEGIN
                EXECUTE IMMEDIATE 'SELECT JSON_VALUE(:p_arr, ''$[' || l_idx || ']'' RETURNING VARCHAR2(32767) NULL ON ERROR) FROM dual'
                INTO l_scalar USING l_arr;
                l_result := l_scalar;
            EXCEPTION WHEN OTHERS THEN
                l_result := NULL;
            END;
        END IF;

        RETURN l_result;
    END arr_element;


    ----------------------------------------------------------------------
    -- Building / merging
    ----------------------------------------------------------------------
    FUNCTION build_obj(p_key IN VARCHAR2, p_value IN VARCHAR2) RETURN CLOB IS
    BEGIN
        RETURN JSON_OBJECT(p_key VALUE p_value RETURNING CLOB);
    END build_obj;

    FUNCTION merge_obj(p_base IN CLOB, p_overlay IN CLOB) RETURN CLOB IS
        l_result CLOB;
    BEGIN
        IF p_base    IS NULL THEN RETURN p_overlay; END IF;
        IF p_overlay IS NULL THEN RETURN p_base;    END IF;

        SELECT JSON_MERGEPATCH(p_base, p_overlay RETURNING CLOB)
        INTO l_result FROM dual;
        RETURN l_result;
    END merge_obj;


    ----------------------------------------------------------------------
    -- Formatting
    ----------------------------------------------------------------------
    FUNCTION pretty(p_json IN CLOB) RETURN CLOB IS
        l_result CLOB;
    BEGIN
        SELECT JSON_SERIALIZE(p_json RETURNING CLOB PRETTY)
        INTO l_result FROM dual;
        RETURN l_result;
    EXCEPTION WHEN OTHERS THEN
        RETURN p_json;
    END pretty;


END otk$json;
/
