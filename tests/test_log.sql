SET SERVEROUTPUT ON
DECLARE
    l_pass       PLS_INTEGER := 0;
    l_fail       PLS_INTEGER := 0;
    l_count      NUMBER;
    l_test_start TIMESTAMP := SYSTIMESTAMP;
    l_rc         SYS_REFCURSOR;
    l_row        otk_error_log%ROWTYPE;

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
    DBMS_OUTPUT.put_line('=== TEST: otk$log (CLOB engine) ===');
    DBMS_OUTPUT.put_line('');

    --------------------------------------------------------------------------
    -- ctx / ctx_merge
    --------------------------------------------------------------------------
    DECLARE
        l_ctx1 CLOB;
        l_ctx2 CLOB;
        l_ctx  CLOB;
    BEGIN
        l_ctx1 := otk$log.ctx('module', 'test_log');
        l_ctx2 := otk$log.ctx('phase', 'init');
        l_ctx  := otk$log.ctx_merge(l_ctx1, l_ctx2);

        ok('ctx: returns non-null JSON',         l_ctx1 IS NOT NULL);
        ok('ctx: key appears in output',          INSTR(l_ctx1, 'module') > 0);
        ok('ctx: value appears in output',        INSTR(l_ctx1, 'test_log') > 0);
        ok('ctx_merge: both keys present',        INSTR(l_ctx, 'module') > 0 AND INSTR(l_ctx, 'phase') > 0);
        ok('ctx_merge: NULL left returns right',  otk$log.ctx_merge(NULL, l_ctx2) = l_ctx2);
        ok('ctx_merge: NULL right returns left',  otk$log.ctx_merge(l_ctx1, NULL) = l_ctx1);
        ok('ctx_merge: both NULL returns NULL',   otk$log.ctx_merge(NULL, NULL) IS NULL);
    END;

    --------------------------------------------------------------------------
    -- INFO
    --------------------------------------------------------------------------
    otk$log.info(
        message => 'otk_test_info_marker',
        context => otk$log.ctx('test', 'info')
    );

    SELECT COUNT(*) INTO l_count
    FROM otk_error_log
    WHERE log_level = 'INFO'
    AND   message   = 'otk_test_info_marker'
    AND   log_timestamp >= l_test_start;

    ok('info: row written to table', l_count = 1);

    --------------------------------------------------------------------------
    -- DEBUG
    --------------------------------------------------------------------------
    otk$log.debug(message => 'otk_test_debug_marker');

    SELECT COUNT(*) INTO l_count
    FROM otk_error_log
    WHERE log_level = 'DEBUG'
    AND   message   = 'otk_test_debug_marker'
    AND   log_timestamp >= l_test_start;

    ok('debug: row written to table', l_count = 1);

    --------------------------------------------------------------------------
    -- WARN
    --------------------------------------------------------------------------
    otk$log.warn(message => 'otk_test_warn_marker');

    SELECT COUNT(*) INTO l_count
    FROM otk_error_log
    WHERE log_level = 'WARN'
    AND   message   = 'otk_test_warn_marker'
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
                otk$log.error(
                    message => 'otk_test_error_marker',
                    context => otk$log.ctx('operation', 'division')
                );
        END;
    END;

    SELECT COUNT(*) INTO l_count
    FROM otk_error_log
    WHERE log_level    = 'ERROR'
    AND   message      = 'otk_test_error_marker'
    AND   sqlerrm_text IS NOT NULL
    AND   log_timestamp >= l_test_start;

    ok('error: row written with SQLERRM', l_count = 1);

    --------------------------------------------------------------------------
    -- created_by populated by trigger
    --------------------------------------------------------------------------
    SELECT COUNT(*) INTO l_count
    FROM otk_error_log
    WHERE message = 'otk_test_info_marker'
    AND   created_by IS NOT NULL
    AND   log_timestamp >= l_test_start;

    ok('trigger: created_by populated', l_count = 1);

    --------------------------------------------------------------------------
    -- get_recent
    --------------------------------------------------------------------------
    l_rc := otk$log.get_recent(5);
    FETCH l_rc INTO l_row;
    ok('get_recent: returns at least one row', l_rc%FOUND OR l_row.log_id IS NOT NULL);
    CLOSE l_rc;

    --------------------------------------------------------------------------
    -- search
    --------------------------------------------------------------------------
    l_rc := otk$log.search('otk_test_warn_marker');
    FETCH l_rc INTO l_row;
    ok('search: finds matching message', l_row.message = 'otk_test_warn_marker');
    CLOSE l_rc;

    --------------------------------------------------------------------------
    -- purge
    --------------------------------------------------------------------------
    SELECT COUNT(*) INTO l_count
    FROM otk_error_log
    WHERE log_timestamp >= l_test_start;

    otk$log.purge(0);   -- purge everything older than now

    SELECT COUNT(*) INTO l_count
    FROM otk_error_log
    WHERE log_timestamp < l_test_start;

    ok('purge: pre-test rows removed', l_count = 0);

    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- ' || l_pass || ' passed, ' || l_fail || ' failed ---');

END;
/
