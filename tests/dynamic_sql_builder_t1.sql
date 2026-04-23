SET SERVEROUTPUT ON
DECLARE
    l_sql    VARCHAR2(4000);
    l_binds  SYS.ODCIVARCHAR2LIST;
    l_pass   PLS_INTEGER := 0;
    l_fail   PLS_INTEGER := 0;

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
    DBMS_OUTPUT.put_line('=== TEST: otk$dynamic_sql_builder ===');
    DBMS_OUTPUT.put_line('');

    --------------------------------------------------------------------------
    -- T1: Full query — SELECT cols, FROM, WHERE, ORDER BY, FETCH
    --------------------------------------------------------------------------
    otk$dynamic_sql_builder.new_query
        .select_cols( SYS.ODCIVARCHAR2LIST('EMPLOYEE_ID', 'LAST_NAME') )
        .from_table('HR.EMPLOYEES')
        .where_clause('DEPARTMENT_ID = :b1', ANYDATA.ConvertNumber(50))
        .order_by('LAST_NAME')
        .fetch_first(10)
        .build(l_sql, l_binds);

    ok('T1: SELECT clause correct',   INSTR(l_sql, 'SELECT EMPLOYEE_ID, LAST_NAME') > 0);
    ok('T1: FROM clause correct',     INSTR(l_sql, 'FROM HR.EMPLOYEES') > 0);
    ok('T1: WHERE clause correct',    INSTR(l_sql, 'WHERE DEPARTMENT_ID = :b1') > 0);
    ok('T1: ORDER BY clause correct', INSTR(l_sql, 'ORDER BY LAST_NAME') > 0);
    ok('T1: FETCH clause correct',    INSTR(l_sql, 'FETCH FIRST 10 ROWS ONLY') > 0);
    ok('T1: bind value captured',     l_binds.COUNT = 1);

    --------------------------------------------------------------------------
    -- T2: SELECT * when no columns specified
    --------------------------------------------------------------------------
    otk$dynamic_sql_builder.new_query
        .from_table('HR.EMPLOYEES')
        .build(l_sql, l_binds);

    ok('T2: SELECT * when no cols given', INSTR(l_sql, 'SELECT *') > 0);
    ok('T2: no binds',                    l_binds.COUNT = 0);

    --------------------------------------------------------------------------
    -- T3: Multiple WHERE clauses joined with AND
    --------------------------------------------------------------------------
    otk$dynamic_sql_builder.new_query
        .from_table('HR.EMPLOYEES')
        .where_clause('DEPARTMENT_ID = :b1', ANYDATA.ConvertNumber(50))
        .where_clause('SALARY > :b2',        ANYDATA.ConvertNumber(5000))
        .build(l_sql, l_binds);

    ok('T3: first condition present',  INSTR(l_sql, 'DEPARTMENT_ID = :b1') > 0);
    ok('T3: AND separator present',    INSTR(l_sql, ' AND ') > 0);
    ok('T3: second condition present', INSTR(l_sql, 'SALARY > :b2') > 0);
    ok('T3: two binds captured',       l_binds.COUNT = 2);

    --------------------------------------------------------------------------
    -- T4: No ORDER BY, no FETCH — minimal query
    --------------------------------------------------------------------------
    otk$dynamic_sql_builder.new_query
        .select_cols( SYS.ODCIVARCHAR2LIST('LOG_ID') )
        .from_table('OTK_ERROR_LOG')
        .build(l_sql, l_binds);

    ok('T4: no ORDER BY in output', INSTR(l_sql, 'ORDER BY') = 0);
    ok('T4: no FETCH in output',    INSTR(l_sql, 'FETCH') = 0);

    --------------------------------------------------------------------------
    -- T5: Injection in column name must be rejected
    --------------------------------------------------------------------------
    BEGIN
        otk$dynamic_sql_builder.new_query
            .select_cols( SYS.ODCIVARCHAR2LIST('col; DROP TABLE employees') )
            .from_table('HR.EMPLOYEES')
            .build(l_sql, l_binds);
        ok('T5: injection in column name rejected', FALSE);
    EXCEPTION WHEN OTHERS THEN
        ok('T5: injection in column name rejected', TRUE);
    END;

    --------------------------------------------------------------------------
    -- T6: Injection in table name must be rejected
    --------------------------------------------------------------------------
    BEGIN
        otk$dynamic_sql_builder.new_query
            .from_table('HR.EMPLOYEES; DELETE FROM HR.EMPLOYEES')
            .build(l_sql, l_binds);
        ok('T6: injection in table name rejected', FALSE);
    EXCEPTION WHEN OTHERS THEN
        ok('T6: injection in table name rejected', TRUE);
    END;

    --------------------------------------------------------------------------
    -- T7: Injection in ORDER BY must be rejected
    --------------------------------------------------------------------------
    BEGIN
        otk$dynamic_sql_builder.new_query
            .from_table('HR.EMPLOYEES')
            .order_by('LAST_NAME; DROP TABLE HR.EMPLOYEES')
            .build(l_sql, l_binds);
        ok('T7: injection in ORDER BY rejected', FALSE);
    EXCEPTION WHEN OTHERS THEN
        ok('T7: injection in ORDER BY rejected', TRUE);
    END;

    --------------------------------------------------------------------------
    DBMS_OUTPUT.put_line('');
    DBMS_OUTPUT.put_line('--- ' || l_pass || ' passed, ' || l_fail || ' failed ---');

END;
/
