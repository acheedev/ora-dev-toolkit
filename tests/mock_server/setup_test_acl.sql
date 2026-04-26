-- =============================================================================
-- otk test suite — Network ACL for mock server
-- Requires: DBA privilege
--
-- Grants your schema permission to connect to the mock server on localhost.
-- Run once per schema. Safe to re-run.
--
-- Usage:
--   @tests/mock_server/setup_test_acl.sql MY_SCHEMA 8765
-- =============================================================================

DEFINE schema = &1
DEFINE port   = &2

BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host       => '127.0.0.1',
        lower_port => &&port,
        upper_port => &&port,
        ace        => xs$ace_type(
            privilege_list => xs$name_list('connect', 'resolve'),
            principal_name => UPPER('&&schema'),
            principal_type => xs_acl.ptype_db
        )
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('ACL granted: &&schema -> 127.0.0.1:&&port');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Verify
SELECT host, lower_port, upper_port, principal
FROM   dba_host_aces
WHERE  principal   = UPPER('&&schema')
AND    host        = '127.0.0.1'
ORDER  BY lower_port;
