BEGIN
    otk$log.set_level('DEBUG');
    otk$log.clear_context;

    otk$log.context('module', 'test_log');
    otk$log.context('action', 'startup');

    otk$log.info('Starting test');
    otk$log.debug('Debug message here');
    otk$log.warn('This is a warning');

    BEGIN
        DECLARE x NUMBER;
        BEGIN
            SELECT 1 / 0 INTO x FROM dual;
        EXCEPTION
            WHEN OTHERS THEN
                otk$log.error('Division by zero occurred');
        END;
    END;

    DBMS_OUTPUT.put_line('Recent logs:');
    FOR r IN (SELECT * FROM otk_error_log ORDER BY log_id DESC FETCH FIRST 5 ROWS ONLY) LOOP
        DBMS_OUTPUT.put_line(r.log_level || ': ' || r.message);
    END LOOP;
END;
/

-- -- Quick JSON usage examples
-- BEGIN
--     some_api_call(l_request_json, l_response_json);
-- EXCEPTION
--     WHEN OTHERS THEN
--         otk$log.json(l_response_json);
--         otk$log.error('API call failed');
--         RAISE;
-- END;
-- /

-- --Attach JSON to an info/debug event
-- BEGIN
--     otk$log.json(l_payload_json);
--     otk$log.info('Ansible Tower job submitted');
-- END;
-- /
