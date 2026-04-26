CREATE OR REPLACE PACKAGE BODY otk$ansible IS

    ----------------------------------------------------------------------
    -- Session-level configuration globals
    ----------------------------------------------------------------------
    g_base_url        VARCHAR2(1000);
    g_bearer          VARCHAR2(4000);
    g_basic_user      VARCHAR2(256);
    g_basic_pass      VARCHAR2(256);
    g_job_timeout_sec NUMBER := 300;
    g_job_poll_sec    NUMBER := 10;


    ----------------------------------------------------------------------
    -- Private: build full API URL from path
    -- e.g. api_url('/api/v2/jobs/42/') => 'https://tower.co/api/v2/jobs/42/'
    ----------------------------------------------------------------------
    FUNCTION api_url(p_path IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN RTRIM(g_base_url, '/') || p_path;
    END api_url;


    ----------------------------------------------------------------------
    -- Private: execute a REST call with session auth
    ----------------------------------------------------------------------
    FUNCTION rest_get(p_path IN VARCHAR2) RETURN otk$rest.t_response IS
    BEGIN
        RETURN otk$rest.get(
            p_url        => api_url(p_path),
            p_bearer     => g_bearer,
            p_basic_user => g_basic_user,
            p_basic_pass => g_basic_pass
        );
    END rest_get;

    FUNCTION rest_post(p_path IN VARCHAR2, p_body IN CLOB DEFAULT NULL)
        RETURN otk$rest.t_response IS
    BEGIN
        RETURN otk$rest.post(
            p_url        => api_url(p_path),
            p_body       => p_body,
            p_bearer     => g_bearer,
            p_basic_user => g_basic_user,
            p_basic_pass => g_basic_pass
        );
    END rest_post;


    ----------------------------------------------------------------------
    -- configure
    ----------------------------------------------------------------------
    PROCEDURE configure(
        p_base_url        IN VARCHAR2,
        p_bearer          IN VARCHAR2 DEFAULT NULL,
        p_basic_user      IN VARCHAR2 DEFAULT NULL,
        p_basic_pass      IN VARCHAR2 DEFAULT NULL,
        p_job_timeout_sec IN NUMBER   DEFAULT 300,
        p_job_poll_sec    IN NUMBER   DEFAULT 10
    ) IS
    BEGIN
        g_base_url        := p_base_url;
        g_bearer          := p_bearer;
        g_basic_user      := p_basic_user;
        g_basic_pass      := p_basic_pass;
        g_job_timeout_sec := NVL(p_job_timeout_sec, 300);
        g_job_poll_sec    := NVL(p_job_poll_sec,    10);
    END configure;


    ----------------------------------------------------------------------
    -- ping
    ----------------------------------------------------------------------
    FUNCTION ping RETURN BOOLEAN IS
        l_resp otk$rest.t_response;
    BEGIN
        l_resp := rest_get('/api/v2/ping/');
        RETURN otk$rest.is_success(l_resp);
    EXCEPTION WHEN OTHERS THEN
        RETURN FALSE;
    END ping;


    ----------------------------------------------------------------------
    -- launch_job
    ----------------------------------------------------------------------
    FUNCTION launch_job(
        p_template_id IN NUMBER,
        p_extra_vars  IN CLOB     DEFAULT NULL,
        p_limit       IN VARCHAR2 DEFAULT NULL,
        p_inventory   IN NUMBER   DEFAULT NULL
    ) RETURN NUMBER IS
        l_body CLOB;
        l_resp otk$rest.t_response;
        l_job_id NUMBER;
    BEGIN
        -- Build launch payload — only include fields that were provided.
        -- JSON_OBJECT_T lets us add keys conditionally without string splicing.
        DECLARE
            l_obj JSON_OBJECT_T := JSON_OBJECT_T();
        BEGIN
            IF p_extra_vars IS NOT NULL THEN
                -- extra_vars is a nested JSON object, parse it before inserting
                l_obj.put('extra_vars', JSON_ELEMENT_T.parse(p_extra_vars));
            END IF;
            IF p_limit IS NOT NULL THEN
                l_obj.put('limit', p_limit);
            END IF;
            IF p_inventory IS NOT NULL THEN
                l_obj.put('inventory', p_inventory);
            END IF;
            l_body := l_obj.to_clob();
        END;

        l_resp := rest_post(
            '/api/v2/job_templates/' || TO_CHAR(p_template_id) || '/launch/',
            l_body
        );

        IF NOT otk$rest.is_success(l_resp) THEN
            RAISE_APPLICATION_ERROR(-20003,
                'Ansible launch failed: HTTP ' || l_resp.status_code ||
                ' ' || l_resp.status_text || CHR(10) ||
                'Response: ' || otk$clob.to_vc2(l_resp.body, 500));
        END IF;

        l_job_id := otk$json.get_num(l_resp.body, '$.job');

        IF l_job_id IS NULL THEN
            RAISE_APPLICATION_ERROR(-20003,
                'Ansible launch succeeded but no job ID in response: ' ||
                otk$clob.to_vc2(l_resp.body, 500));
        END IF;

        RETURN l_job_id;
    END launch_job;


    ----------------------------------------------------------------------
    -- get_job
    ----------------------------------------------------------------------
    FUNCTION get_job(p_job_id IN NUMBER) RETURN CLOB IS
        l_resp otk$rest.t_response;
    BEGIN
        l_resp := rest_get('/api/v2/jobs/' || TO_CHAR(p_job_id) || '/');

        IF NOT otk$rest.is_success(l_resp) THEN
            RAISE_APPLICATION_ERROR(-20003,
                'Failed to get job ' || p_job_id ||
                ': HTTP ' || l_resp.status_code);
        END IF;

        RETURN l_resp.body;
    END get_job;


    ----------------------------------------------------------------------
    -- job_status
    ----------------------------------------------------------------------
    FUNCTION job_status(p_job_id IN NUMBER) RETURN VARCHAR2 IS
    BEGIN
        RETURN otk$json.get_str(get_job(p_job_id), '$.status');
    END job_status;


    ----------------------------------------------------------------------
    -- job_complete / job_succeeded
    ----------------------------------------------------------------------
    FUNCTION job_complete(p_job_id IN NUMBER) RETURN BOOLEAN IS
        l_status VARCHAR2(20) := job_status(p_job_id);
    BEGIN
        RETURN l_status IN (
            c_status_successful,
            c_status_failed,
            c_status_error,
            c_status_canceled
        );
    END job_complete;

    FUNCTION job_succeeded(p_job_id IN NUMBER) RETURN BOOLEAN IS
    BEGIN
        RETURN job_status(p_job_id) = c_status_successful;
    END job_succeeded;


    ----------------------------------------------------------------------
    -- get_job_output
    ----------------------------------------------------------------------
    FUNCTION get_job_output(p_job_id IN NUMBER) RETURN CLOB IS
        l_resp otk$rest.t_response;
    BEGIN
        l_resp := rest_get(
            '/api/v2/jobs/' || TO_CHAR(p_job_id) || '/stdout/?format=txt'
        );

        IF NOT otk$rest.is_success(l_resp) THEN
            RAISE_APPLICATION_ERROR(-20003,
                'Failed to get output for job ' || p_job_id ||
                ': HTTP ' || l_resp.status_code);
        END IF;

        RETURN l_resp.body;
    END get_job_output;


    ----------------------------------------------------------------------
    -- wait_for_job
    ----------------------------------------------------------------------
    FUNCTION wait_for_job(
        p_job_id      IN NUMBER,
        p_timeout_sec IN NUMBER DEFAULT NULL,
        p_poll_sec    IN NUMBER DEFAULT NULL
    ) RETURN VARCHAR2 IS
        l_timeout  NUMBER  := NVL(p_timeout_sec, g_job_timeout_sec);
        l_poll     NUMBER  := NVL(p_poll_sec,    g_job_poll_sec);
        l_elapsed  NUMBER  := 0;
        l_status   VARCHAR2(20);
        l_job_body CLOB;
    BEGIN
        LOOP
            l_job_body := get_job(p_job_id);
            l_status   := otk$json.get_str(l_job_body, '$.status');

            EXIT WHEN l_status IN (
                c_status_successful,
                c_status_failed,
                c_status_error,
                c_status_canceled
            );

            IF l_elapsed >= l_timeout THEN
                RAISE_APPLICATION_ERROR(-20002,
                    'Timeout waiting for job ' || p_job_id ||
                    ' after ' || l_timeout || 's. Last status: ' || l_status);
            END IF;

            DBMS_SESSION.SLEEP(l_poll);
            l_elapsed := l_elapsed + l_poll;
        END LOOP;

        RETURN l_status;
    END wait_for_job;


    ----------------------------------------------------------------------
    -- cancel_job
    ----------------------------------------------------------------------
    PROCEDURE cancel_job(p_job_id IN NUMBER) IS
        l_resp otk$rest.t_response;
    BEGIN
        -- No-op if already in a terminal state
        IF job_complete(p_job_id) THEN RETURN; END IF;

        l_resp := rest_post(
            '/api/v2/jobs/' || TO_CHAR(p_job_id) || '/cancel/'
        );

        -- Tower returns 202 Accepted on successful cancel request,
        -- 405 Method Not Allowed if the job is already terminal
        IF l_resp.status_code NOT IN (202, 405) THEN
            RAISE_APPLICATION_ERROR(-20003,
                'Failed to cancel job ' || p_job_id ||
                ': HTTP ' || l_resp.status_code ||
                ' ' || l_resp.status_text);
        END IF;
    END cancel_job;


END otk$ansible;
/
