CREATE OR REPLACE PACKAGE BODY otk$rest IS

    ----------------------------------------------------------------------
    -- Session-level configuration globals
    ----------------------------------------------------------------------
    g_wallet_path     VARCHAR2(1000);
    g_wallet_password VARCHAR2(1000);
    g_connect_timeout NUMBER := 30;
    g_read_timeout    NUMBER := 60;

    ----------------------------------------------------------------------
    -- Exception mappings for check_connectivity diagnosis
    ----------------------------------------------------------------------
    e_acl_denied    EXCEPTION; PRAGMA EXCEPTION_INIT(e_acl_denied,    -24247);
    e_wallet_file   EXCEPTION; PRAGMA EXCEPTION_INIT(e_wallet_file,   -28759);
    e_ssl_handshake EXCEPTION; PRAGMA EXCEPTION_INIT(e_ssl_handshake, -29024);
    e_cert_verify   EXCEPTION; PRAGMA EXCEPTION_INIT(e_cert_verify,   -28860);


    ----------------------------------------------------------------------
    -- Private: Base64-encode credentials for Basic auth header
    ----------------------------------------------------------------------
    FUNCTION encode_basic(p_user IN VARCHAR2, p_pass IN VARCHAR2) RETURN VARCHAR2 IS
        l_raw RAW(32767);
    BEGIN
        l_raw := UTL_ENCODE.BASE64_ENCODE(
                     UTL_RAW.CAST_TO_RAW(p_user || ':' || p_pass)
                 );
        -- Remove MIME line breaks inserted every 64 chars
        RETURN REPLACE(REPLACE(UTL_RAW.CAST_TO_VARCHAR2(l_raw), CHR(13), ''), CHR(10), '');
    END encode_basic;


    ----------------------------------------------------------------------
    -- Private: parse JSON headers CLOB and apply each key-value to request
    ----------------------------------------------------------------------
    PROCEDURE apply_headers(p_req IN OUT NOCOPY UTL_HTTP.REQ, p_headers IN CLOB) IS
        l_obj  JSON_OBJECT_T;
        l_keys JSON_KEY_LIST;
    BEGIN
        IF p_headers IS NULL THEN RETURN; END IF;
        l_obj  := JSON_OBJECT_T.parse(p_headers);
        l_keys := l_obj.get_keys();
        FOR i IN 1 .. l_keys.COUNT LOOP
            UTL_HTTP.SET_HEADER(p_req, l_keys(i), l_obj.get_string(l_keys(i)));
        END LOOP;
    END apply_headers;


    ----------------------------------------------------------------------
    -- Private: read full response body into a CLOB
    ----------------------------------------------------------------------
    FUNCTION read_body(p_resp IN OUT NOCOPY UTL_HTTP.RESP) RETURN CLOB IS
        l_body   CLOB;
        l_buffer VARCHAR2(32767);
    BEGIN
        DBMS_LOB.CREATETEMPORARY(l_body, TRUE);
        BEGIN
            LOOP
                UTL_HTTP.READ_TEXT(p_resp, l_buffer, 32767);
                otk$clob.append(l_body, TO_CLOB(l_buffer));
            END LOOP;
        EXCEPTION
            WHEN UTL_HTTP.END_OF_BODY THEN NULL;
        END;
        RETURN l_body;
    END read_body;


    ----------------------------------------------------------------------
    -- Private: core request executor — all verb functions delegate here
    ----------------------------------------------------------------------
    FUNCTION execute_request(
        p_method       IN VARCHAR2,
        p_url          IN VARCHAR2,
        p_body         IN CLOB     DEFAULT NULL,
        p_content_type IN VARCHAR2 DEFAULT NULL,
        p_headers      IN CLOB     DEFAULT NULL,
        p_bearer       IN VARCHAR2 DEFAULT NULL,
        p_basic_user   IN VARCHAR2 DEFAULT NULL,
        p_basic_pass   IN VARCHAR2 DEFAULT NULL
    ) RETURN t_response IS
        l_req      UTL_HTTP.REQ;
        l_resp     UTL_HTTP.RESP;
        l_response t_response;
        l_resp_open BOOLEAN := FALSE;
    BEGIN
        -- Set wallet only when configured (HTTPS).
        -- NULL wallet allows plain HTTP — intended for local testing only.
        IF g_wallet_path IS NOT NULL THEN
            UTL_HTTP.SET_WALLET(g_wallet_path, g_wallet_password);
        END IF;
        UTL_HTTP.SET_TRANSFER_TIMEOUT(g_read_timeout);

        -- Open request
        l_req := UTL_HTTP.BEGIN_REQUEST(p_url, p_method, 'HTTP/1.1');
        UTL_HTTP.SET_HEADER(l_req, 'Connection', 'close');

        -- Content-Type
        IF p_content_type IS NOT NULL THEN
            UTL_HTTP.SET_HEADER(l_req, 'Content-Type', p_content_type);
        END IF;

        -- Auth — bearer takes precedence
        IF p_bearer IS NOT NULL THEN
            UTL_HTTP.SET_HEADER(l_req, 'Authorization', 'Bearer ' || p_bearer);
        ELSIF p_basic_user IS NOT NULL THEN
            UTL_HTTP.SET_HEADER(l_req, 'Authorization',
                'Basic ' || encode_basic(p_basic_user, p_basic_pass));
        END IF;

        -- Custom headers applied last so caller can override if needed
        apply_headers(l_req, p_headers);

        -- Write request body in 32767-byte chunks
        IF p_body IS NOT NULL THEN
            UTL_HTTP.SET_HEADER(l_req, 'Content-Length',
                TO_CHAR(DBMS_LOB.GETLENGTH(p_body)));
            FOR i IN 1 .. otk$clob.chunk_count(p_body) LOOP
                UTL_HTTP.WRITE_TEXT(l_req, otk$clob.chunk(p_body, i));
            END LOOP;
        END IF;

        -- Read response
        l_resp      := UTL_HTTP.GET_RESPONSE(l_req);
        l_resp_open := TRUE;

        l_response.status_code  := l_resp.status_code;
        l_response.status_text  := l_resp.reason_phrase;
        l_response.content_type := l_resp.content_type;
        l_response.body         := read_body(l_resp);

        UTL_HTTP.END_RESPONSE(l_resp);
        RETURN l_response;

    EXCEPTION WHEN OTHERS THEN
        IF l_resp_open THEN
            BEGIN UTL_HTTP.END_RESPONSE(l_resp); EXCEPTION WHEN OTHERS THEN NULL; END;
        END IF;
        RAISE;
    END execute_request;


    ----------------------------------------------------------------------
    -- configure
    ----------------------------------------------------------------------
    PROCEDURE configure(
        p_wallet_path     IN VARCHAR2,
        p_wallet_password IN VARCHAR2 DEFAULT NULL,
        p_connect_timeout IN NUMBER   DEFAULT 30,
        p_read_timeout    IN NUMBER   DEFAULT 60
    ) IS
    BEGIN
        g_wallet_path     := p_wallet_path;
        g_wallet_password := p_wallet_password;
        g_connect_timeout := p_connect_timeout;
        g_read_timeout    := p_read_timeout;
    END configure;


    ----------------------------------------------------------------------
    -- HTTP verbs
    ----------------------------------------------------------------------
    FUNCTION get(
        p_url        IN VARCHAR2,
        p_headers    IN CLOB     DEFAULT NULL,
        p_bearer     IN VARCHAR2 DEFAULT NULL,
        p_basic_user IN VARCHAR2 DEFAULT NULL,
        p_basic_pass IN VARCHAR2 DEFAULT NULL
    ) RETURN t_response IS
    BEGIN
        RETURN execute_request('GET', p_url,
            p_headers => p_headers, p_bearer => p_bearer,
            p_basic_user => p_basic_user, p_basic_pass => p_basic_pass);
    END get;

    FUNCTION post(
        p_url          IN VARCHAR2,
        p_body         IN CLOB     DEFAULT NULL,
        p_content_type IN VARCHAR2 DEFAULT 'application/json',
        p_headers      IN CLOB     DEFAULT NULL,
        p_bearer       IN VARCHAR2 DEFAULT NULL,
        p_basic_user   IN VARCHAR2 DEFAULT NULL,
        p_basic_pass   IN VARCHAR2 DEFAULT NULL
    ) RETURN t_response IS
    BEGIN
        RETURN execute_request('POST', p_url, p_body, p_content_type,
            p_headers, p_bearer, p_basic_user, p_basic_pass);
    END post;

    FUNCTION put(
        p_url          IN VARCHAR2,
        p_body         IN CLOB     DEFAULT NULL,
        p_content_type IN VARCHAR2 DEFAULT 'application/json',
        p_headers      IN CLOB     DEFAULT NULL,
        p_bearer       IN VARCHAR2 DEFAULT NULL,
        p_basic_user   IN VARCHAR2 DEFAULT NULL,
        p_basic_pass   IN VARCHAR2 DEFAULT NULL
    ) RETURN t_response IS
    BEGIN
        RETURN execute_request('PUT', p_url, p_body, p_content_type,
            p_headers, p_bearer, p_basic_user, p_basic_pass);
    END put;

    FUNCTION patch(
        p_url          IN VARCHAR2,
        p_body         IN CLOB     DEFAULT NULL,
        p_content_type IN VARCHAR2 DEFAULT 'application/json',
        p_headers      IN CLOB     DEFAULT NULL,
        p_bearer       IN VARCHAR2 DEFAULT NULL,
        p_basic_user   IN VARCHAR2 DEFAULT NULL,
        p_basic_pass   IN VARCHAR2 DEFAULT NULL
    ) RETURN t_response IS
    BEGIN
        RETURN execute_request('PATCH', p_url, p_body, p_content_type,
            p_headers, p_bearer, p_basic_user, p_basic_pass);
    END patch;

    FUNCTION del(
        p_url        IN VARCHAR2,
        p_headers    IN CLOB     DEFAULT NULL,
        p_bearer     IN VARCHAR2 DEFAULT NULL,
        p_basic_user IN VARCHAR2 DEFAULT NULL,
        p_basic_pass IN VARCHAR2 DEFAULT NULL
    ) RETURN t_response IS
    BEGIN
        RETURN execute_request('DELETE', p_url,
            p_headers => p_headers, p_bearer => p_bearer,
            p_basic_user => p_basic_user, p_basic_pass => p_basic_pass);
    END del;


    ----------------------------------------------------------------------
    -- Response helpers
    ----------------------------------------------------------------------
    FUNCTION is_success(p_response IN t_response) RETURN BOOLEAN IS
    BEGIN
        RETURN p_response.status_code BETWEEN 200 AND 299;
    END is_success;

    FUNCTION is_error(p_response IN t_response) RETURN BOOLEAN IS
    BEGIN
        RETURN p_response.status_code BETWEEN 400 AND 599;
    END is_error;


    ----------------------------------------------------------------------
    -- check_connectivity
    ----------------------------------------------------------------------
    PROCEDURE check_connectivity(
        p_url     IN  VARCHAR2,
        p_success OUT BOOLEAN,
        p_report  OUT CLOB
    ) IS
        l_response t_response;
        l_host     VARCHAR2(1000);

        PROCEDURE line(p_text IN VARCHAR2) IS
        BEGIN
            otk$clob.append(p_report, TO_CLOB(p_text || CHR(10)));
        END line;

    BEGIN
        DBMS_LOB.CREATETEMPORARY(p_report, TRUE);
        line('otk$rest connectivity check');
        line('URL : ' || p_url);
        line(RPAD('-', 60, '-'));

        -- 1. Wallet / protocol check
        IF g_wallet_path IS NULL THEN
            IF LOWER(SUBSTR(p_url, 1, 5)) = 'http:' THEN
                line('WARN  No wallet configured — HTTP only (not for production use)');
            ELSE
                line('FAIL  Wallet not configured — required for HTTPS');
                line('      Call otk$rest.configure() with p_wallet_path');
                p_success := FALSE;
                RETURN;
            END IF;
        ELSE
            line('OK    Wallet path : ' || g_wallet_path);
        END IF;

        -- 2. Extract host for reporting
        l_host := REGEXP_SUBSTR(p_url, '//([^/:]+)', 1, 1, NULL, 1);
        line('OK    Target host : ' || l_host);
        line('      Attempting connection...');

        -- 3. Attempt GET — categorise errors by Oracle error code
        BEGIN
            l_response := get(p_url);
            line('OK    HTTP ' || l_response.status_code || ' ' || l_response.status_text);
            p_success := TRUE;

        EXCEPTION
            WHEN e_acl_denied THEN
                line('FAIL  Network ACL denied (ORA-24247)');
                line('      Ask your DBA to run:');
                line('      @src/rest/setup/setup_acl.sql ' ||
                     SYS_CONTEXT('USERENV','SESSION_USER') || ' ' || l_host || ' 443');
                p_success := FALSE;

            WHEN e_wallet_file THEN
                line('FAIL  Wallet file not found (ORA-28759)');
                line('      Wallet path    : ' || g_wallet_path);
                line('      Run setup      : src/rest/setup/setup_wallet.sh');
                p_success := FALSE;

            WHEN e_cert_verify THEN
                line('FAIL  Server certificate not trusted (ORA-28860)');
                line('      The server''s CA cert is not in the wallet');
                line('      Run setup      : src/rest/setup/setup_wallet.sh');
                p_success := FALSE;

            WHEN e_ssl_handshake THEN
                line('FAIL  SSL handshake failed (ORA-29024)');
                line('      Certificate may be expired or the wrong CA cert is imported');
                p_success := FALSE;

            WHEN OTHERS THEN
                line('FAIL  Unexpected error: ' || SQLERRM);
                p_success := FALSE;
        END;

        line(RPAD('-', 60, '-'));
        line(CASE p_success WHEN TRUE THEN 'RESULT: OK' ELSE 'RESULT: FAILED' END);

    END check_connectivity;


END otk$rest;
/
