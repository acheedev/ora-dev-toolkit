SET SERVEROUTPUT ON
DECLARE
    l_pass       PLS_INTEGER := 0;
    l_fail       PLS_INTEGER := 0;
    l_count      NUMBER;
    l_test_start TIMESTAMP := SYSTIMESTAMP;
    l_rc         SYS_REFCURSOR;
    l_row        otk_error_log_json%ROWTYPE;

    PROCEDURE ok(p_label VARCHAR2, p_cond BOOLEAN) IS
    BEGIN
        IF p_cond THEN
            DBMS_OUTPUT.put_line('  PASS  ' || p_label);
            l_pass := l_pass + 1;
        ELSE
            DBMS_OUTPUT.put_line('  FAIL  ' || p_label);
            l_fail := l_fail + 1;
        END IF;
    END ok;

BEGIN
    DBMS_OUTPUT.put_line('=== TEST: otk$log_json (JSON-native engine) ===');
    DBMS_OUTPUT.put_line('');

    --------------------------------------------------------------------------
    -- ctx / ctx_merge
    --------------------------------------------------------------------------
    DECLARE
        l_ctx1 JSON;
        l_ctx2 JSON;
        l_ctx  JSON;
    BEGIN
        l_ctx1 := otk$log_json.ctx('module', 'test_log_json');
        l_ctx2 := otk$log_json.ctx('phase', 'init');
        l_ctx  := otk$log_json.ctx_merge(l_ctx1, l_ctx2);

        ok('ctx: returns non-null JSON',       l_ctx1 IS NOT NULL);
        ok('ctx_merge: merged result non-null', l_ctx IS NOT NULL);
        ok('ctx_merge: NULL left returns right', otk$log_json.ctx_merge(NULL, l_ctx2) IS NOT NULL);
        ok('ctx_merge: NULL right returns left', otk$log_json.ctx_merge(l_ctx1, NULL) IS NOT NULL);
    END;

    --------------------------------------------------------------------------
    -- INFO
    --------------------------------------------------------------------------
    otk$log_json.info(
        message => 'otk_json_test_info_marker',
        context => otk$log_json.ctx('test', 'info')
    );

    SELECT COUNT(*) INTO l_count
    FROM otk_error_log_json
    WHERE log_level = 'INFO'
    AND   message   = 'otk_json_test_info_marker'
    AND   log_timestamp >= l_test_start;

    ok('info: row written to table', l_count = 1);

    --------------------------------------------------------------------------
    -- DEBUG
    --------------------------------------------------------------------------
    otk$log_json.debug(message => 'otk_json_test_debug_marker');

    SELECT COUNT(*) INTO l_count
    FROM otk_error_log_json
    WHERE log_level = 'DEBUG'
    AND   message   = 'otk_json_test_debug_marker'
    AND   log_timestamp >= l_test_start;

    ok('debug: row written to table', l_count = 1);

    --------------------------------------------------------------------------
    -- WARN
    --------------------------------------------------------------------------
    otk$log_json.warn(message => 'otk_json_test_warn_marker');

    SELECT COUNT(*) INTO l_count
    FROM otk_error_log_json
    WHERE log_level = 'WARN'
    AND   message   = 'otk_json_test_warn_marker'
    AND   log_timestamp >= l_test_start;

    ok('warn: row written to table', l_count = 1);

    --------------------------------------------------------------------------
    -- ERROR (captures SQLERRM, stack, backtrace)
    --------------------------------------------------------------------------
    BEGIN
        DECLARE x NUMBER;
        BEGIN
            SELECT 1 / 0 INTO x FROM dual;
        EXCEPTION
            WHEN OTHERS THEN
                otk$log_json.error(
                    message => 'otk_json_test_error_marker',
                    context => otk$log_json.ctx('operation', 'division')
                );
        END;
    END;

    SELECT COUNT(*) INTO l_count
    FROM otk_error_log_json
    WHERE log_level    = 'ERROR'
    AND   message      = 'otk_json_test_error_marker'
    AND   sqlerrm_text IS NOT NULL
    AND   log_timestamp >= l_test_start;

    ok('error: row written with SQLERRM', l_count = 1);

    --------------------------------------------------------------------------
    -- created_by populated by trigger
    --------------------------------------------------------------------------
    SELECT COUNT(*) INTO l_count
    FROM otk_error_log_json
    WHERE message    = 'otk_json_test_info_marker'
    AND   created_by IS NOT NULL
    AND   log_timestamp >= l_test_start;

    ok('trigger: created_by populated', l_count = 1);

    --------------------------------------------------------------------------
    -- get_recent
    --------------------------------------------------------------------------
    l_rc := otk$log_json.get_recent(5);
    FETCH l_rc INTO l_row;
    ok('get_recent: returns at least one row', l_rc%FOUND OR l_row.log_id IS NOT NULL);
    CLOSE l_rc;

    --------------------------------------------------------------------------
    -- search
    --------------------------------------------------------------------------
    l_rc := otk$log_json.search('otk_json_test_warn_marker');
    FETCH l_rc INTO l_row;
    ok('search: finds matching message', l_row.message = 'otk_json_test_warn_marker');
    CLOSE l_rc;

    --------------------------------------------------------------------------
    -- purge
    --------------------------------------------------------------------------
    otk$log_json.purge(0);

    SELECT COUNT(*) INTO l_count
    FROM otk_error_log_json
    WHERE log_timestamp < l_test_start;

    ok('purge: pre-test rows removed', l_count = 0);

    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- ' || l_pass || ' passed, ' || l_fail || ' failed ---');

END;
/
