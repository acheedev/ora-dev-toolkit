CREATE OR REPLACE PACKAGE BODY otk$log_json IS

    g_log_level    VARCHAR2(10) := c_level_info;
    g_context      JSON;
    g_json_payload JSON;

    PROCEDURE set_level(p_level IN VARCHAR2) IS
    BEGIN
        g_log_level := UPPER(p_level);
    END;

    FUNCTION get_level RETURN VARCHAR2 IS
    BEGIN
        RETURN g_log_level;
    END;

    PROCEDURE context(p_key IN VARCHAR2, p_value IN VARCHAR2) IS
    BEGIN
        IF g_context IS NULL THEN
            g_context := JSON_OBJECT(p_key VALUE p_value);
        ELSE
            g_context := g_context || JSON_OBJECT(p_key VALUE p_value);
        END IF;
    END;

    PROCEDURE clear_context IS
    BEGIN
        g_context := NULL;
    END;

    PROCEDURE json(p_json IN JSON) IS
    BEGIN
        g_json_payload := p_json;
    END;

    FUNCTION level_enabled(p_level VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        CASE g_log_level
            WHEN c_level_debug THEN RETURN TRUE;
            WHEN c_level_info  THEN RETURN p_level IN (c_level_info, c_level_warn, c_level_error);
            WHEN c_level_warn  THEN RETURN p_level IN (c_level_warn, c_level_error);
            WHEN c_level_error THEN RETURN p_level = c_level_error;
        END CASE;
        RETURN TRUE;
    END;

    PROCEDURE write_log(
        p_level       IN VARCHAR2,
        p_message     IN VARCHAR2,
        p_sqlerrm     IN VARCHAR2 DEFAULT NULL,
        p_stack       IN CLOB    DEFAULT NULL,
        p_backtrace   IN CLOB    DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO otk_error_log_json (
            log_level,
            context_data,
            json_payload,
            message,
            sqlerrm_text,
            error_stack,
            error_backtrace
        )
        VALUES (
            p_level,
            g_context,
            g_json_payload,
            p_message,
            p_sqlerrm,
            p_stack,
            p_backtrace
        );

        COMMIT;

        g_json_payload := NULL;
    END;

    PROCEDURE error(p_message IN VARCHAR2 DEFAULT NULL) IS
        l_sqlerrm VARCHAR2(4000);
    BEGIN
        IF NOT level_enabled(c_level_error) THEN RETURN; END IF;

        l_sqlerrm := SUBSTR(SQLERRM, 1, 4000);

        write_log(
            p_level     => c_level_error,
            p_message   => p_message,
            p_sqlerrm   => l_sqlerrm,
            p_stack     => DBMS_UTILITY.format_error_stack,
            p_backtrace => DBMS_UTILITY.format_error_backtrace
        );
    END;

    PROCEDURE warn(p_message IN VARCHAR2) IS
    BEGIN
        IF level_enabled(c_level_warn) THEN
            write_log(c_level_warn, p_message);
        END IF;
    END;

    PROCEDURE info(p_message IN VARCHAR2) IS
    BEGIN
        IF level_enabled(c_level_info) THEN
            write_log(c_level_info, p_message);
        END IF;
    END;

    PROCEDURE debug(p_message IN VARCHAR2) IS
    BEGIN
        IF level_enabled(c_level_debug) THEN
            write_log(c_level_debug, p_message);
        END IF;
    END;

    PROCEDURE purge(p_days IN NUMBER) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        DELETE FROM otk_error_log_json
        WHERE log_timestamp < SYSTIMESTAMP - p_days;
        COMMIT;
    END;

    FUNCTION get_recent(p_limit IN NUMBER) RETURN SYS_REFCURSOR IS
        l_rc SYS_REFCURSOR;
    BEGIN
        OPEN l_rc FOR
            SELECT *
            FROM otk_error_log_json
            ORDER BY log_id DESC
            FETCH FIRST p_limit ROWS ONLY;
        RETURN l_rc;
    END;

    FUNCTION search(p_keyword IN VARCHAR2) RETURN SYS_REFCURSOR IS
        l_rc SYS_REFCURSOR;
    BEGIN
        OPEN l_rc FOR
            SELECT *
            FROM otk_error_log_json
            WHERE message      LIKE '%' || p_keyword || '%'
               OR sqlerrm_text LIKE '%' || p_keyword || '%';
        RETURN l_rc;
    END;

END otk$log_json;
/
