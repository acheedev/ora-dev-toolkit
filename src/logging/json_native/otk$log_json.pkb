CREATE OR REPLACE PACKAGE BODY otk$log_json IS

    FUNCTION ctx(p_key VARCHAR2, p_value VARCHAR2) RETURN JSON IS
    BEGIN
        RETURN JSON_OBJECT(p_key VALUE p_value RETURNING JSON);
    END;

    FUNCTION ctx_merge(p_ctx1 JSON, p_ctx2 JSON) RETURN JSON IS
        l_obj1 JSON_OBJECT_T;
        l_obj2 JSON_OBJECT_T;
        l_keys JSON_KEY_LIST;
    BEGIN
        IF p_ctx1 IS NULL THEN RETURN p_ctx2; END IF;
        IF p_ctx2 IS NULL THEN RETURN p_ctx1; END IF;

        l_obj1 := JSON_OBJECT_T(p_ctx1);
        l_obj2 := JSON_OBJECT_T(p_ctx2);
        l_keys := l_obj2.get_keys;

        FOR i IN 1 .. l_keys.COUNT LOOP
            l_obj1.put(l_keys(i), l_obj2.get(l_keys(i)));
        END LOOP;

        RETURN l_obj1.to_json;
    END;

    PROCEDURE write_log(
        p_level     IN VARCHAR2,
        p_message   IN VARCHAR2,
        p_context   IN JSON,
        p_payload   IN JSON,
        p_sqlerrm   IN VARCHAR2 DEFAULT NULL,
        p_stack     IN CLOB DEFAULT NULL,
        p_backtrace IN CLOB DEFAULT NULL
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
            p_context,
            p_payload,
            p_message,
            p_sqlerrm,
            p_stack,
            p_backtrace
        );

        COMMIT;
    END;

    PROCEDURE error(message IN VARCHAR2, context IN JSON DEFAULT NULL, payload IN JSON DEFAULT NULL) IS
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

    PROCEDURE warn(message IN VARCHAR2, context IN JSON DEFAULT NULL, payload IN JSON DEFAULT NULL) IS
    BEGIN
        write_log(c_level_warn, message, context, payload);
    END;

    PROCEDURE info(message IN VARCHAR2, context IN JSON DEFAULT NULL, payload IN JSON DEFAULT NULL) IS
    BEGIN
        write_log(c_level_info, message, context, payload);
    END;

    PROCEDURE debug(message IN VARCHAR2, context IN JSON DEFAULT NULL, payload IN JSON DEFAULT NULL) IS
    BEGIN
        write_log(c_level_debug, message, context, payload);
    END;

    PROCEDURE purge(p_days IN NUMBER) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        DELETE FROM otk_error_log_json
        WHERE log_timestamp < SYSTIMESTAMP - NUMTODSINTERVAL(p_days, 'DAY');
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
            WHERE message LIKE '%' || p_keyword || '%'
               OR sqlerrm_text LIKE '%' || p_keyword || '%';
        RETURN l_rc;
    END;

END otk$log_json;
/
