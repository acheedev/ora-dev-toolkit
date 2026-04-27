CREATE OR REPLACE PACKAGE BODY otk$log IS

    ----------------------------------------------------------------------
    -- JSON helpers (CLOB-based)
    ----------------------------------------------------------------------
    FUNCTION ctx(p_key VARCHAR2, p_value VARCHAR2) RETURN CLOB IS
    BEGIN
        RETURN TO_CLOB(JSON_OBJECT(p_key VALUE p_value));
    END;

    FUNCTION ctx_merge(p_ctx1 CLOB, p_ctx2 CLOB) RETURN CLOB IS
    BEGIN
        IF p_ctx1 IS NULL OR DBMS_LOB.GETLENGTH(p_ctx1) <= 2 THEN RETURN p_ctx2; END IF;
        IF p_ctx2 IS NULL OR DBMS_LOB.GETLENGTH(p_ctx2) <= 2 THEN RETURN p_ctx1; END IF;

        RETURN SUBSTR(p_ctx1, 1, LENGTH(p_ctx1)-1) ||
               ',' ||
               SUBSTR(p_ctx2, 2);
    END;

    ----------------------------------------------------------------------
    -- Internal write routine
    ----------------------------------------------------------------------
    PROCEDURE write_log(
        p_level     IN VARCHAR2,
        p_message   IN VARCHAR2,
        p_context   IN CLOB,
        p_payload   IN CLOB,
        p_sqlerrm   IN VARCHAR2 DEFAULT NULL,
        p_stack     IN CLOB DEFAULT NULL,
        p_backtrace IN CLOB DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO otk_error_log (
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
            p_context,
            p_payload,
            p_message,
            p_sqlerrm,
            p_stack,
            p_backtrace
        );

        COMMIT;
    END;

    ----------------------------------------------------------------------
    -- Public API
    ----------------------------------------------------------------------
    PROCEDURE error(
        message IN VARCHAR2,
        context IN CLOB DEFAULT NULL,
        payload IN CLOB DEFAULT NULL
    ) IS
        l_sqlerrm VARCHAR2(4000);
    BEGIN
        l_sqlerrm := SUBSTR(SQLERRM, 1, 4000);

        write_log(
            p_level     => c_level_error,
            p_message   => message,
            p_context   => context,
            p_payload   => payload,
            p_sqlerrm   => l_sqlerrm,
            p_stack     => DBMS_UTILITY.format_error_stack,
            p_backtrace => DBMS_UTILITY.format_error_backtrace
        );
    END;

    PROCEDURE warn(message IN VARCHAR2, context IN CLOB DEFAULT NULL, payload IN CLOB DEFAULT NULL) IS
    BEGIN
        write_log(c_level_warn, message, context, payload);
    END;

    PROCEDURE info(message IN VARCHAR2, context IN CLOB DEFAULT NULL, payload IN CLOB DEFAULT NULL) IS
    BEGIN
        write_log(c_level_info, message, context, payload);
    END;

    PROCEDURE debug(message IN VARCHAR2, context IN CLOB DEFAULT NULL, payload IN CLOB DEFAULT NULL) IS
    BEGIN
        write_log(c_level_debug, message, context, payload);
    END;

    ----------------------------------------------------------------------
    -- Utilities
    ----------------------------------------------------------------------
    PROCEDURE purge(p_days IN NUMBER) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        DELETE FROM otk_error_log
        WHERE log_timestamp < SYSTIMESTAMP - NUMTODSINTERVAL(p_days, 'DAY');
        COMMIT;
    END;

    FUNCTION get_recent(p_limit IN NUMBER) RETURN SYS_REFCURSOR IS
        l_rc SYS_REFCURSOR;
    BEGIN
        OPEN l_rc FOR
            SELECT *
            FROM otk_error_log
            ORDER BY log_id DESC
            FETCH FIRST p_limit ROWS ONLY;
        RETURN l_rc;
    END;

    FUNCTION search(p_keyword IN VARCHAR2) RETURN SYS_REFCURSOR IS
        l_rc SYS_REFCURSOR;
    BEGIN
        OPEN l_rc FOR
            SELECT *
            FROM otk_error_log
            WHERE message LIKE '%' || p_keyword || '%'
               OR sqlerrm_text LIKE '%' || p_keyword || '%';
        RETURN l_rc;
    END;

END otk$log;
/
