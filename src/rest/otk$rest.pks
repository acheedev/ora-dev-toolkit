CREATE OR REPLACE PACKAGE otk$rest IS

    ----------------------------------------------------------------------
    -- Requires Oracle 19c or later.
    -- Depends on: otk$clob (request body chunking, response assembly)
    -- Assumes HTTPS for all connections. configure() must be called
    -- before any HTTP verb to supply the wallet path.
    ----------------------------------------------------------------------

    ----------------------------------------------------------------------
    -- Response record returned by all verb functions
    ----------------------------------------------------------------------
    TYPE t_response IS RECORD (
        status_code  PLS_INTEGER,
        status_text  VARCHAR2(256),
        content_type VARCHAR2(256),
        body         CLOB
    );

    ----------------------------------------------------------------------
    -- Session configuration
    -- Call once before making any requests (e.g. in a package initialiser
    -- or at the top of a procedure).
    --
    -- p_wallet_path     : Oracle wallet directory in file: URI format
    --                     e.g. 'file:/opt/oracle/wallets/rest'
    -- p_wallet_password : Omit for auto-login wallets (cwallet.sso)
    -- p_connect_timeout : Seconds before connection attempt is abandoned
    -- p_read_timeout    : Seconds before a stalled read is abandoned
    ----------------------------------------------------------------------
    PROCEDURE configure(
        p_wallet_path     IN VARCHAR2,
        p_wallet_password IN VARCHAR2 DEFAULT NULL,
        p_connect_timeout IN NUMBER   DEFAULT 30,
        p_read_timeout    IN NUMBER   DEFAULT 60
    );

    ----------------------------------------------------------------------
    -- HTTP verbs
    --
    -- p_headers    : optional JSON object of custom request headers
    --                e.g. '{"X-Tenant":"acme","X-Trace-Id":"abc123"}'
    -- p_bearer     : Bearer token — sets Authorization: Bearer <token>
    -- p_basic_user : Basic auth username (used with p_basic_pass)
    -- p_basic_pass : Basic auth password
    --
    -- Bearer takes precedence over Basic when both are supplied.
    -- Custom p_headers are applied after auth headers.
    ----------------------------------------------------------------------
    FUNCTION get  (p_url        IN VARCHAR2,
                   p_headers    IN CLOB     DEFAULT NULL,
                   p_bearer     IN VARCHAR2 DEFAULT NULL,
                   p_basic_user IN VARCHAR2 DEFAULT NULL,
                   p_basic_pass IN VARCHAR2 DEFAULT NULL) RETURN t_response;

    FUNCTION post (p_url          IN VARCHAR2,
                   p_body         IN CLOB     DEFAULT NULL,
                   p_content_type IN VARCHAR2 DEFAULT 'application/json',
                   p_headers      IN CLOB     DEFAULT NULL,
                   p_bearer       IN VARCHAR2 DEFAULT NULL,
                   p_basic_user   IN VARCHAR2 DEFAULT NULL,
                   p_basic_pass   IN VARCHAR2 DEFAULT NULL) RETURN t_response;

    FUNCTION put  (p_url          IN VARCHAR2,
                   p_body         IN CLOB     DEFAULT NULL,
                   p_content_type IN VARCHAR2 DEFAULT 'application/json',
                   p_headers      IN CLOB     DEFAULT NULL,
                   p_bearer       IN VARCHAR2 DEFAULT NULL,
                   p_basic_user   IN VARCHAR2 DEFAULT NULL,
                   p_basic_pass   IN VARCHAR2 DEFAULT NULL) RETURN t_response;

    FUNCTION patch(p_url          IN VARCHAR2,
                   p_body         IN CLOB     DEFAULT NULL,
                   p_content_type IN VARCHAR2 DEFAULT 'application/json',
                   p_headers      IN CLOB     DEFAULT NULL,
                   p_bearer       IN VARCHAR2 DEFAULT NULL,
                   p_basic_user   IN VARCHAR2 DEFAULT NULL,
                   p_basic_pass   IN VARCHAR2 DEFAULT NULL) RETURN t_response;

    -- Note: DELETE is a PL/SQL reserved word — function is named del
    FUNCTION del  (p_url        IN VARCHAR2,
                   p_headers    IN CLOB     DEFAULT NULL,
                   p_bearer     IN VARCHAR2 DEFAULT NULL,
                   p_basic_user IN VARCHAR2 DEFAULT NULL,
                   p_basic_pass IN VARCHAR2 DEFAULT NULL) RETURN t_response;

    ----------------------------------------------------------------------
    -- Response helpers
    ----------------------------------------------------------------------
    FUNCTION is_success(p_response IN t_response) RETURN BOOLEAN;  -- 2xx
    FUNCTION is_error  (p_response IN t_response) RETURN BOOLEAN;  -- 4xx / 5xx

    ----------------------------------------------------------------------
    -- Connectivity diagnostic
    -- Makes a GET request to p_url and reports on each failure layer:
    -- wallet configuration → network ACL → SSL handshake → HTTP response.
    -- p_success : TRUE if HTTP response received (any status code)
    -- p_report  : human-readable diagnosis, suitable for logging
    ----------------------------------------------------------------------
    PROCEDURE check_connectivity(
        p_url     IN  VARCHAR2,
        p_success OUT BOOLEAN,
        p_report  OUT CLOB
    );

END otk$rest;
/
