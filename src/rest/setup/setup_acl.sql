-- =============================================================================
-- otk$rest — Network ACL Setup
-- Requires: DBA privilege
--
-- Usage (from SQL*Plus or SQLcl):
--   @src/rest/setup/setup_acl.sql <schema> <host> <port>
--
-- Example:
--   @src/rest/setup/setup_acl.sql MY_APP_SCHEMA api.ansible-tower.company.com 443
--
-- Run once per schema/host combination. Safe to re-run — uses APPEND_HOST_ACE
-- which adds privileges without replacing existing ones.
-- =============================================================================

DEFINE schema = &1
DEFINE host   = &2
DEFINE port   = &3

BEGIN
    DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
        host       => '&&host',
        lower_port => &&port,
        upper_port => &&port,
        ace        => xs$ace_type(
            privilege_list => xs$name_list('connect', 'resolve'),
            principal_name => UPPER('&&schema'),
            principal_type => xs_acl.ptype_db
        )
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('ACL granted: &&schema -> &&host:&&port');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error: ' || SQLERRM);
        ROLLBACK;
END;
/

-- Verify
SELECT host, lower_port, upper_port, ace_order,
       grant_option, inverted, start_date, end_date
FROM   dba_host_aces
WHERE  principal = UPPER('&&schema')
ORDER  BY host, lower_port;
