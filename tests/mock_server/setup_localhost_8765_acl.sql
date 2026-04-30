-- =============================================================================
-- otk test suite - Local mock server network ACL
-- Requires: DBA privilege
--
-- Grants a database schema permission to reach the local Python mock server at:
--   http://127.0.0.1:8765
--   http://localhost:8765
--
-- Usage from SQL*Plus / SQLcl as SYSDBA or another DBA user connected to the
-- target PDB, for example FREEPDB1:
--   @tests/mock_server/setup_localhost_8765_acl.sql AISQL
--
-- Safe to re-run; duplicate ACE errors are ignored.
-- =============================================================================

SET SERVEROUTPUT ON

DEFINE schema = &1

DECLARE
    c_schema CONSTANT VARCHAR2(128) := UPPER('&&schema');
    c_port   CONSTANT PLS_INTEGER   := 8765;

    PROCEDURE grant_connect(p_host IN VARCHAR2) IS
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
            host       => p_host,
            lower_port => c_port,
            upper_port => c_port,
            ace        => xs$ace_type(
                privilege_list => xs$name_list('connect'),
                principal_name => c_schema,
                principal_type => xs_acl.ptype_db
            )
        );
        DBMS_OUTPUT.PUT_LINE('Granted connect: ' || c_schema || ' -> ' || p_host || ':' || c_port);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -24243 THEN
                DBMS_OUTPUT.PUT_LINE('Already granted connect: ' || c_schema || ' -> ' || p_host || ':' || c_port);
            ELSE
                RAISE;
            END IF;
    END grant_connect;

    PROCEDURE grant_resolve(p_host IN VARCHAR2) IS
    BEGIN
        DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
            host => p_host,
            ace  => xs$ace_type(
                privilege_list => xs$name_list('resolve'),
                principal_name => c_schema,
                principal_type => xs_acl.ptype_db
            )
        );
        DBMS_OUTPUT.PUT_LINE('Granted resolve: ' || c_schema || ' -> ' || p_host);
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -24243 THEN
                DBMS_OUTPUT.PUT_LINE('Already granted resolve: ' || c_schema || ' -> ' || p_host);
            ELSE
                RAISE;
            END IF;
    END grant_resolve;
BEGIN
    grant_connect('127.0.0.1');
    grant_connect('localhost');
    grant_resolve('localhost');

    COMMIT;
END;
/

PROMPT
PROMPT Current ACEs for &&schema on local mock server hosts:

COLUMN host FORMAT A20
COLUMN principal FORMAT A30
COLUMN privilege FORMAT A12

SELECT host, lower_port, upper_port, principal, privilege
FROM   dba_host_aces
WHERE  principal = UPPER('&&schema')
AND    host IN ('127.0.0.1', 'localhost')
ORDER  BY host, lower_port, privilege;
