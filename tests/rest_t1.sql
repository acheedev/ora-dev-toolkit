-- =============================================================================
-- otk$rest test suite
-- Requires: mock server running on 127.0.0.1:8765
--           See tests/mock_server/README.md
-- =============================================================================

SET SERVEROUTPUT ON
DECLARE
    l_pass PLS_INTEGER := 0;
    l_fail PLS_INTEGER := 0;
    l_resp otk$rest.t_response;
    l_ok   BOOLEAN;
    l_rep  CLOB;

    c_base CONSTANT VARCHAR2(100) := 'http://127.0.0.1:8765';

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
    DBMS_OUTPUT.put_line('=== TEST: otk$rest (mock server) ===');
    DBMS_OUTPUT.put_line('');

    -- Configure for HTTP — no wallet needed for localhost mock
    otk$rest.configure(
        p_wallet_path => NULL,
        p_read_timeout => 10
    );

    --------------------------------------------------------------------------
    -- check_connectivity
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('--- check_connectivity ---');

    otk$rest.check_connectivity(
        p_url     => c_base || '/get',
        p_success => l_ok,
        p_report  => l_rep
    );
    ok('check_connectivity: mock server reachable', l_ok = TRUE);
    ok('check_connectivity: report contains OK',
        otk$clob.contains(l_rep, 'RESULT: OK') = TRUE);
    ok('check_connectivity: WARN for HTTP noted',
        otk$clob.contains(l_rep, 'WARN') = TRUE);

    --------------------------------------------------------------------------
    -- GET
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- GET ---');

    l_resp := otk$rest.get(c_base || '/get');
    ok('GET: 200 status',             l_resp.status_code = 200);
    ok('GET: is_success',             otk$rest.is_success(l_resp) = TRUE);
    ok('GET: is_error FALSE',         otk$rest.is_error(l_resp)   = FALSE);
    ok('GET: method echoed',          otk$json.get_str(l_resp.body, '$.method') = 'GET');
    ok('GET: body non-empty',         NOT otk$clob.is_empty(l_resp.body));

    --------------------------------------------------------------------------
    -- GET with custom headers
    --------------------------------------------------------------------------
    l_resp := otk$rest.get(
        p_url     => c_base || '/headers',
        p_headers => '{"X-Otk-Test":"mock_header_value","X-Correlation-Id":"abc123"}'
    );
    ok('GET headers: X-Otk-Test echoed',
        otk$json.get_str(l_resp.body, '$.headers."X-Otk-Test"') = 'mock_header_value');
    ok('GET headers: X-Correlation-Id echoed',
        otk$json.get_str(l_resp.body, '$.headers."X-Correlation-Id"') = 'abc123');

    --------------------------------------------------------------------------
    -- GET with Bearer auth
    --------------------------------------------------------------------------
    l_resp := otk$rest.get(
        p_url    => c_base || '/bearer',
        p_bearer => 'my_test_token'
    );
    ok('GET bearer: 200 with valid token',   l_resp.status_code = 200);
    ok('GET bearer: authenticated true',
        otk$json.get_bool_yn(l_resp.body, '$.authenticated') = 'Y');
    ok('GET bearer: token echoed back',
        otk$json.get_str(l_resp.body, '$.token') = 'my_test_token');

    l_resp := otk$rest.get(c_base || '/bearer');   -- no token
    ok('GET bearer: 401 without token', l_resp.status_code = 401);
    ok('GET bearer: is_error TRUE',     otk$rest.is_error(l_resp) = TRUE);

    --------------------------------------------------------------------------
    -- GET with Basic auth
    --------------------------------------------------------------------------
    l_resp := otk$rest.get(
        p_url        => c_base || '/basic-auth/alice/secret99',
        p_basic_user => 'alice',
        p_basic_pass => 'secret99'
    );
    ok('GET basic auth: 200 correct creds',
        l_resp.status_code = 200);
    ok('GET basic auth: user echoed',
        otk$json.get_str(l_resp.body, '$.user') = 'alice');

    l_resp := otk$rest.get(
        p_url        => c_base || '/basic-auth/alice/secret99',
        p_basic_user => 'alice',
        p_basic_pass => 'wrongpass'
    );
    ok('GET basic auth: 401 wrong password', l_resp.status_code = 401);

    --------------------------------------------------------------------------
    -- POST
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- POST ---');

    l_resp := otk$rest.post(
        p_url  => c_base || '/post',
        p_body => TO_CLOB('{"order_id":1001,"status":"PENDING"}')
    );
    ok('POST: 200 status',         l_resp.status_code = 200);
    ok('POST: method echoed',      otk$json.get_str(l_resp.body, '$.method') = 'POST');
    ok('POST: body key echoed',
        otk$json.get_num(l_resp.body, '$.json.order_id') = 1001);
    ok('POST: content-type sent',
        otk$clob.contains(l_resp.body, 'application/json') = TRUE);

    --------------------------------------------------------------------------
    -- PUT
    --------------------------------------------------------------------------
    l_resp := otk$rest.put(
        p_url  => c_base || '/put',
        p_body => TO_CLOB('{"updated":true}')
    );
    ok('PUT: 200 status',     l_resp.status_code = 200);
    ok('PUT: method echoed',  otk$json.get_str(l_resp.body, '$.method') = 'PUT');

    --------------------------------------------------------------------------
    -- PATCH
    --------------------------------------------------------------------------
    l_resp := otk$rest.patch(
        p_url  => c_base || '/patch',
        p_body => TO_CLOB('{"patched":true}')
    );
    ok('PATCH: 200 status',    l_resp.status_code = 200);
    ok('PATCH: method echoed', otk$json.get_str(l_resp.body, '$.method') = 'PATCH');

    --------------------------------------------------------------------------
    -- DEL
    --------------------------------------------------------------------------
    l_resp := otk$rest.del(c_base || '/delete');
    ok('DEL: 200 status',    l_resp.status_code = 200);
    ok('DEL: method echoed', otk$json.get_str(l_resp.body, '$.method') = 'DELETE');

    --------------------------------------------------------------------------
    -- Status code responses
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- Status codes ---');

    l_resp := otk$rest.get(c_base || '/status/201');
    ok('status/201: correct code',    l_resp.status_code = 201);
    ok('status/201: is_success',      otk$rest.is_success(l_resp) = TRUE);

    l_resp := otk$rest.get(c_base || '/status/400');
    ok('status/400: correct code',    l_resp.status_code = 400);
    ok('status/400: is_error',        otk$rest.is_error(l_resp) = TRUE);

    l_resp := otk$rest.get(c_base || '/status/404');
    ok('status/404: correct code',    l_resp.status_code = 404);
    ok('status/404: is_error',        otk$rest.is_error(l_resp) = TRUE);
    ok('status/404: is_success FALSE',otk$rest.is_success(l_resp) = FALSE);

    l_resp := otk$rest.get(c_base || '/status/500');
    ok('status/500: correct code',    l_resp.status_code = 500);
    ok('status/500: is_error',        otk$rest.is_error(l_resp) = TRUE);

    l_resp := otk$rest.get(c_base || '/status/503');
    ok('status/503: correct code',    l_resp.status_code = 503);
    ok('status/503: is_error',        otk$rest.is_error(l_resp) = TRUE);

    --------------------------------------------------------------------------
    -- Read timeout (configure a 2-second timeout, hit /slow/5)
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- Read timeout ---');

    otk$rest.configure(p_wallet_path => NULL, p_read_timeout => 2);

    BEGIN
        l_resp := otk$rest.get(c_base || '/slow/5');
        ok('read timeout: exception raised', FALSE);   -- should not reach here
    EXCEPTION WHEN OTHERS THEN
        ok('read timeout: exception raised on slow response', TRUE);
    END;

    -- Restore normal timeout for remaining tests
    otk$rest.configure(p_wallet_path => NULL, p_read_timeout => 10);

    --------------------------------------------------------------------------
    -- is_success / is_error boundary checks
    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- Response helper boundaries ---');

    DECLARE l_r otk$rest.t_response; BEGIN
        l_r.status_code := 200; ok('is_success 200', otk$rest.is_success(l_r) = TRUE);
        l_r.status_code := 299; ok('is_success 299', otk$rest.is_success(l_r) = TRUE);
        l_r.status_code := 300; ok('is_success 300', otk$rest.is_success(l_r) = FALSE);
        l_r.status_code := 399; ok('is_error   399', otk$rest.is_error(l_r)   = FALSE);
        l_r.status_code := 400; ok('is_error   400', otk$rest.is_error(l_r)   = TRUE);
        l_r.status_code := 599; ok('is_error   599', otk$rest.is_error(l_r)   = TRUE);
        l_r.status_code := 600; ok('is_error   600', otk$rest.is_error(l_r)   = FALSE);
    END;

    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- ' || l_pass || ' passed, ' || l_fail || ' failed ---');

END;
/
