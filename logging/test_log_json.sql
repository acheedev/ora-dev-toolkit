DECLARE
    l_ctx JSON := JSON_OBJECT('module' VALUE 'test_log_json', 'action' VALUE 'run');
    l_payload JSON := JSON_OBJECT('user_id' VALUE 123, 'op' VALUE 'create');
BEGIN
    otk$log_json.set_level('DEBUG');
    otk$log_json.clear_context;

    -- context via API
    otk$log_json.context('module', 'test_log_json');
    otk$log_json.context('phase', 'startup');

    -- JSON payload
    otk$log_json.json(l_payload);
    otk$log_json.info('Starting JSON logger test');

    BEGIN
        DECLARE x NUMBER;
        BEGIN
            SELECT 1 / 0 INTO x FROM dual;
        EXCEPTION
            WHEN OTHERS THEN
                otk$log_json.json(JSON_OBJECT('detail' VALUE 'division by zero'));
                otk$log_json.error('JSON logger error test');
        END;
    END;

    DBMS_OUTPUT.put_line('Recent JSON logs:');
    FOR r IN (
        SELECT log_id, log_level, message, context_data, json_payload
        FROM otk_error_log_json
        ORDER BY log_id DESC
        FETCH FIRST 5 ROWS ONLY
    ) LOOP
        DBMS_OUTPUT.put_line(
            r.log_id || ' ' || r.log_level || ' ' || r.message
        );
    END LOOP;
END;
/
