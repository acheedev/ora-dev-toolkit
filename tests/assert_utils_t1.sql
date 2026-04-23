SET SERVEROUTPUT ON
DECLARE
    l_pass   PLS_INTEGER := 0;
    l_fail   PLS_INTEGER := 0;
    l_result VARCHAR2(4000);

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
    DBMS_OUTPUT.put_line('=== TEST: otk$assert_utils ===');
    DBMS_OUTPUT.put_line('');

    --------------------------------------------------------------------------
    -- simple_name: valid identifiers
    --------------------------------------------------------------------------
    BEGIN
        l_result := otk$assert_utils.simple_name('EMPLOYEE_ID');
        ok('simple_name: plain identifier accepted', l_result = 'EMPLOYEE_ID');
    EXCEPTION WHEN OTHERS THEN
        ok('simple_name: plain identifier accepted', FALSE);
    END;

    BEGIN
        l_result := otk$assert_utils.simple_name('last_name');
        ok('simple_name: lowercase identifier accepted', l_result = 'last_name');
    EXCEPTION WHEN OTHERS THEN
        ok('simple_name: lowercase identifier accepted', FALSE);
    END;

    --------------------------------------------------------------------------
    -- simple_name: injection attempts must be rejected
    --------------------------------------------------------------------------
    BEGIN
        l_result := otk$assert_utils.simple_name('; DROP TABLE employees --');
        ok('simple_name: semicolon injection rejected', FALSE);
    EXCEPTION WHEN OTHERS THEN
        ok('simple_name: semicolon injection rejected', TRUE);
    END;

    BEGIN
        l_result := otk$assert_utils.simple_name('col'' OR ''1''=''1');
        ok('simple_name: quote injection rejected', FALSE);
    EXCEPTION WHEN OTHERS THEN
        ok('simple_name: quote injection rejected', TRUE);
    END;

    BEGIN
        l_result := otk$assert_utils.simple_name('col/*comment*/name');
        ok('simple_name: comment injection rejected', FALSE);
    EXCEPTION WHEN OTHERS THEN
        ok('simple_name: comment injection rejected', TRUE);
    END;

    --------------------------------------------------------------------------
    -- object_name: valid schema-qualified names
    --------------------------------------------------------------------------
    BEGIN
        l_result := otk$assert_utils.object_name('HR.EMPLOYEES');
        ok('object_name: schema-qualified name accepted', l_result = 'HR.EMPLOYEES');
    EXCEPTION WHEN OTHERS THEN
        ok('object_name: schema-qualified name accepted', FALSE);
    END;

    --------------------------------------------------------------------------
    -- object_name: injection must be rejected
    --------------------------------------------------------------------------
    BEGIN
        l_result := otk$assert_utils.object_name('HR.EMPLOYEES; DELETE FROM HR.EMPLOYEES');
        ok('object_name: injection rejected', FALSE);
    EXCEPTION WHEN OTHERS THEN
        ok('object_name: injection rejected', TRUE);
    END;

    --------------------------------------------------------------------------
    -- literal: safely quotes string values
    --------------------------------------------------------------------------
    BEGIN
        l_result := otk$assert_utils.literal('O''Reilly');
        ok('literal: embedded quote escaped', l_result = '''O''''Reilly''');
    EXCEPTION WHEN OTHERS THEN
        ok('literal: embedded quote escaped', FALSE);
    END;

    BEGIN
        l_result := otk$assert_utils.literal('plain value');
        ok('literal: plain value quoted', l_result = '''plain value''');
    EXCEPTION WHEN OTHERS THEN
        ok('literal: plain value quoted', FALSE);
    END;

    --------------------------------------------------------------------------
    -- enquote: quotes identifiers
    --------------------------------------------------------------------------
    BEGIN
        l_result := otk$assert_utils.enquote('my column');
        ok('enquote: identifier with space quoted', l_result IS NOT NULL);
    EXCEPTION WHEN OTHERS THEN
        ok('enquote: identifier with space quoted', FALSE);
    END;

    --------------------------------------------------------------------------
    -- NULL inputs
    --------------------------------------------------------------------------
    BEGIN
        l_result := otk$assert_utils.simple_name(NULL);
        ok('simple_name: NULL rejected', FALSE);
    EXCEPTION WHEN OTHERS THEN
        ok('simple_name: NULL rejected', TRUE);
    END;

    BEGIN
        l_result := otk$assert_utils.object_name(NULL);
        ok('object_name: NULL rejected', FALSE);
    EXCEPTION WHEN OTHERS THEN
        ok('object_name: NULL rejected', TRUE);
    END;

    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- ' || l_pass || ' passed, ' || l_fail || ' failed ---');

END;
/
