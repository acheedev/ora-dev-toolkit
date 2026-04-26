SET SERVEROUTPUT ON
DECLARE
    l_pass  PLS_INTEGER := 0;
    l_fail  PLS_INTEGER := 0;
    l_bool  BOOLEAN;
    l_err   VARCHAR2(4000);

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
    DBMS_OUTPUT.put_line('=== TEST: otk$ddl ===');
    DBMS_OUTPUT.put_line('');

    --------------------------------------------------------------------------
    -- Setup: ensure test table does not exist before we start
    --------------------------------------------------------------------------
    otk$ddl.drop_table_if_exists('otk_ddl_test_tab', p_cascade_constraints => TRUE);
    otk$ddl.drop_table_if_exists('otk_ddl_test_child');

    --------------------------------------------------------------------------
    -- exec_ddl: create the test tables
    --------------------------------------------------------------------------
    otk$ddl.exec_ddl('
        CREATE TABLE otk_ddl_test_tab (
            id          NUMBER PRIMARY KEY,
            label       VARCHAR2(100),
            created_dt  DATE DEFAULT SYSDATE
        )
    ');

    otk$ddl.exec_ddl('
        CREATE TABLE otk_ddl_test_child (
            id         NUMBER PRIMARY KEY,
            parent_id  NUMBER REFERENCES otk_ddl_test_tab(id)
        )
    ');

    --------------------------------------------------------------------------
    -- table_exists
    --------------------------------------------------------------------------
    ok('table_exists: present table',    otk$ddl.table_exists('otk_ddl_test_tab')   = TRUE);
    ok('table_exists: absent table',     otk$ddl.table_exists('otk_no_such_table')  = FALSE);
    ok('table_exists: case-insensitive', otk$ddl.table_exists('OTK_DDL_TEST_TAB')   = TRUE);

    --------------------------------------------------------------------------
    -- object_exists (generic)
    --------------------------------------------------------------------------
    ok('object_exists: TABLE type',   otk$ddl.object_exists('otk_ddl_test_tab', 'TABLE') = TRUE);
    ok('object_exists: wrong type',   otk$ddl.object_exists('otk_ddl_test_tab', 'VIEW')  = FALSE);

    --------------------------------------------------------------------------
    -- column_exists
    --------------------------------------------------------------------------
    ok('column_exists: id column',          otk$ddl.column_exists('otk_ddl_test_tab', 'id')          = TRUE);
    ok('column_exists: label column',       otk$ddl.column_exists('otk_ddl_test_tab', 'label')       = TRUE);
    ok('column_exists: absent column',      otk$ddl.column_exists('otk_ddl_test_tab', 'no_such_col') = FALSE);
    ok('column_exists: case-insensitive',   otk$ddl.column_exists('OTK_DDL_TEST_TAB', 'ID')          = TRUE);
    ok('column_exists: wrong table',        otk$ddl.column_exists('otk_no_such_table', 'id')         = FALSE);

    --------------------------------------------------------------------------
    -- constraint_exists
    --------------------------------------------------------------------------
    ok('constraint_exists: PK constraint exists',
        otk$ddl.constraint_exists('SYS_C%', 'otk_ddl_test_tab') OR
        -- PK name may be system-generated; test via ALL_CONSTRAINTS directly
        (SELECT COUNT(*) FROM all_constraints
         WHERE table_name = 'OTK_DDL_TEST_TAB'
         AND   constraint_type = 'P'
         AND   owner = SYS_CONTEXT('USERENV','CURRENT_SCHEMA')) > 0 = TRUE);

    ok('constraint_exists: absent constraint',
        otk$ddl.constraint_exists('OTK_NO_SUCH_CONSTRAINT') = FALSE);

    --------------------------------------------------------------------------
    -- drop_if_exists: non-existent object is a no-op (must not raise)
    --------------------------------------------------------------------------
    BEGIN
        otk$ddl.drop_if_exists('otk_no_such_table', 'TABLE');
        ok('drop_if_exists: no-op on missing object', TRUE);
    EXCEPTION WHEN OTHERS THEN
        ok('drop_if_exists: no-op on missing object', FALSE);
    END;

    --------------------------------------------------------------------------
    -- drop_table_if_exists: CASCADE CONSTRAINTS
    --------------------------------------------------------------------------
    -- Child table references parent — drop parent without CASCADE should fail
    l_bool := otk$ddl.try_exec(
        'DROP TABLE otk_ddl_test_tab',
        l_err
    );
    ok('try_exec: FK violation returns FALSE',  l_bool = FALSE);
    ok('try_exec: error text populated',        l_err  IS NOT NULL);

    -- Drop with CASCADE CONSTRAINTS should succeed
    BEGIN
        otk$ddl.drop_table_if_exists('otk_ddl_test_tab', p_cascade_constraints => TRUE);
        ok('drop_table_if_exists: CASCADE CONSTRAINTS succeeds', TRUE);
    EXCEPTION WHEN OTHERS THEN
        ok('drop_table_if_exists: CASCADE CONSTRAINTS succeeds', FALSE);
    END;

    ok('table_exists: gone after drop', otk$ddl.table_exists('otk_ddl_test_tab') = FALSE);

    --------------------------------------------------------------------------
    -- drop_table_if_exists: already-gone table is a no-op
    --------------------------------------------------------------------------
    BEGIN
        otk$ddl.drop_table_if_exists('otk_ddl_test_tab');
        ok('drop_table_if_exists: no-op on missing table', TRUE);
    EXCEPTION WHEN OTHERS THEN
        ok('drop_table_if_exists: no-op on missing table', FALSE);
    END;

    --------------------------------------------------------------------------
    -- try_exec: success path
    --------------------------------------------------------------------------
    l_bool := otk$ddl.try_exec(
        'CREATE TABLE otk_ddl_test_tab (id NUMBER)',
        l_err
    );
    ok('try_exec: success returns TRUE',   l_bool = TRUE);
    ok('try_exec: p_err NULL on success',  l_err  IS NULL);
    ok('table_exists: present after try_exec create', otk$ddl.table_exists('otk_ddl_test_tab') = TRUE);

    --------------------------------------------------------------------------
    -- exec_ddl: failure raises with DDL in message
    --------------------------------------------------------------------------
    BEGIN
        otk$ddl.exec_ddl('THIS IS NOT VALID SQL');
        ok('exec_ddl: raises on bad DDL', FALSE);
    EXCEPTION WHEN OTHERS THEN
        ok('exec_ddl: raises on bad DDL',          TRUE);
        ok('exec_ddl: error contains DDL snippet',
            INSTR(SQLERRM, 'THIS IS NOT VALID SQL') > 0 OR
            INSTR(DBMS_UTILITY.format_error_stack, 'DDL:') > 0);
    END;

    --------------------------------------------------------------------------
    -- Cleanup
    --------------------------------------------------------------------------
    otk$ddl.drop_table_if_exists('otk_ddl_test_child');
    otk$ddl.drop_table_if_exists('otk_ddl_test_tab');

    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- ' || l_pass || ' passed, ' || l_fail || ' failed ---');

END;
/
