-- =============================================================================
-- otk$ansible test suite
-- Requires: mock server running on 127.0.0.1:8765
--           See tests/mock_server/README.md
--
-- Template IDs used:
--   1   -> job completes successfully  (after 2 polls)
--   2   -> job fails                   (after 2 polls)
--   3   -> job errors                  (after 2 polls)
--   999 -> job never completes         (cancel test)
-- =============================================================================

SET SERVEROUTPUT ON
DECLARE
    l_pass PLS_INTEGER := 0;
    l_fail PLS_INTEGER := 0;

    c_base CONSTANT VARCHAR2(100) := 'http://127.0.0.1:8765';

    l_job_id NUMBER;
    l_status VARCHAR2(20);
    l_clob   CLOB;
    l_resp   otk$rest.t_response;
    l_running_job_id NUMBER;

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
    DBMS_OUTPUT.put_line('=== TEST: otk$ansible (mock server) ===');
    DBMS_OUTPUT.put_line('');

    -- Configure modules
    otk$rest.configure(p_wallet_path => NULL, p_read_timeout => 10);

    otk$ansible.configure(
        p_base_url        => c_base,
        p_bearer          => 'mock_test_token',
        p_job_timeout_sec => 30,
        p_job_poll_sec    => 1    -- fast polling for tests
    );

    -- Reset mock server state for a clean run
    l_resp := otk$rest.post(c_base || '/admin/reset');
    ok('admin reset: mock state cleared', l_resp.status_code = 200);

    --------------------------------------------------------------------------
    -- ping
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- ping ---');

    ok('ping: Tower reachable', otk$ansible.ping = TRUE);

    --------------------------------------------------------------------------
    -- launch_job — template 1 (successful)
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- launch_job (template 1 -> successful) ---');

    l_job_id := otk$ansible.launch_job(
        p_template_id => 1,
        p_extra_vars  => '{"env":"test","dry_run":true}'
    );

    ok('launch_job: returns numeric ID',  l_job_id > 0);
    DBMS_OUTPUT.put_line('      Job ID: ' || l_job_id);

    --------------------------------------------------------------------------
    -- job_status — initial state should be running
    --------------------------------------------------------------------------
    l_status := otk$ansible.job_status(l_job_id);
    ok('job_status: initial state is running-type',
        l_status IN ('new','pending','waiting','running'));

    l_running_job_id := otk$ansible.launch_job(p_template_id => 999);
    ok('job_complete: FALSE while running',  otk$ansible.job_complete(l_running_job_id)  = FALSE);
    ok('job_succeeded: FALSE while running', otk$ansible.job_succeeded(l_running_job_id) = FALSE);

    --------------------------------------------------------------------------
    -- wait_for_job — polls until successful
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- wait_for_job ---');

    l_status := otk$ansible.wait_for_job(l_job_id);

    ok('wait_for_job: returns terminal status',
        l_status IN ('successful','failed','error','canceled'));
    ok('wait_for_job: template 1 is successful',
        l_status = otk$ansible.c_status_successful);
    ok('job_complete: TRUE after terminal',   otk$ansible.job_complete(l_job_id)  = TRUE);
    ok('job_succeeded: TRUE after successful',otk$ansible.job_succeeded(l_job_id) = TRUE);

    --------------------------------------------------------------------------
    -- get_job — full JSON response
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- get_job ---');

    l_clob := otk$ansible.get_job(l_job_id);

    ok('get_job: returns non-empty CLOB',      NOT otk$clob.is_empty(l_clob));
    ok('get_job: id field matches',            otk$json.get_num(l_clob, '$.id') = l_job_id);
    ok('get_job: status field present',        otk$json.path_exists(l_clob, '$.status') = TRUE);
    ok('get_job: status is successful',        otk$json.get_str(l_clob, '$.status') = 'successful');
    ok('get_job: elapsed field populated',     otk$json.get_num(l_clob, '$.elapsed') IS NOT NULL);
    ok('get_job: finished field populated',    otk$json.path_exists(l_clob, '$.finished') = TRUE);

    --------------------------------------------------------------------------
    -- get_job_output — playbook stdout
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- get_job_output ---');

    l_clob := otk$ansible.get_job_output(l_job_id);

    ok('get_job_output: non-empty',            NOT otk$clob.is_empty(l_clob));
    ok('get_job_output: contains PLAY',        otk$clob.contains(l_clob, 'PLAY') = TRUE);
    ok('get_job_output: contains PLAY RECAP',  otk$clob.contains(l_clob, 'PLAY RECAP') = TRUE);
    ok('get_job_output: multiple lines',       otk$clob.line_count(l_clob) > 3);

    --------------------------------------------------------------------------
    -- launch_job with limit and extra_vars
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- launch_job with options ---');

    l_job_id := otk$ansible.launch_job(
        p_template_id => 1,
        p_extra_vars  => '{"version":"2.1.0","region":"us-east-1"}',
        p_limit       => 'web_servers'
    );
    ok('launch_job with limit: returns ID', l_job_id > 0);
    l_status := otk$ansible.wait_for_job(l_job_id);
    ok('launch_job with limit: completes', l_status = 'successful');

    --------------------------------------------------------------------------
    -- Failed job — template 2
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- Failed job (template 2) ---');

    l_job_id := otk$ansible.launch_job(p_template_id => 2);
    ok('launch template 2: returns ID', l_job_id > 0);

    l_status := otk$ansible.wait_for_job(l_job_id);
    ok('failed job: status = failed',       l_status = otk$ansible.c_status_failed);
    ok('failed job: job_complete TRUE',     otk$ansible.job_complete(l_job_id)  = TRUE);
    ok('failed job: job_succeeded FALSE',   otk$ansible.job_succeeded(l_job_id) = FALSE);

    --------------------------------------------------------------------------
    -- Error job — template 3
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- Error job (template 3) ---');

    l_job_id := otk$ansible.launch_job(p_template_id => 3);
    l_status  := otk$ansible.wait_for_job(l_job_id);
    ok('error job: status = error',       l_status = otk$ansible.c_status_error);
    ok('error job: job_complete TRUE',    otk$ansible.job_complete(l_job_id) = TRUE);
    ok('error job: job_succeeded FALSE',  otk$ansible.job_succeeded(l_job_id) = FALSE);

    --------------------------------------------------------------------------
    -- Invalid template — expect ORA-20003
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- Invalid template (expect error) ---');

    BEGIN
        l_job_id := otk$ansible.launch_job(p_template_id => 42);
        ok('invalid template: ORA-20003 raised', FALSE);
    EXCEPTION WHEN OTHERS THEN
        ok('invalid template: ORA-20003 raised', SQLCODE = -20003);
    END;

    --------------------------------------------------------------------------
    -- Cancel job — template 999 (never completes naturally)
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- cancel_job (template 999) ---');

    l_job_id := otk$ansible.launch_job(p_template_id => 999);
    ok('cancel test: job launched', l_job_id > 0);

    -- Confirm it is running
    l_status := otk$ansible.job_status(l_job_id);
    ok('cancel test: initially running', l_status = 'running');

    -- Cancel it
    BEGIN
        otk$ansible.cancel_job(l_job_id);
        ok('cancel_job: no exception raised', TRUE);
    EXCEPTION WHEN OTHERS THEN
        ok('cancel_job: no exception raised', FALSE);
    END;

    -- Confirm it is now canceled
    l_status := otk$ansible.job_status(l_job_id);
    ok('cancel_job: status is canceled',  l_status = otk$ansible.c_status_canceled);
    ok('cancel_job: job_complete TRUE',   otk$ansible.job_complete(l_job_id) = TRUE);

    -- Cancel again — should no-op silently (job already terminal)
    BEGIN
        otk$ansible.cancel_job(l_job_id);
        ok('cancel already-terminal: no exception', TRUE);
    EXCEPTION WHEN OTHERS THEN
        ok('cancel already-terminal: no exception', FALSE);
    END;

    --------------------------------------------------------------------------
    -- wait_for_job timeout — template 999 with short timeout
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- wait_for_job timeout ---');

    -- Reset mock so template 999 is fresh (forced_status is cleared)
    l_resp   := otk$rest.post(c_base || '/admin/reset');
    l_job_id := otk$ansible.launch_job(p_template_id => 999);

    BEGIN
        l_status := otk$ansible.wait_for_job(
            p_job_id      => l_job_id,
            p_timeout_sec => 3,   -- shorter than it would ever complete
            p_poll_sec    => 1
        );
        ok('timeout: ORA-20002 raised', FALSE);
    EXCEPTION WHEN OTHERS THEN
        ok('timeout: ORA-20002 raised', SQLCODE = -20002);
    END;

    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- ' || l_pass || ' passed, ' || l_fail || ' failed ---');

END;
/
